# Personale

A local-first macOS productivity tracker. Passively monitors which applications you use and for how long — all data stays on your machine.

## Components

- **personal/** — Swift macOS app (menu bar + dashboard window)
- **server/** — Java Spring Boot backend with PostgreSQL
- **extension/** — Chrome/Brave browser extension for per-site tracking

## Quick Start

```bash
./personale setup     # one-time: deps check + secret-scan git hooks
./personale up        # start Postgres + backend + open the app (builds if stale)
./personale status    # see what's running
./personale install   # autostart backend + app at login (optional)
```

Run `./personale help` for the full subcommand list.

### Manual (no script)

```bash
cd server && docker compose up -d              # Postgres
./gradlew --no-daemon bootRun                  # backend on :8696
open ../personal/personal.xcodeproj            # Xcode → Cmd+R
```

## Browser Extension

Breaks down browser time by website (e.g. GitHub = Code, YouTube = Media) instead of just "Chrome."

```bash
cd extension && npm install && npx tsc
```

Then load in Chrome/Brave:
1. Go to `chrome://extensions` (or `brave://extensions`)
2. Enable **Developer mode**
3. Click **Load unpacked** → select the `extension/` folder
4. The extension options page lets you configure the server URL and excluded domains

## Settings

The macOS app has a settings page (gear icon in sidebar):
- **Server URL** — default `http://localhost:8696`
- **Work day** — configure start hour, end hour, and daily target
- **Idle thresholds** — per-category (Code: 180s, Media: 60s, etc.)
- **Launch at login** — toggle

## API

- `POST /api/events` — Record an app switch
- `POST /api/events/close` — Close the active session (sleep/idle)
- `POST /api/events/browser` — Record a browser tab change
- `GET /api/stats/today` — Today's time-per-app stats
- `GET /api/stats/day?date=` — Stats for a specific day
- `GET /api/stats/timeline?date=` — Merged session blocks
- `GET /api/stats/categories?date=` — Time by category (enriched with browser data)
- `GET /api/stats/range?from=&to=` — Per-day breakdown over a date range
- `GET /api/stats/range/summary?from=&to=` — Aggregate stats for a range
- `GET /api/health` — Server health check
