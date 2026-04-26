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
    let topDomains: [DomainTimeResponse]?

    var id: String { "\(name)-\(startTime)" }
}

struct SessionAppBreakdownResponse: Decodable, Identifiable {
    let appName: String
    let bundleId: String?
    let category: String
    let totalSeconds: Int
    let percent: Int
    let domains: [DomainTimeResponse]?

    var id: String { appName }
}

struct DomainTimeResponse: Decodable, Identifiable {
    let domain: String
    let seconds: Int

    var id: String { domain }
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

// MARK: - Domain Stats Response Models

struct DomainStatsResponse: Decodable {
    let categoryDetails: [CategoryDetail]
}

struct CategoryDetail: Decodable {
    let category: String
    let totalSeconds: Int
    let sources: [CategorySource]
}

struct CategorySource: Decodable, Identifiable {
    let name: String
    let type: String  // "app" or "domain"
    let seconds: Int

    var id: String { "\(type)-\(name)" }
}

// MARK: - Context switches per hour

struct ContextSwitchHour: Decodable, Identifiable {
    let hour: Int
    let switches: Int

    var id: Int { hour }
}

// MARK: - Interruptors (M10 polish)

struct InterruptorResponse: Decodable, Identifiable {
    let appName: String
    let bundleId: String?
    let category: String
    let count: Int
    let totalSeconds: Int

    var id: String { bundleId ?? appName }
}

// MARK: - Category Settings (M12)

struct CategoryResponse: Decodable, Identifiable {
    let name: String
    let idleThresholdSeconds: Int
    let focus: Bool
    let workHours: Bool
    let idleDetection: Bool
    let distractionBlocker: Bool
    let dailyGoalSeconds: Int
    let goalIsMax: Bool

    var id: String { name }
    var hasGoal: Bool { dailyGoalSeconds > 0 }
}

struct CategoryUpdateRequest: Encodable {
    var idleThresholdSeconds: Int?
    var focus: Bool?
    var workHours: Bool?
    var idleDetection: Bool?
    var distractionBlocker: Bool?
    var dailyGoalSeconds: Int?
    var goalIsMax: Bool?
}

struct CategoryCreateRequest: Encodable {
    let name: String
    let idleThresholdSeconds: Int?
    let focus: Bool?
    let workHours: Bool?
    let idleDetection: Bool?
    let distractionBlocker: Bool?
    let dailyGoalSeconds: Int?
    let goalIsMax: Bool?
}

// MARK: - Tracking Rules (M13)

struct TrackingRuleResponse: Decodable, Identifiable {
    let id: Int64
    let source: String          // "macos" | "browser"
    let appName: String
    let keywords: String?
    let category: String
    let alwaysBlock: Bool
    let blockBreaks: Bool
    let blockMeetings: Bool
    let blockFocus: Bool
    let trackTitles: Bool
    let trackFullUrls: Bool
}

// MARK: - Pomodoro (M11)

struct PomodoroSessionResponse: Decodable, Identifiable {
    let id: Int64
    let goal: String
    let startedAt: String       // ISO-8601
    let endedAt: String?
    let targetSeconds: Int
    let durationSeconds: Int
    let status: String          // running | completed | discarded
}

// MARK: - Session Reviews (Time Entry Review)

struct SessionReviewResponse: Decodable, Identifiable {
    let blockKey: String
    let date: String
    let startTime: String
    let endTime: String
    let durationSeconds: Int
    let category: String
    let title: String?
    let description: String?
    let task: String?
    let project: String?
    let client: String?
    let status: String              // pending | approved | rejected
    let aiTitle: String?
    let aiDescription: String?
    let aiGeneratedAt: String?
    let apps: [AppTimeEntry]
    let categories: [CategoryBreakdownResponse]
    let topDomains: [DomainTimeResponse]?

    var id: String { blockKey }
}

struct SessionReviewUpdateRequest: Encodable {
    var title: String?
    var description: String?
    var task: String?
    var project: String?
    var client: String?
    var category: String?
}

// MARK: - Session Insights (M16)

struct SessionInsightResponse: Decodable {
    let sessionId: Int64
    let title: String
    let description: String
    let model: String
    let generatedAt: String
}

struct PomodoroStartRequest: Encodable {
    let goal: String
    let targetSeconds: Int
}

struct TrackingRuleRequest: Encodable {
    var source: String?
    var appName: String?
    var keywords: String?
    var category: String?
    var alwaysBlock: Bool?
    var blockBreaks: Bool?
    var blockMeetings: Bool?
    var blockFocus: Bool?
    var trackTitles: Bool?
    var trackFullUrls: Bool?
}

// MARK: - API Client

class APIClient {
    static let shared = APIClient()

