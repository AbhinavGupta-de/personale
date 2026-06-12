from __future__ import annotations

import httpx
import pytest

from personale_mcp.client import (
    PersonaleAPIError,
    PersonaleClient,
    PersonaleUnavailableError,
)
from personale_mcp.config import Settings


@pytest.mark.asyncio
async def test_day_start_hour_auto_injection() -> None:
    seen_query: dict[str, str] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal seen_query
        seen_query = dict(request.url.params)
        return httpx.Response(200, json={"ok": True})

    client = PersonaleClient(
        Settings(base_url="http://personale.test", day_start_hour=7),
        transport=httpx.MockTransport(handler),
    )

    async with client:
        result = await client.get("/api/stats/today")

    assert result == {"ok": True}
    assert seen_query["dayStartHour"] == "7"


@pytest.mark.asyncio
async def test_unavailable_error_on_connect_failure() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    client = PersonaleClient(
        Settings(base_url="http://personale.test"),
        transport=httpx.MockTransport(handler),
    )

    with pytest.raises(PersonaleUnavailableError):
        await client.get("/api/activity/current")


@pytest.mark.asyncio
async def test_api_error_on_non_2xx() -> None:
    client = PersonaleClient(
        Settings(base_url="http://personale.test"),
        transport=httpx.MockTransport(
            lambda request: httpx.Response(503, text="maintenance")
        ),
    )

    with pytest.raises(PersonaleAPIError) as exc_info:
        await client.get("/api/activity/current")

    assert exc_info.value.status == 503
    assert exc_info.value.body == "maintenance"
