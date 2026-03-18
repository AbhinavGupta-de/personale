#if os(macOS)
import Foundation

// MARK: - Response Models (shared between StatsEngine and ViewModels)

struct DailyStatsResponse {
    let date: String
    let apps: [AppTimeEntry]
    let totalTrackedSeconds: Int
    let idleSessionCount: Int?
}

struct AppTimeEntry {
    let appName: String
    let bundleId: String?
    let totalSeconds: Int
}

struct TimelineEntryResponse {
    let startTime: String   // "HH:mm"
    let endTime: String     // "HH:mm"
    let appName: String
    let bundleId: String?
    let category: String
}

struct ActivityLogEntryResponse {
    let time: String        // "HH:mm:ss"
    let appName: String
    let bundleId: String?
    let detail: String
    let durationSeconds: Int
}

struct CategoryBreakdownResponse {
    let category: String
    let totalSeconds: Int
    let percent: Int
}

struct WorkblockEntryResponse {
    let time: String
    let task: String
    let duration: String
    let durationSeconds: Int
}

struct FocusSessionResponse: Identifiable {
    let name: String
    let startTime: String
    let endTime: String
    let durationSeconds: Int
    let duration: String
    let apps: [SessionAppBreakdownResponse]
    let categories: [CategoryBreakdownResponse]

    var id: String { "\(name)-\(startTime)" }
}

struct SessionAppBreakdownResponse: Identifiable {
    let appName: String
    let bundleId: String?
    let category: String
    let totalSeconds: Int
    let percent: Int

    var id: String { appName }
}
#endif