    let baseURL: URL

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL = AppSettings.shared.serverBaseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    /// Current user-configured day start hour. Attached to every day/range
    /// request so the server can window results correctly.
    private var dayStartParam: [String: String] {
        ["dayStartHour": String(AppSettings.shared.dayStartHour)]
    }

    func fetchDayStats(date: String) async throws -> DailyStatsResponse {
        try await get("/api/stats/day", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchTimeline(date: String) async throws -> [TimelineEntryResponse] {
        try await get("/api/stats/timeline", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchActivity(date: String) async throws -> [ActivityLogEntryResponse] {
        try await get("/api/stats/activity", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchCategories(date: String) async throws -> [CategoryBreakdownResponse] {
        try await get("/api/stats/categories", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchWorkblocks(date: String) async throws -> [WorkblockEntryResponse] {
        try await get("/api/stats/workblocks", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchSessions(date: String) async throws -> [FocusSessionResponse] {
        try await get("/api/stats/sessions", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchRange(from: String, to: String) async throws -> RangeResponse {
        try await get("/api/stats/range", params: ["from": from, "to": to].merging(dayStartParam) { a, _ in a })
    }

    func fetchRangeSummary(from: String, to: String) async throws -> RangeSummaryResponse {
        try await get("/api/stats/range/summary", params: ["from": from, "to": to].merging(dayStartParam) { a, _ in a })
    }

    func fetchInterruptors(date: String) async throws -> [InterruptorResponse] {
        try await get("/api/stats/interruptors", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchContextSwitches(date: String) async throws -> [ContextSwitchHour] {
        try await get("/api/stats/context-switches",
                      params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchInterruptorsRange(from: String, to: String) async throws -> [InterruptorResponse] {
        try await get("/api/stats/interruptors/range",
                      params: ["from": from, "to": to].merging(dayStartParam) { a, _ in a })
    }

    func fetchDomainStats(date: String) async throws -> DomainStatsResponse {
        try await get("/api/stats/domains", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    // MARK: - Category Settings (M12)

    func fetchCategorySettings() async throws -> [CategoryResponse] {
        try await get("/api/categories")
    }

    func createCategory(_ req: CategoryCreateRequest) async throws -> CategoryResponse {
        try await body("/api/categories", method: "POST", body: req)
    }

    func updateCategory(_ name: String, _ req: CategoryUpdateRequest) async throws -> CategoryResponse {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await body("/api/categories/\(encoded)", method: "PUT", body: req)
    }

    func deleteCategory(_ name: String) async throws {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        try await delete("/api/categories/\(encoded)")
    }

    /// Upsert a single bundleId → category mapping (used by on-device
    /// auto-classifier). Writes through to `category_mappings`.
    struct MappingUpsert: Encodable {
        let bundleId: String
        let category: String
    }
    struct MappingUpsertAck: Decodable {
        let bundleId: String
        let category: String
    }
    func upsertCategoryMapping(bundleId: String, category: String) async throws {
        let _: MappingUpsertAck = try await body(
            "/api/settings/categories/mapping", method: "PUT",
            body: MappingUpsert(bundleId: bundleId, category: category))
    }

    // MARK: - Tracking Rules (M13)

    func fetchTrackingRules() async throws -> [TrackingRuleResponse] {
        try await get("/api/tracking-rules")
    }

    func createTrackingRule(_ req: TrackingRuleRequest) async throws -> TrackingRuleResponse {
        try await body("/api/tracking-rules", method: "POST", body: req)
    }

    func updateTrackingRule(_ id: Int64, _ req: TrackingRuleRequest) async throws -> TrackingRuleResponse {
        try await body("/api/tracking-rules/\(id)", method: "PUT", body: req)
    }

    func deleteTrackingRule(_ id: Int64) async throws {
        try await delete("/api/tracking-rules/\(id)")
    }

    // MARK: - Pomodoro (M11)

    func startPomodoro(goal: String, targetSeconds: Int) async throws -> PomodoroSessionResponse {
        try await body("/api/pomodoro/start", method: "POST",
                       body: PomodoroStartRequest(goal: goal, targetSeconds: targetSeconds))
    }

    func endPomodoro(id: Int64, discard: Bool) async throws -> PomodoroSessionResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/pomodoro/\(id)/end")
                                .appending(queryItems: [URLQueryItem(name: "discard", value: String(discard))]))
        req.httpMethod = "POST"
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(PomodoroSessionResponse.self, from: data)
    }

    func fetchPomodoros(date: String) async throws -> [PomodoroSessionResponse] {
        try await get("/api/pomodoro", params: ["date": date].merging(dayStartParam) { a, _ in a })
    }

    func fetchInsight(sessionId: Int64) async throws -> SessionInsightResponse? {
        let url = baseURL.appendingPathComponent("/api/pomodoro/\(sessionId)/insight")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(SessionInsightResponse.self, from: data)
    }

    // MARK: - Session Reviews

    func fetchReviews(date: String, status: String = "all") async throws -> [SessionReviewResponse] {
        try await get("/api/reviews",
            params: ["date": date, "status": status].merging(dayStartParam) { a, _ in a })
    }

    func updateReview(key: String, date: String, req: SessionReviewUpdateRequest) async throws -> SessionReviewResponse {
        let dsh = AppSettings.shared.dayStartHour
        var urlReq = URLRequest(url: baseURL.appendingPathComponent("/api/reviews/\(key)")
            .appending(queryItems: [
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "dayStartHour", value: String(dsh))
            ]))
        urlReq.httpMethod = "PUT"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = try JSONEncoder().encode(req)
        let (data, response) = try await session.data(for: urlReq)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let b = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "review-update",
                          code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: b])
        }
        return try decoder.decode(SessionReviewResponse.self, from: data)
    }

    func setReviewStatus(key: String, date: String, status: String) async throws -> SessionReviewResponse {
        let dsh = AppSettings.shared.dayStartHour
        var urlReq = URLRequest(url: baseURL.appendingPathComponent("/api/reviews/\(key)/status")
            .appending(queryItems: [
                URLQueryItem(name: "status", value: status),
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "dayStartHour", value: String(dsh))
            ]))
        urlReq.httpMethod = "POST"
        let (data, response) = try await session.data(for: urlReq)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(SessionReviewResponse.self, from: data)
    }

    /// Batch: regenerate every block on the day that has no AI draft yet.
    func generateMissingReviewInsights(date: String) async throws -> [SessionReviewResponse] {
        try await batchRegen(date: date, path: "/api/reviews/generate-missing")
    }

    /// Force-regenerate every block on the day, replacing existing AI drafts.
    /// Use when the prompt has improved and old summaries are stale.
    func regenerateAllReviewInsights(date: String) async throws -> [SessionReviewResponse] {
        try await batchRegen(date: date, path: "/api/reviews/regenerate-all")
    }

    private func batchRegen(date: String, path: String) async throws -> [SessionReviewResponse] {
        let dsh = AppSettings.shared.dayStartHour
        var urlReq = URLRequest(url: baseURL.appendingPathComponent(path)
            .appending(queryItems: [
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "dayStartHour", value: String(dsh))
            ]))
        urlReq.httpMethod = "POST"
        urlReq.timeoutInterval = 180
        let (data, response) = try await session.data(for: urlReq)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode([SessionReviewResponse].self, from: data)
    }

    func generateReviewInsight(key: String, date: String) async throws -> SessionReviewResponse {
        let dsh = AppSettings.shared.dayStartHour
        var urlReq = URLRequest(url: baseURL.appendingPathComponent("/api/reviews/\(key)/generate")
            .appending(queryItems: [
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "dayStartHour", value: String(dsh))
            ]))
        urlReq.httpMethod = "POST"
        urlReq.timeoutInterval = 30
        let (data, response) = try await session.data(for: urlReq)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "review-insight", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
        return try decoder.decode(SessionReviewResponse.self, from: data)
    }

    func generateInsight(sessionId: Int64) async throws -> SessionInsightResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/pomodoro/\(sessionId)/insight"))
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "insight", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
        return try decoder.decode(SessionInsightResponse.self, from: data)
    }

    private func delete(_ path: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func body<Req: Encodable, T: Decodable>(_ path: String, method: String, body: Req) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
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
