CREATE TABLE IF NOT EXISTS app_sessions (
    id              BIGSERIAL PRIMARY KEY,
    app_name        TEXT NOT NULL,
    bundle_id       TEXT,
    window_title    TEXT,
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    duration_seconds INT GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (ended_at - started_at))::INT
    ) STORED,

    CONSTRAINT check_dates CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_single_active ON app_sessions ((true)) WHERE (ended_at IS NULL);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON app_sessions (started_at) WHERE (ended_at IS NULL);
CREATE INDEX IF NOT EXISTS idx_sessions_range ON app_sessions (started_at, ended_at);
