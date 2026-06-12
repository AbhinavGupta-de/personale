from __future__ import annotations

from typing import Any

import pytest

from personale_mcp import server
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
