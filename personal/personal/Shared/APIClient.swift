#if os(macOS)
import Foundation

// MARK: - API Response Models

struct DailyStatsResponse: Decodable {
    let date: String
    let apps: [AppTimeEntry]
    let totalTrackedSeconds: Int
    let idleSessionCount: Int?
}

struct AppTimeEntry: Decodable {
    let appName: String
    let bundleId: String?
    let totalSeconds: Int
}

struct TimelineEntryResponse: Decodable {
    let startTime: String   // "HH:mm"
    let endTime: String     // "HH:mm"
    let appName: String
    let bundleId: String?
    let category: String
}

struct ActivityLogEntryResponse: Decodable {
    let time: String        // "HH:mm:ss"
    let appName: String
    let bundleId: String?
    let detail: String
    let durationSeconds: Int
}

struct CategoryBreakdownResponse: Decodable {
    let category: String
    let totalSeconds: Int
    let percent: Int
}

struct WorkblockEntryResponse: Decodable {
    let time: String
    let task: String
    let duration: String
    let durationSeconds: Int
}

struct FocusSessionResponse: Decodable, Identifiable {
    let name: String
    let startTime: String
    let endTime: String
    let durationSeconds: Int
    let duration: String
    let apps: [SessionAppBreakdownResponse]
    let categories: [CategoryBreakdownResponse]

    var id: String { "\(name)-\(startTime)" }
}

struct SessionAppBreakdownResponse: Decodable, Identifiable {
    let appName: String
    let bundleId: String?
    let category: String
    let totalSeconds: Int
    let percent: Int

    var id: String { appName }
}

// MARK: - Range Response Models

struct RangeDayBreakdownResponse: Decodable {
    let date: String
    let totalTrackedSeconds: Int
    let categories: [RangeCategorySeconds]
}

struct RangeCategorySeconds: Decodable {
    let category: String
    let seconds: Int
}

struct RangeResponse: Decodable {
    let from: String
    let to: String
    let days: [RangeDayBreakdownResponse]
}

struct RangeSummaryResponse: Decodable {
    let from: String
    let to: String
    let totalTrackedSeconds: Int
    let daysWithData: Int
    let avgSecondsPerDay: Int
    let avgSecondsPerWeek: Int
    let categoryBreakdown: [CategoryBreakdownResponse]
}

// MARK: - API Client

class APIClient {
    static let shared = APIClient()

    let baseURL: URL

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL = URL(string: "http://localhost:8696")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    func fetchDayStats(date: String) async throws -> DailyStatsResponse {
        try await get("/api/stats/day", params: ["date": date])
    }

    func fetchTimeline(date: String) async throws -> [TimelineEntryResponse] {
        try await get("/api/stats/timeline", params: ["date": date])
    }

    func fetchActivity(date: String) async throws -> [ActivityLogEntryResponse] {
        try await get("/api/stats/activity", params: ["date": date])
    }

    func fetchCategories(date: String) async throws -> [CategoryBreakdownResponse] {
        try await get("/api/stats/categories", params: ["date": date])
    }

    func fetchWorkblocks(date: String) async throws -> [WorkblockEntryResponse] {
        try await get("/api/stats/workblocks", params: ["date": date])
    }

    func fetchSessions(date: String) async throws -> [FocusSessionResponse] {
        try await get("/api/stats/sessions", params: ["date": date])
    }

    func fetchRange(from: String, to: String) async throws -> RangeResponse {
        try await get("/api/stats/range", params: ["from": from, "to": to])
    }

    func fetchRangeSummary(from: String, to: String) async throws -> RangeSummaryResponse {
        try await get("/api/stats/range/summary", params: ["from": from, "to": to])
    }

    private func get<T: Decodable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }
}
#endif
