from __future__ import annotations

from typing import Any

import pytest

from personale_mcp import server
from personale_mcp.client import PersonaleUnavailableError
from personale_mcp.config import Settings


class FakeClient:
    def __init__(self) -> None:
        self.settings = Settings(base_url="http://personale.test")
        self.calls: list[tuple[str, dict[str, Any]]] = []

    async def get(self, path: str, **params: Any) -> Any:
        self.calls.append((path, params))
        if path == "/api/stats/day":
            return {
                "apps": [{"name": "Editor", "seconds": 120}],
                "totalTrackedSeconds": 120,
                "idleSessionCount": 0,
            }
        if path == "/api/stats/categories":
            return {"categories": [{"category": "Development", "seconds": 120}]}
        if path == "/api/stats/sessions":
            return {"sessions": [{"app": "Editor", "seconds": 120}]}
        return {"path": path, "params": params}


SAMPLE_ANOMALIES = {
    "date": "2026-06-12",
    "lookbackDays": 14,
    "baselineDaysWithData": 10,
    "metrics": [
        {
            "name": "contextSwitches",
            "value": 88,
            "baselineMean": 40.0,
            "baselineStdDev": 12.0,
            "zScore": 4.0,
            "severity": "high",
            "message": "Way more context switches than usual.",
        }
    ],
}


class AnomalyClient(FakeClient):
    async def get(self, path: str, **params: Any) -> Any:
        self.calls.append((path, params))
        if path == "/api/insights/anomalies":
            return SAMPLE_ANOMALIES
        return {"path": path, "params": params}


class WeeklyReviewClient(FakeClient):
    async def get(self, path: str, **params: Any) -> Any:
        self.calls.append((path, params))
        if path == "/api/stats/range/summary":
            return {"endpoint": "range"}
        if path == "/api/stats/interruptors/range":
            return {"endpoint": "interruptors"}
        if path == "/api/insights/overview":
            return {"endpoint": "overview"}
        if path == "/api/insights/anomalies":
            return {"endpoint": "anomalies"}
        return {"path": path, "params": params}


class OfflineOnNthCallClient(FakeClient):
    """Raises PersonaleUnavailableError on the Nth get() call (1-indexed).

    Used to prove weekly_review's offline guard catches a *mid-sequence*
    failure, not just one on the very first composed call.
    """

    def __init__(self, fail_on_call: int) -> None:
        super().__init__()
        self.fail_on_call = fail_on_call

    async def get(self, path: str, **params: Any) -> Any:
        self.calls.append((path, params))
        if len(self.calls) == self.fail_on_call:
            raise PersonaleUnavailableError("backend down")
        return {"path": path, "params": params}


@pytest.fixture
def fake_client(monkeypatch: pytest.MonkeyPatch) -> FakeClient:
    client = FakeClient()
    monkeypatch.setattr(server, "_client", client)
    return client


@pytest.mark.asyncio
async def test_date_validation_rejects_bad_format() -> None:
    with pytest.raises(ValueError, match="YYYY-MM-DD"):
        await server.domains("2026/06/12")


@pytest.mark.asyncio
async def test_current_activity_happy_path(fake_client: FakeClient) -> None:
    result = await server.current_activity()

    assert result == {
        "path": "/api/activity/current",
        "params": {"dayStartHour": 4, "targetHours": 12},
    }
    assert fake_client.calls == [
        ("/api/activity/current", {"dayStartHour": 4, "targetHours": 12})
    ]


@pytest.mark.asyncio
async def test_day_summary_happy_path(fake_client: FakeClient) -> None:
    result = await server.day_summary("2026-06-12")

    assert result == {
        "apps": [{"name": "Editor", "seconds": 120}],
        "totalTrackedSeconds": 120,
        "idleSessionCount": 0,
        "categories": [{"category": "Development", "seconds": 120}],
        "sessions": [{"app": "Editor", "seconds": 120}],
    }
    assert fake_client.calls == [
        ("/api/stats/day", {"date": "2026-06-12"}),
        ("/api/stats/categories", {"date": "2026-06-12"}),
        ("/api/stats/sessions", {"date": "2026-06-12"}),
    ]


@pytest.mark.asyncio
async def test_range_summary_happy_path(fake_client: FakeClient) -> None:
    result = await server.range_summary("2026-06-01", "2026-06-12")

    assert result == {
        "path": "/api/stats/range/summary",
        "params": {"from": "2026-06-01", "to": "2026-06-12"},
    }


@pytest.mark.asyncio
async def test_insights_happy_path(fake_client: FakeClient) -> None:
    result = await server.insights("2026-06-01", "2026-06-12")

    assert result == {
        "path": "/api/insights/overview",
        "params": {"from": "2026-06-01", "to": "2026-06-12"},
    }


