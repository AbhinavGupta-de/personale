#if os(macOS)
import Foundation
import SQLite3

/// Manages SQLite database lifecycle and provides low-level query execution.
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.personale.database", qos: .userInitiated)

    private init() {
        openDatabase()
        createTables()
        seedCategories()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Setup

    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("Personale")

        try? fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("personale.db").path
        print("[DatabaseManager] Opening database at \(dbPath)")

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("[DatabaseManager] Failed to open database: \(errmsg)")
            return
        }

        // Enable WAL mode for better concurrent read performance
        execute("PRAGMA journal_mode=WAL")
        execute("PRAGMA foreign_keys=ON")
    }

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS app_sessions (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name        TEXT NOT NULL,
                bundle_id       TEXT,
                window_title    TEXT,
                started_at      TEXT NOT NULL,
                ended_at        TEXT,
                CHECK (ended_at IS NULL OR ended_at >= started_at)
            )
        """)

        execute("CREATE INDEX IF NOT EXISTS idx_sessions_range ON app_sessions (started_at, ended_at)")
        execute("CREATE INDEX IF NOT EXISTS idx_sessions_active ON app_sessions (started_at) WHERE ended_at IS NULL")

        execute("""
            CREATE TABLE IF NOT EXISTS category_mappings (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                bundle_id   TEXT NOT NULL UNIQUE,
                category    TEXT NOT NULL
            )
        """)
    }

    // Pre-seed common macOS app categories (same as the PostgreSQL schema)
    private func seedCategories() {
        let mappings: [(String, String)] = [
            // Coding: IDEs & editors
            ("com.apple.dt.Xcode", "Code"),
            ("com.microsoft.VSCode", "Code"),
            ("com.todesktop.230313mzl4w4u92", "Code"),     // Cursor
            ("com.sublimetext.4", "Code"),
            ("com.jetbrains.intellij", "Code"),
            ("com.jetbrains.intellij.ce", "Code"),
            ("com.jetbrains.goland", "Code"),
            ("com.jetbrains.pycharm", "Code"),
            ("com.jetbrains.WebStorm", "Code"),
            ("com.jetbrains.fleet", "Code"),
            // Coding: terminals
            ("com.googlecode.iterm2", "Code"),
            ("com.apple.Terminal", "Code"),
            ("com.mitchellh.ghostty", "Code"),
            ("dev.warp.Warp-Stable", "Code"),
            // Coding: AI assistants & dev tools
            ("com.anthropic.claudefordesktop", "Code"),
            ("com.openai.chat", "Code"),
            ("com.postmanlabs.mac", "Code"),
            ("com.t3tools.t3code", "Code"),
            // Browsers
            ("com.apple.Safari", "Browsing"),
            ("com.google.Chrome", "Browsing"),
            ("com.google.Chrome.canary", "Browsing"),
            ("company.thebrowser.Browser", "Browsing"),
            ("com.brave.Browser", "Browsing"),
            ("org.mozilla.firefox", "Browsing"),
            ("com.vivaldi.Vivaldi", "Browsing"),
            ("com.operasoftware.Opera", "Browsing"),
            ("org.chromium.Chromium", "Browsing"),
            // Communication
            ("com.tinyspeck.slackmacgap", "Communication"),
            ("us.zoom.xos", "Communication"),
            ("com.microsoft.teams2", "Communication"),
            ("com.apple.MobileSMS", "Communication"),
            ("com.apple.mail", "Communication"),
            ("com.readdle.smartemail-macos", "Communication"),
            ("ru.keepcoder.Telegram", "Communication"),
            ("com.hnc.Discord", "Communication"),
            ("net.whatsapp.WhatsApp", "Communication"),
            ("com.apple.FaceTime", "Communication"),
            // Design
            ("com.figma.Desktop", "Design"),
            ("com.bohemiancoding.sketch3", "Design"),
            // Writing
            ("com.apple.iWork.Pages", "Writing"),
            ("com.microsoft.Word", "Writing"),
            ("md.obsidian", "Writing"),
            ("com.apple.Notes", "Writing"),
            ("net.shinyfrog.bear", "Writing"),
            ("notion.id", "Writing"),
            // Media
            ("com.apple.Music", "Media"),
            ("com.spotify.client", "Media"),
            ("com.apple.QuickTimePlayerX", "Media"),
            ("com.apple.TV", "Media"),
            // Utilities
            ("com.apple.finder", "Utilities"),
            ("com.apple.systempreferences", "Utilities"),
            ("com.apple.ActivityMonitor", "Utilities"),
            ("com.raycast.macos", "Utilities"),
            ("com.1password.1password", "Utilities"),
            ("abhinavgpt.personale", "Utilities"),
            // Reading
            ("com.apple.iBooksX", "Reading"),
            ("com.apple.Preview", "Reading"),
        ]

        for (bundleId, category) in mappings {
            execute(
                "INSERT OR IGNORE INTO category_mappings (bundle_id, category) VALUES (?, ?)",
                params: [bundleId, category]
            )
        }
    }

    // MARK: - Query Execution

    @discardableResult
    func execute(_ sql: String, params: [Any?] = []) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("[DatabaseManager] Prepare failed: \(errmsg) — SQL: \(sql)")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        bindParams(stmt: stmt, params: params)

        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE && result != SQLITE_ROW {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("[DatabaseManager] Step failed: \(errmsg) — SQL: \(sql)")
            return false
        }
        return true
    }

    func query(_ sql: String, params: [Any?] = []) -> [[String: Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("[DatabaseManager] Prepare failed: \(errmsg) — SQL: \(sql)")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        bindParams(stmt: stmt, params: params)

        var rows: [[String: Any]] = []
        let columnCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(stmt, i))
                case SQLITE_TEXT:
                    row[name] = String(cString: sqlite3_column_text(stmt, i))
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_NULL:
                    row[name] = nil as Any?
                default:
                    break
                }
            }
            rows.append(row)
        }
        return rows
    }

    func lastInsertRowId() -> Int {
        Int(sqlite3_last_insert_rowid(db))
    }

    private func bindParams(stmt: OpaquePointer?, params: [Any?]) {
        for (index, param) in params.enumerated() {
            let i = Int32(index + 1)
            if param == nil {
                sqlite3_bind_null(stmt, i)
            } else if let val = param as? String {
                sqlite3_bind_text(stmt, i, (val as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else if let val = param as? Int {
                sqlite3_bind_int64(stmt, i, Int64(val))
            } else if let val = param as? Double {
                sqlite3_bind_double(stmt, i, val)
            }
        }
    }
}
#endif
