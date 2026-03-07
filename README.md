# Personale

A local-first macOS productivity tracker. Passively monitors which applications you use and for how long — all data stays on your machine.

## Components

- **personal/** — Swift macOS app (menu bar + window)
- **server/** — Java Spring Boot backend with PostgreSQL

## Quick Start

```bash
# Start PostgreSQL
cd server && docker compose up -d

# Start the backend
./gradlew bootRun

# Build and run the macOS app from Xcode
open ../personal/personal.xcodeproj
# Cmd+R to run
```

## API

- `POST /api/events` — Record an app switch
- `POST /api/events/close` — Close the active session (sleep/idle)
- `GET /api/stats/today` — Today's time-per-app stats
