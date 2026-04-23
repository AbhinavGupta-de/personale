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

-- Category mapping: bundle_id → category for time breakdown
CREATE TABLE IF NOT EXISTS category_mappings (
    id          BIGSERIAL PRIMARY KEY,
    bundle_id   TEXT NOT NULL UNIQUE,
    category    TEXT NOT NULL
);

-- M4 + M12: per-category config (idle threshold + tracking flags)
-- Reading allows long pauses (thinking, scrolling); Communication needs snappy cuts.
CREATE TABLE IF NOT EXISTS category_thresholds (
    category               TEXT PRIMARY KEY,
    idle_threshold_seconds INT  NOT NULL,
    focus                  BOOLEAN NOT NULL DEFAULT TRUE,
    work_hours             BOOLEAN NOT NULL DEFAULT TRUE,
    idle_detection         BOOLEAN NOT NULL DEFAULT TRUE,
    distraction_blocker    BOOLEAN NOT NULL DEFAULT FALSE
);

-- M12 backfill for existing deployments
ALTER TABLE category_thresholds ADD COLUMN IF NOT EXISTS focus               BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE category_thresholds ADD COLUMN IF NOT EXISTS work_hours          BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE category_thresholds ADD COLUMN IF NOT EXISTS idle_detection      BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE category_thresholds ADD COLUMN IF NOT EXISTS distraction_blocker BOOLEAN NOT NULL DEFAULT FALSE;

-- Category goals: 0 = no goal. goal_is_max=true means target is ceiling (stay under),
-- false means floor (stay above). Added Apr 2026 from research.
ALTER TABLE category_thresholds ADD COLUMN IF NOT EXISTS daily_goal_seconds  INT     NOT NULL DEFAULT 0;
ALTER TABLE category_thresholds ADD COLUMN IF NOT EXISTS goal_is_max         BOOLEAN NOT NULL DEFAULT FALSE;

INSERT INTO category_thresholds (category, idle_threshold_seconds, focus, work_hours, idle_detection, distraction_blocker) VALUES
    -- Core focus categories
    ('Code',          600, TRUE,  TRUE,  TRUE,  FALSE),
    ('Reading',       900, TRUE,  TRUE,  TRUE,  FALSE),
    ('Writing',       600, TRUE,  TRUE,  TRUE,  FALSE),
    ('Design',        600, TRUE,  TRUE,  TRUE,  FALSE),
    ('Documenting',   600, TRUE,  TRUE,  TRUE,  FALSE),
    ('Learning',      600, TRUE,  TRUE,  TRUE,  FALSE),
    -- Work-adjacent
    ('Communication', 180, FALSE, TRUE,  TRUE,  FALSE),
    ('Email',         240, FALSE, TRUE,  TRUE,  FALSE),
    ('Messaging',     120, FALSE, TRUE,  TRUE,  FALSE),
    ('Meetings',      180, FALSE, TRUE,  FALSE, FALSE),
    ('In Person Meetings', 180, FALSE, TRUE, FALSE, FALSE),
    ('Customer Support',   180, FALSE, TRUE, TRUE, FALSE),
    ('Hiring',        300, FALSE, TRUE,  TRUE,  FALSE),
    ('Marketing',     300, FALSE, TRUE,  TRUE,  FALSE),
    ('Admin',         300, FALSE, TRUE,  TRUE,  FALSE),
    ('Finance',       300, FALSE, TRUE,  TRUE,  FALSE),
    -- Non-work / utilities
    ('Browsing',      300, FALSE, FALSE, TRUE,  FALSE),
    ('Media',         600, FALSE, FALSE, FALSE, TRUE),
    ('Entertainment', 600, FALSE, FALSE, FALSE, TRUE),
    ('Gaming',        600, FALSE, FALSE, FALSE, TRUE),
    ('Utilities',     180, FALSE, FALSE, TRUE,  FALSE),
    ('Break',         600, FALSE, FALSE, FALSE, FALSE),
    ('Miscellaneous', 300, FALSE, FALSE, TRUE,  FALSE),
    ('Other',         300, FALSE, FALSE, TRUE,  FALSE)
ON CONFLICT (category) DO NOTHING;

