#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure homebrew binaries (docker, colima, java) are on PATH when run by launchd.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Load the BYOC Anthropic API key (AI insight features) from a gitignored file
# OUTSIDE the repo. launchd does not load your shell profile, so the key must
# live somewhere the agent can read it. The key value never enters the repo.
if [ -f "$HOME/.personale/anthropic.key" ]; then
    export ANTHROPIC_API_KEY="$(tr -d '\r\n' < "$HOME/.personale/anthropic.key")"
fi

# Wait up to 5 minutes for a Docker socket. At login, Docker Desktop / Colima
# can take a while to come up; launchd starts us before either is ready.
wait_for_docker() {
    local started_docker_app=0 started_colima=0
    for i in $(seq 1 150); do
        if docker info >/dev/null 2>&1; then
            [[ $i -gt 1 ]] && echo "Docker came up after ${i}s"
            return 0
        fi
        # First miss: try to nudge whichever runtime is installed.
        if [[ $started_docker_app -eq 0 && -d /Applications/Docker.app ]]; then
            echo "Launching Docker.app..."
            open -ga Docker >/dev/null 2>&1 || true
            started_docker_app=1
        elif [[ $started_colima -eq 0 ]] && command -v colima >/dev/null 2>&1; then
            echo "Starting Colima..."
            colima start --runtime docker >/dev/null 2>&1 &
            started_colima=1
        fi
        sleep 2
    done
    echo "ERROR: Docker did not become ready within 5 minutes."
    return 1
}

wait_for_docker || exit 1

# Bring up Postgres (idempotent).
if ! docker compose ps --status running 2>/dev/null | grep -q postgres; then
    echo "Starting PostgreSQL..."
    docker compose up -d
fi

# Wait for Postgres to accept connections.
for i in $(seq 1 30); do
    if docker compose exec -T postgres pg_isready -U personale >/dev/null 2>&1; then
        [[ $i -gt 1 ]] && echo "Postgres ready after ${i}s"
        break
    fi
    sleep 1
    [[ $i -eq 30 ]] && { echo "ERROR: Postgres not ready after 30s. Check 'docker compose logs postgres'"; exit 1; }
done

echo "Starting Personale backend on port 8696..."
exec ./gradlew --no-daemon bootRun
