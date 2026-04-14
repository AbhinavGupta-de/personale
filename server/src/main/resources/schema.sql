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

-- M4: per-category idle thresholds (how long a gap before a session is split)
-- Reading allows long pauses (thinking, scrolling); Communication needs snappy cuts.
CREATE TABLE IF NOT EXISTS category_thresholds (
    category               TEXT PRIMARY KEY,
    idle_threshold_seconds INT  NOT NULL
);

INSERT INTO category_thresholds (category, idle_threshold_seconds) VALUES
    ('Code',          600),   -- 10 min: natural thinking pauses
    ('Reading',       900),   -- 15 min: long scroll/read sessions
    ('Writing',       600),   -- 10 min: think, draft, revise
    ('Design',        600),   -- 10 min: contemplate, iterate
    ('Communication', 180),   -- 3 min: chats are snappy
    ('Browsing',      300),   -- 5 min: tab-switching noise
    ('Media',         600),   -- 10 min: passive consumption
    ('Utilities',     180),   -- 3 min: quick task tools
    ('Other',         300)    -- 5 min: default
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
    ('org.mozilla.firefox',               'Browsing'),
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
