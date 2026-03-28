#if os(macOS)
import Foundation
import SQLite3

final class LocalEventStore {
    static let shared = LocalEventStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.abhinavgpt.personale.localstore", qos: .utility)

    private init() {
        openDatabase()
        createTable()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("abhinavgpt.personale")

        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        let dbPath = appDir.appendingPathComponent("events.db").path
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[LocalEventStore] Failed to open database at \(dbPath)")
            db = nil
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS pending_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                app_name TEXT,
                bundle_id TEXT,
                window_title TEXT,
                session_started_at TEXT,
                timestamp TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                synced INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_pending_unsynced ON pending_events (synced) WHERE synced = 0;
            """
        queue.sync {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown"
                print("[LocalEventStore] Failed to create table: \(msg)")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Insert

    func insertAppSwitch(appName: String, bundleId: String?, windowTitle: String?, timestamp: String) {
        insert(type: "app_switch", appName: appName, bundleId: bundleId, windowTitle: windowTitle,
               sessionStartedAt: nil, timestamp: timestamp)
    }

    func insertSessionClose(timestamp: String, bundleId: String?, sessionStartedAt: String?) {
        insert(type: "session_close", appName: nil, bundleId: bundleId, windowTitle: nil,
               sessionStartedAt: sessionStartedAt, timestamp: timestamp)
    }

    private func insert(type: String, appName: String?, bundleId: String?, windowTitle: String?,
                        sessionStartedAt: String?, timestamp: String) {
        queue.async { [weak self] in
            guard let db = self?.db else { return }
            let sql = """
                INSERT INTO pending_events (type, app_name, bundle_id, window_title, session_started_at, timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                print("[LocalEventStore] Failed to prepare insert")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (type as NSString).utf8String, -1, nil)
            Self.bindOptionalText(stmt, index: 2, value: appName)
            Self.bindOptionalText(stmt, index: 3, value: bundleId)
            Self.bindOptionalText(stmt, index: 4, value: windowTitle)
            Self.bindOptionalText(stmt, index: 5, value: sessionStartedAt)
            sqlite3_bind_text(stmt, 6, (timestamp as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[LocalEventStore] Failed to insert event")
            }
        }
    }

    // MARK: - Query Unsynced

    struct PendingEvent {
        let id: Int64
        let type: String
        let appName: String?
        let bundleId: String?
        let windowTitle: String?
        let sessionStartedAt: String?
        let timestamp: String
    }

    func fetchUnsynced(limit: Int = 50) -> [PendingEvent] {
        queue.sync {
            guard let db = db else { return [] }
            let sql = "SELECT id, type, app_name, bundle_id, window_title, session_started_at, timestamp FROM pending_events WHERE synced = 0 ORDER BY id ASC LIMIT ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int(stmt, 1, Int32(limit))

            var events: [PendingEvent] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let event = PendingEvent(
                    id: sqlite3_column_int64(stmt, 0),
                    type: String(cString: sqlite3_column_text(stmt, 1)),
                    appName: Self.optionalColumn(stmt, index: 2),
                    bundleId: Self.optionalColumn(stmt, index: 3),
                    windowTitle: Self.optionalColumn(stmt, index: 4),
                    sessionStartedAt: Self.optionalColumn(stmt, index: 5),
                    timestamp: String(cString: sqlite3_column_text(stmt, 6))
                )
                events.append(event)
            }
            return events
        }
    }

    // MARK: - Mark Synced

    func markSynced(id: Int64) {
        queue.async { [weak self] in
            guard let db = self?.db else { return }
            let sql = "UPDATE pending_events SET synced = 1 WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, id)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Unsynced Count

    func unsyncedCount() -> Int {
        queue.sync {
            guard let db = db else { return 0 }
            let sql = "SELECT COUNT(*) FROM pending_events WHERE synced = 0"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
        }
    }

    // MARK: - Cleanup

    func deleteOldSyncedEvents(olderThanDays days: Int = 7) {
        queue.async { [weak self] in
            guard let db = self?.db else { return }
            let sql = "DELETE FROM pending_events WHERE synced = 1 AND created_at < datetime('now', ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            let modifier = "-\(days) days"
            sqlite3_bind_text(stmt, 1, (modifier as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_DONE {
                let deleted = sqlite3_changes(db)
                if deleted > 0 {
                    print("[LocalEventStore] Cleaned up \(deleted) old synced events")
                }
            }
        }
    }

    // MARK: - Helpers

    private static func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let value = value {
            sqlite3_bind_text(stmt, index, (value as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static func optionalColumn(_ stmt: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return String(cString: sqlite3_column_text(stmt, index))
    }
}
#endif
