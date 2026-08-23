from __future__ import annotations

import re
from datetime import date as calendar_date
from datetime import datetime
from typing import Any

from mcp.server.fastmcp import FastMCP

from .client import PersonaleClient, PersonaleUnavailableError
from .config import load_settings

mcp = FastMCP("personale")

_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_client: PersonaleClient | None = None


def validate_date(date_str: str) -> None:
    if not _DATE_RE.match(date_str):
        raise ValueError(f"Expected date in YYYY-MM-DD format, got {date_str!r}.")

    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise ValueError(
            f"Invalid date {date_str!r}; expected a real calendar date in YYYY-MM-DD format."
        ) from exc


def _get_client() -> PersonaleClient:
    global _client
    if _client is None:
        _client = PersonaleClient(load_settings())
    return _client


def _offline_message(client: PersonaleClient) -> str:
    return (
        f"Personale backend is offline (expected at {client.settings.base_url}). "
        "Ask the user to run ./personale up"
    )


def _unwrap_response(value: Any, key: str) -> Any:
    if isinstance(value, dict):
        return value.get(key, value)
    return value


@mcp.tool()
async def current_activity() -> dict[str, Any] | str:
    """Get what the user is doing right now: category, app, state (focused/scattered/idle/away/break), focusMinutes, contextSwitchesLastHour, dailyTargetPct."""
    client = _get_client()
    try:
        return await client.get(
            "/api/activity/current",
            dayStartHour=client.settings.day_start_hour,
            targetHours=client.settings.target_hours,
        )
    except PersonaleUnavailableError:
        return _offline_message(client)


@mcp.tool()
async def day_summary(date: str | None = None) -> dict[str, Any] | str:
    """Get a full summary for a day: app usage, total tracked seconds, idle count, category breakdown, and session list. Pass date as YYYY-MM-DD or omit for today."""
    if date is not None:
        validate_date(date)

    client = _get_client()
    stats_path = "/api/stats/today" if date is None else "/api/stats/day"
    stats_params = {} if date is None else {"date": date}
    related_date = date or calendar_date.today().isoformat()

    try:
        stats = await client.get(stats_path, **stats_params)
        categories = await client.get("/api/stats/categories", date=related_date)
        sessions = await client.get("/api/stats/sessions", date=related_date)
    except PersonaleUnavailableError:
        return _offline_message(client)

    return {
        "apps": stats.get("apps", []),
        "totalTrackedSeconds": stats.get("totalTrackedSeconds", 0),
        "idleSessionCount": stats.get("idleSessionCount", 0),
        "categories": _unwrap_response(categories, "categories"),
        "sessions": _unwrap_response(sessions, "sessions"),
    }


@mcp.tool()
async def range_summary(from_date: str, to_date: str) -> dict[str, Any] | str:
    """Get aggregated stats over a date range. Both from_date and to_date must be YYYY-MM-DD."""
    validate_date(from_date)
    validate_date(to_date)

    client = _get_client()
    try:
        return await client.get(
            "/api/stats/range/summary",
            **{"from": from_date, "to": to_date},
        )
    except PersonaleUnavailableError:
        return _offline_message(client)


@mcp.tool()
async def insights(from_date: str, to_date: str) -> dict[str, Any] | str:
    """Get rich productivity analytics: heatmap, day-of-week patterns, top distractions, longest focus sessions, streaks, category mix vs prior period. Both dates must be YYYY-MM-DD."""
    validate_date(from_date)
    validate_date(to_date)

    client = _get_client()
    try:
        return await client.get(
            "/api/insights/overview",
            **{"from": from_date, "to": to_date},
        )
    except PersonaleUnavailableError:
        return _offline_message(client)


@mcp.tool()
async def interruptors(
    date: str | None = None,
    from_date: str | None = None,
    to_date: str | None = None,
) -> dict[str, Any] | str:
    """Get interruption events. Provide either date (YYYY-MM-DD) for a single day, or from_date+to_date for a range. Not both."""
    has_date = date is not None
    has_range_part = from_date is not None or to_date is not None

    if has_date and has_range_part:
        raise ValueError("Provide either date or from_date+to_date, not both.")
    if not has_date and not has_range_part:
        raise ValueError("Provide either date or from_date+to_date.")
    if has_range_part and (from_date is None or to_date is None):
        raise ValueError("Provide both from_date and to_date for a range.")

    client = _get_client()
    try:
        if date is not None:
            validate_date(date)
            return await client.get("/api/stats/interruptors", date=date)

        assert from_date is not None
        assert to_date is not None
        validate_date(from_date)
        validate_date(to_date)
        return await client.get(
            "/api/stats/interruptors/range",
            **{"from": from_date, "to": to_date},
        )
    except PersonaleUnavailableError:
        return _offline_message(client)


@mcp.tool()
async def domains(date: str) -> dict[str, Any] | str:
    """Get browser domain time breakdown for a given day (YYYY-MM-DD)."""
    validate_date(date)

    client = _get_client()
    try:
        return await client.get("/api/stats/domains", date=date)
    except PersonaleUnavailableError:
        return _offline_message(client)


@mcp.tool()
async def anomaly_check(date: str, lookback_days: int = 14) -> dict[str, Any] | str:
    """Check whether a given day (YYYY-MM-DD) was unusually fragmented or low-focus vs the user's recent baseline. Returns per-metric z-scores and severity (normal/elevated/high)."""
    validate_date(date)
    if lookback_days < 3:
        raise ValueError(
            f"lookback_days must be >= 3 to build a baseline, got {lookback_days}."
        )

    client = _get_client()
    try:
        return await client.get(
            "/api/insights/anomalies",
            date=date,
            lookbackDays=lookback_days,
        )
    except PersonaleUnavailableError:
        return _offline_message(client)


@mcp.tool()
async def weekly_review(from_date: str, to_date: str) -> dict[str, Any] | str:
    """Pull everything needed to narrate a week in review: range totals + category mix, top interruptors, productivity overview (streaks/heatmap), and the anomaly check for the most recent day. Returns a single structured dict for Claude to synthesize into prose. Both dates must be YYYY-MM-DD."""
    validate_date(from_date)
    validate_date(to_date)

    client = _get_client()
    try:
        range_summary = await client.get(
            "/api/stats/range/summary",
            **{"from": from_date, "to": to_date},
        )
        interruptors = await client.get(
            "/api/stats/interruptors/range",
            **{"from": from_date, "to": to_date},
        )
        overview = await client.get(
            "/api/insights/overview",
            **{"from": from_date, "to": to_date},
        )
        latest_day_anomalies = await client.get(
            "/api/insights/anomalies",
            date=to_date,
            lookbackDays=14,
        )
    except PersonaleUnavailableError:
        return _offline_message(client)

    return {
        "range": range_summary,
        "interruptors": interruptors,
        "overview": overview,
        "latest_day_anomalies": latest_day_anomalies,
    }
