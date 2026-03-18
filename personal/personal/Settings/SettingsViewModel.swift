#if os(macOS)
import Combine
import Foundation
import SwiftUI

struct TrackedApp: Identifiable {
    let id: String
    let appName: String
    let bundleId: String?
    var category: String
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apps: [TrackedApp] = []
    @Published var totalSessions: Int = 0
    @Published var totalMappings: Int = 0
    @Published var dbPath: String = ""

    private let db = DatabaseManager.shared
    private let stats = StatsEngine.shared

    let allCategories = [
        "Code", "Browsing", "Communication", "Design",
        "Writing", "Media", "Utilities", "Reading", "Other"
    ]

    func load() {
        loadApps()
        loadDBInfo()
    }

    private func loadApps() {
        // Get all unique apps that have been tracked
        let rows = db.query("""
            SELECT DISTINCT app_name, bundle_id FROM app_sessions
            ORDER BY app_name COLLATE NOCASE
        """)

        apps = rows.compactMap { row in
            guard let appName = row["app_name"] as? String else { return nil }
            let bundleId = row["bundle_id"] as? String
            let category = stats.resolveCategory(bundleId)
            let id = bundleId ?? appName
            return TrackedApp(id: id, appName: appName, bundleId: bundleId, category: category)
        }
    }

    private func loadDBInfo() {
        let sessionRows = db.query("SELECT COUNT(*) as cnt FROM app_sessions")
        totalSessions = (sessionRows.first?["cnt"] as? Int) ?? 0

        let mappingRows = db.query("SELECT COUNT(*) as cnt FROM category_mappings")
        totalMappings = (mappingRows.first?["cnt"] as? Int) ?? 0

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dbPath = appSupport.appendingPathComponent("Personale/personale.db").path
    }

    func updateCategory(bundleId: String?, appName: String, to newCategory: String) {
        guard let bid = bundleId else { return }

        // Upsert into category_mappings
        db.execute("""
            INSERT INTO category_mappings (bundle_id, category) VALUES (?, ?)
            ON CONFLICT(bundle_id) DO UPDATE SET category = excluded.category
        """, params: [bid, newCategory])

        // Invalidate the category cache in StatsEngine
        stats.invalidateCategoryCache()

        // Update local state
        if let idx = apps.firstIndex(where: { $0.bundleId == bid }) {
            apps[idx] = TrackedApp(id: apps[idx].id, appName: apps[idx].appName,
                                   bundleId: apps[idx].bundleId, category: newCategory)
        }
    }
}
#endif
