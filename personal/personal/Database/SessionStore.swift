#if os(macOS)
import Foundation

/// Replaces EventClient + EventService — writes app sessions directly to SQLite.
final class SessionStore {
    static let shared = SessionStore()

    private let db = DatabaseManager.shared
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {
        closeOrphanedSessions()
    }

    /// Close any session left open from a previous crash/kill.
    private func closeOrphanedSessions() {
        let now = iso8601.string(from: Date())
        let rows = db.query("SELECT id, started_at FROM app_sessions WHERE ended_at IS NULL")
        for row in rows {
            guard let id = row["id"] as? Int else { continue }
            db.execute("UPDATE app_sessions SET ended_at = ? WHERE id = ?", params: [now, id])
            print("[SessionStore] Closed orphaned session id=\(id)")
        }
    }

    /// Handle an app switch: close current active session and start a new one.
    func saveAppSwitch(appName: String, bundleId: String?, windowTitle: String?, timestamp: String) {
        // Close the currently active session at this timestamp
        closeActiveSessionInternal(timestamp: timestamp)

        // Open a new session
        db.execute(
            "INSERT INTO app_sessions (app_name, bundle_id, window_title, started_at) VALUES (?, ?, ?, ?)",
            params: [appName, bundleId, windowTitle, timestamp]
        )
    }

    /// Close the active session (on sleep/idle).
    func closeActiveSession(timestamp: String) {
        closeActiveSessionInternal(timestamp: timestamp)
    }

    private func closeActiveSessionInternal(timestamp: String) {
        db.execute(
            "UPDATE app_sessions SET ended_at = ? WHERE ended_at IS NULL",
            params: [timestamp]
        )
    }
}
#endif
