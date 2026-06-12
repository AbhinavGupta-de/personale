# personale-mcp

Read-only MCP server for Personale, a local activity tracker whose Spring Boot REST API runs on `http://localhost:8696`.

The server uses the official Python `mcp` SDK with FastMCP over stdio and calls Personale with `httpx`. It exposes tools for current activity, daily summaries, range summaries, insights, interruptors, and browser domain breakdowns.

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