-- Seed common macOS app categories
INSERT INTO category_mappings (bundle_id, category) VALUES
    -- Coding: IDEs & editors
    ('com.apple.dt.Xcode',                'Code'),
    ('com.microsoft.VSCode',              'Code'),
    ('com.todesktop.230313mzl4w4u92',     'Code'),    -- Cursor
    ('com.sublimetext.4',                 'Code'),
    ('com.jetbrains.intellij',            'Code'),
    ('com.jetbrains.intellij.ce',         'Code'),
    ('com.jetbrains.goland',              'Code'),
    ('com.jetbrains.pycharm',             'Code'),
    ('com.jetbrains.WebStorm',            'Code'),
    ('com.jetbrains.fleet',               'Code'),
    -- Coding: terminals
    ('com.googlecode.iterm2',             'Code'),
    ('com.apple.Terminal',                'Code'),
    ('com.mitchellh.ghostty',             'Code'),
    ('dev.warp.Warp-Stable',              'Code'),
    -- Coding: AI assistants & dev tools
    ('com.anthropic.claudefordesktop',    'Code'),     -- Claude Desktop
    ('com.openai.chat',                   'Code'),     -- ChatGPT Desktop
    ('com.postmanlabs.mac',               'Code'),     -- Postman
    ('com.t3tools.t3code',                'Code'),     -- T3 Code (Alpha)
    -- Browsers
    ('com.apple.Safari',                  'Browsing'),
    ('com.google.Chrome',                 'Browsing'),
    ('com.google.Chrome.canary',          'Browsing'),
    ('company.thebrowser.Browser',        'Browsing'),
    ('com.brave.Browser',                 'Browsing'),
    ('org.mozilla.firefox',               'Reading'),
    ('com.vivaldi.Vivaldi',               'Browsing'),
    ('com.operasoftware.Opera',           'Browsing'),
    ('org.chromium.Chromium',             'Browsing'),
    -- Communication
    ('com.tinyspeck.slackmacgap',         'Communication'),
    ('us.zoom.xos',                       'Communication'),
    ('com.microsoft.teams2',              'Communication'),
    ('com.apple.MobileSMS',               'Communication'),
    ('com.apple.mail',                    'Communication'),
    ('com.readdle.smartemail-macos',       'Communication'),
    ('ru.keepcoder.Telegram',             'Communication'),
    ('com.hnc.Discord',                   'Communication'),
    ('net.whatsapp.WhatsApp',             'Communication'),
    ('com.apple.FaceTime',                'Communication'),
    -- Design
    ('com.figma.Desktop',                 'Design'),
    ('com.bohemiancoding.sketch3',        'Design'),
    -- Writing
    ('com.apple.iWork.Pages',             'Writing'),
    ('com.microsoft.Word',                'Writing'),
    ('md.obsidian',                       'Writing'),
    ('com.apple.Notes',                   'Writing'),
    ('net.shinyfrog.bear',                'Writing'),
    ('notion.id',                         'Writing'),
    -- Media
    ('com.apple.Music',                   'Media'),
    ('com.spotify.client',                'Media'),
    ('com.apple.QuickTimePlayerX',        'Media'),
    ('com.apple.TV',                      'Media'),
    -- Utilities
    ('com.apple.finder',                  'Utilities'),
    ('com.apple.systempreferences',       'Utilities'),
    ('com.apple.ActivityMonitor',         'Utilities'),
    ('com.raycast.macos',                 'Utilities'),
    ('com.1password.1password',           'Utilities'),
    ('abhinavgpt.personale',              'Utilities'),
    -- Reading
    ('com.apple.iBooksX',                 'Reading'),
    ('com.apple.Preview',                 'Reading')
ON CONFLICT (bundle_id) DO NOTHING;

