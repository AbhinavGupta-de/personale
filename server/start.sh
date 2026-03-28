#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check Docker/Colima
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running. Start Docker Desktop or Colima first."
    exit 1
fi

# Check PostgreSQL container
if ! docker compose ps --status running 2>/dev/null | grep -q postgres; then
    echo "Starting PostgreSQL..."
    docker compose up -d
    sleep 3
fi

# Check PostgreSQL is accepting connections
if ! docker compose exec -T postgres pg_isready -U personale &>/dev/null; then
    echo "ERROR: PostgreSQL is not ready. Check 'docker compose logs postgres'"
    exit 1
fi

echo "Starting Personale backend on port 8696..."
exec ./gradlew --no-daemon bootRun