@pytest.mark.asyncio
async def test_interruptors_day_happy_path(fake_client: FakeClient) -> None:
    result = await server.interruptors(date="2026-06-12")

    assert result == {
        "path": "/api/stats/interruptors",
        "params": {"date": "2026-06-12"},
    }


@pytest.mark.asyncio
async def test_interruptors_range_happy_path(fake_client: FakeClient) -> None:
    result = await server.interruptors(
        from_date="2026-06-01",
        to_date="2026-06-12",
    )

    assert result == {
        "path": "/api/stats/interruptors/range",
        "params": {"from": "2026-06-01", "to": "2026-06-12"},
    }


@pytest.mark.asyncio
async def test_domains_happy_path(fake_client: FakeClient) -> None:
    result = await server.domains("2026-06-12")

    assert result == {
        "path": "/api/stats/domains",
        "params": {"date": "2026-06-12"},
    }


@pytest.mark.asyncio
async def test_interruptors_rejects_neither_date_nor_range() -> None:
    with pytest.raises(ValueError, match="Provide either date"):
        await server.interruptors()


@pytest.mark.asyncio
async def test_interruptors_rejects_both_date_and_range() -> None:
    with pytest.raises(ValueError, match="not both"):
        await server.interruptors(
            date="2026-06-12",
            from_date="2026-06-01",
            to_date="2026-06-12",
        )


@pytest.mark.asyncio
async def test_anomaly_check_happy_path(monkeypatch: pytest.MonkeyPatch) -> None:
    client = AnomalyClient()
    monkeypatch.setattr(server, "_client", client)

    result = await server.anomaly_check("2026-06-12")

    assert result == SAMPLE_ANOMALIES
    assert client.calls == [
        ("/api/insights/anomalies", {"date": "2026-06-12", "lookbackDays": 14})
    ]


@pytest.mark.asyncio
async def test_anomaly_check_custom_lookback(monkeypatch: pytest.MonkeyPatch) -> None:
    client = AnomalyClient()
    monkeypatch.setattr(server, "_client", client)

    await server.anomaly_check("2026-06-12", lookback_days=7)

    assert client.calls == [
        ("/api/insights/anomalies", {"date": "2026-06-12", "lookbackDays": 7})
    ]


@pytest.mark.asyncio
async def test_anomaly_check_rejects_bad_date() -> None:
    with pytest.raises(ValueError, match="YYYY-MM-DD"):
        await server.anomaly_check("2026/06/12")


@pytest.mark.asyncio
async def test_anomaly_check_rejects_short_lookback() -> None:
    with pytest.raises(ValueError, match="must be >= 3"):
        await server.anomaly_check("2026-06-12", lookback_days=2)


@pytest.mark.asyncio
async def test_weekly_review_happy_path(monkeypatch: pytest.MonkeyPatch) -> None:
    client = WeeklyReviewClient()
    monkeypatch.setattr(server, "_client", client)

    result = await server.weekly_review("2026-06-06", "2026-06-12")

    assert result == {
        "range": {"endpoint": "range"},
        "interruptors": {"endpoint": "interruptors"},
        "overview": {"endpoint": "overview"},
        "latest_day_anomalies": {"endpoint": "anomalies"},
    }
    assert set(result.keys()) == {
        "range",
        "interruptors",
        "overview",
        "latest_day_anomalies",
    }
    assert client.calls == [
        ("/api/stats/range/summary", {"from": "2026-06-06", "to": "2026-06-12"}),
        ("/api/stats/interruptors/range", {"from": "2026-06-06", "to": "2026-06-12"}),
        ("/api/insights/overview", {"from": "2026-06-06", "to": "2026-06-12"}),
        ("/api/insights/anomalies", {"date": "2026-06-12", "lookbackDays": 14}),
    ]


@pytest.mark.asyncio
async def test_weekly_review_rejects_bad_date() -> None:
    with pytest.raises(ValueError, match="YYYY-MM-DD"):
        await server.weekly_review("2026-06-06", "2026/06/12")


@pytest.mark.asyncio
async def test_weekly_review_offline_midway_returns_offline_message(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # The 3rd of the 4 composed GETs goes offline. The except block must still
    # fire and return the offline message rather than a partial dict or a raised
    # exception — this is the core risk of the multi-call composition.
    client = OfflineOnNthCallClient(fail_on_call=3)
    monkeypatch.setattr(server, "_client", client)

    result = await server.weekly_review("2026-06-06", "2026-06-12")

    assert isinstance(result, str)
    assert "offline" in result.lower()
    # Stopped at the failing 3rd call; the 4th was never attempted.
    assert len(client.calls) == 3
