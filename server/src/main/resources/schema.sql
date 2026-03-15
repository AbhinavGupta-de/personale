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
