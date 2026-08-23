# personale-mcp

Read-only MCP server for Personale, a local activity tracker whose Spring Boot REST API runs on `http://localhost:8696`.

The server uses the official Python `mcp` SDK with FastMCP over stdio and calls Personale with `httpx`. It exposes tools for current activity, daily summaries, range summaries, insights, interruptors, browser domain breakdowns, anomaly checks, and weekly reviews.

## Tools

| Tool | Description |
| --- | --- |
| `current_activity` | What the user is doing right now: category, app, state, focus minutes, context switches. |
| `day_summary` | Full summary for a day: app usage, tracked seconds, idle count, category breakdown, sessions. |
| `range_summary` | Aggregated stats over a date range. |
| `insights` | Rich productivity analytics: heatmap, day-of-week patterns, distractions, focus sessions, streaks. |
| `interruptors` | Interruption events for a single day or a date range. |
| `domains` | Browser domain time breakdown for a given day. |
| `anomaly_check` | Whether a day was unusually fragmented or low-focus vs the recent baseline; per-metric z-scores and severity. |
| `weekly_review` | Combined range totals, top interruptors, productivity overview, and latest-day anomalies for a week in review. |

## Environment

| Variable | Default | Description |
| --- | --- | --- |
| `PERSONALE_BASE_URL` | `http://localhost:8696` | Base URL for the local Personale backend. |
| `PERSONALE_DAY_START_HOUR` | `4` | Hour used by Personale to anchor the activity day. |
| `PERSONALE_TARGET_HOURS` | `12` | Daily target hours used by the current activity tool. |

## Claude Code Registration

```sh
claude mcp add --scope user personale -- uvx --from /Users/ares/Documents/Abhinav/Code/personal/personale/tools/personale-mcp personale-mcp
```

## Development

```sh
uv venv .venv
uv pip install -e ".[dev]" -q
.venv/bin/pytest -q
```