-- Review pipeline: user-editable title/description per focus-session block.
-- block_key = sha256(date + startTime + endTime + category) keeps a stable row
-- across re-derivation as long as the merge boundaries don't shift.
CREATE TABLE IF NOT EXISTS session_reviews (
    block_key       TEXT PRIMARY KEY,
    block_date      DATE        NOT NULL,
    start_time      TEXT        NOT NULL,   -- "HH:mm"
    end_time        TEXT        NOT NULL,   -- "HH:mm"
    category        TEXT        NOT NULL,
    title           TEXT,
    description     TEXT,
    task            TEXT,
    project         TEXT,
    client          TEXT,
    status          TEXT        NOT NULL DEFAULT 'pending',  -- pending|approved|rejected
    ai_title        TEXT,
    ai_description  TEXT,
    ai_model        TEXT,
    ai_generated_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_session_reviews_date_status ON session_reviews (block_date, status);

-- M16: AI-generated insights attached to a pomodoro session (title + description).
CREATE TABLE IF NOT EXISTS pomodoro_session_insights (
    session_id      BIGINT PRIMARY KEY,
    title           TEXT    NOT NULL,
    description     TEXT    NOT NULL,
    model           TEXT    NOT NULL,
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- M11: Pomodoro sessions — user-initiated focus intervals with a goal string.
CREATE TABLE IF NOT EXISTS pomodoro_sessions (
    id              BIGSERIAL PRIMARY KEY,
    goal            TEXT    NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    target_seconds  INT     NOT NULL,
    status          TEXT    NOT NULL   -- 'running' | 'completed' | 'discarded'
);
CREATE INDEX IF NOT EXISTS idx_pomodoro_started_at ON pomodoro_sessions (started_at);

-- M13: Tracking rules — per-app / per-domain overrides with keyword filters
-- and behavior flags (blocking, title/URL capture toggles).
CREATE TABLE IF NOT EXISTS tracking_rules (
    id                  BIGSERIAL PRIMARY KEY,
    source              TEXT    NOT NULL,   -- 'macos' | 'browser'
    app_name            TEXT    NOT NULL,   -- bundle id (macos) or domain (browser)
    keywords            TEXT,               -- comma-separated, optional
    category            TEXT    NOT NULL,
    always_block        BOOLEAN NOT NULL DEFAULT FALSE,
    block_breaks        BOOLEAN NOT NULL DEFAULT FALSE,
    block_meetings      BOOLEAN NOT NULL DEFAULT FALSE,
    block_focus         BOOLEAN NOT NULL DEFAULT FALSE,
    track_titles        BOOLEAN NOT NULL DEFAULT TRUE,
    track_full_urls     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tracking_rules_source_app
    ON tracking_rules (source, app_name);

-- Browser navigation events (enriches "Browsing" app sessions with per-site detail)
CREATE TABLE IF NOT EXISTS browser_events (
    id              BIGSERIAL PRIMARY KEY,
    domain          TEXT NOT NULL,
    title           TEXT,
    url             TEXT,
    browser         TEXT,
    timestamp       TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_browser_events_timestamp ON browser_events (timestamp);

-- Domain → category mapping for browser enrichment
CREATE TABLE IF NOT EXISTS domain_category_mappings (
    id          BIGSERIAL PRIMARY KEY,
    domain      TEXT NOT NULL UNIQUE,
    category    TEXT NOT NULL
);

-- Seed common domains
INSERT INTO domain_category_mappings (domain, category) VALUES
    -- Code
    ('github.com',                  'Code'),
    ('gitlab.com',                  'Code'),
    ('bitbucket.org',               'Code'),
    ('stackoverflow.com',           'Code'),
    ('stackexchange.com',           'Code'),
    ('console.cloud.google.com',    'Code'),
    ('console.aws.amazon.com',      'Code'),
    ('portal.azure.com',            'Code'),
    ('sentry.io',                   'Code'),
    ('vercel.com',                  'Code'),
    ('netlify.com',                 'Code'),
    ('npmjs.com',                   'Code'),
    ('pypi.org',                    'Code'),
    ('crates.io',                   'Code'),
    ('hub.docker.com',              'Code'),
    -- Communication
    ('gmail.com',                   'Communication'),
    ('mail.google.com',             'Communication'),
    ('outlook.live.com',            'Communication'),
    ('outlook.office365.com',       'Communication'),
    ('slack.com',                   'Communication'),
    ('discord.com',                 'Communication'),
    ('teams.microsoft.com',         'Communication'),
    ('web.whatsapp.com',            'Communication'),
    ('web.telegram.org',            'Communication'),
    -- Media
    ('youtube.com',                 'Media'),
    ('netflix.com',                 'Media'),
    ('twitch.tv',                   'Media'),
    ('spotify.com',                 'Media'),
    ('music.apple.com',             'Media'),
    ('soundcloud.com',              'Media'),
    -- Writing
    ('docs.google.com',             'Writing'),
    ('notion.so',                   'Writing'),
    ('medium.com',                  'Writing'),
    ('substack.com',                'Writing'),
    ('overleaf.com',                'Writing'),
    -- Reading
    ('news.ycombinator.com',        'Reading'),
    ('reddit.com',                  'Reading'),
    ('wikipedia.org',               'Reading'),
    ('arxiv.org',                   'Reading'),
    ('dev.to',                      'Reading'),
    -- Design
    ('figma.com',                   'Design'),
    ('dribbble.com',                'Design'),
    ('behance.net',                 'Design'),
    ('canva.com',                   'Design'),
    -- Work infrastructure
    ('docs.aws.amazon.com',         'Code'),
    ('community.grafana.com',       'Code'),
    ('notebooklm.google.com',       'Writing'),
    ('grafana.internal-apps.emergentagent.com',    'Code'),
    ('argocd.internal-apps.emergentagent.com',     'Code'),
    ('argocd.internal-staging.emergentagent.com',  'Code'),
    ('sso.emergentagent.com',                      'Code')
ON CONFLICT (domain) DO NOTHING;
