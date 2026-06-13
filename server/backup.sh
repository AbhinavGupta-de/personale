#!/bin/bash
# Nightly Postgres backup for Personale. Dumps the personale DB to a gzipped
# pg_dump under ~/personale-backups and prunes to the most recent KEEP files.
# Wired into `personale install` as a launchd agent (daily 03:00).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DEST="${PERSONALE_BACKUP_DIR:-$HOME/personale-backups}"
KEEP="${PERSONALE_BACKUP_KEEP:-14}"
mkdir -p "$DEST"

# Skip silently if Docker/Postgres isn't up (don't error a scheduled run).
if ! docker compose exec -T postgres pg_isready -U personale >/dev/null 2>&1; then
    echo "$(date -u +%FT%TZ) postgres not ready — skipping backup" >&2
    exit 0
fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="$DEST/personale-${ts}.sql.gz"
tmp="${out}.partial"

# Dump → gzip atomically (write to .partial, then rename).
if docker compose exec -T postgres pg_dump -U personale personale | gzip > "$tmp"; then
    mv "$tmp" "$out"
    echo "$(date -u +%FT%TZ) backup ok: $out ($(du -h "$out" | cut -f1))"
else
    rm -f "$tmp"
    echo "$(date -u +%FT%TZ) backup FAILED" >&2
    exit 1
fi

# Prune: keep the newest $KEEP, delete the rest.
ls -1t "$DEST"/personale-*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    rm -f "$old" && echo "pruned $old"
done
