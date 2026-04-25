#if os(macOS)
import Combine
import Foundation
import SwiftUI

@MainActor
class ActivityViewModel: ObservableObject {
    enum ViewMode: String { case day = "Day"; case week = "Week" }

    @Published var selectedDate: Date = ActivityViewModel.effectiveToday(
        dayStartHour: AppSettings.shared.dayStartHour)
    @Published var isLoading = false
    @Published var sessions: [FocusSessionResponse] = []
    @Published var selectedSession: FocusSessionResponse?
    @Published var showSessionDetail = false
    @Published var dayStats: DailyStatsResponse?
    @Published var categoryBreakdown: [CategoryBreakdownResponse] = []
    @Published var viewMode: ViewMode = .day
    @Published var weekSessions: [String: [FocusSessionResponse]] = [:]
    @Published var reviewsByKey: [String: SessionReviewResponse] = [:]
    @Published var availableCategoryNames: [String] = []
    /// Dates we've already triggered batch AI generation for in this session.
    /// generate-missing skips already-drafted blocks server-side, but we still
    /// debounce client-side to avoid burning a request per 30s refresh tick.
    private var draftsRequestedDates: Set<String> = []

    var dayStartHour: Int { AppSettings.shared.dayStartHour }

    /// The calendar date whose "day window" currently contains `now`.
    /// If now is before `dayStartHour`, we're still inside the previous
    /// calendar date's window (e.g. 4am with dayStartHour=6 → yesterday).
    static func effectiveToday(dayStartHour: Int, now: Date = Date()) -> Date {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let start = cal.startOfDay(for: now)
        if hour < dayStartHour {
            return cal.date(byAdding: .day, value: -1, to: start) ?? start
        }
        return start
    }

    var effectiveToday: Date {
        Self.effectiveToday(dayStartHour: dayStartHour)
    }

    private let api = APIClient.shared
    private var cache: [String: [FocusSessionResponse]] = [:]
    private var activeFetchDate: String?

    private static let dateFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private static let displayFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d, yyyy"
        return fmt
    }()

    var dateString: String { Self.dateFmt.string(from: selectedDate) }
    var displayDate: String { Self.displayFmt.string(from: selectedDate) }

    var isToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: effectiveToday)
    }

    // MARK: - Week helpers

    var weekStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        return cal.date(from: comps) ?? selectedDate
    }

    var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? selectedDate
    }

    var weekDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var displayWeek: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: weekStart)) – \(fmt.string(from: weekEnd))"
    }

    var displayPeriod: String {
        viewMode == .day ? displayDate : displayWeek
    }

    var isCurrentPeriod: Bool {
        viewMode == .day
            ? isToday
            : Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    // MARK: - Navigation

    func load() {
        fetchSessions()
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        selectedSession = nil
        showSessionDetail = false
        navigateToCurrentDate()
    }

    func goToNextDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if tomorrow <= effectiveToday {
            selectedDate = tomorrow
            selectedSession = nil
            showSessionDetail = false
            navigateToCurrentDate()
        }
    }

    func goToToday() {
        selectedDate = effectiveToday
        selectedSession = nil
        showSessionDetail = false
        navigateToCurrentDate()
    }

    // MARK: - Week-aware navigation (used by DateNavigator)

    func goToPrevious() {
        switch viewMode {
        case .day:
            goToPreviousDay()
        case .week:
            selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            fetchWeek()
        }
    }

    func goToNext() {
        switch viewMode {
        case .day:
            goToNextDay()
        case .week:
            let next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            if next <= effectiveToday {
                selectedDate = next
                fetchWeek()
            }
        }
    }

    func goToCurrent() {
        switch viewMode {
        case .day:
            goToToday()
        case .week:
            selectedDate = effectiveToday
            fetchWeek()
        }
    }

    func switchViewMode(_ mode: ViewMode) {
        viewMode = mode
        if mode == .week { fetchWeek() }
    }

    private func fetchWeek() {
        // Backend windows each day by dayStartHour, so one fetch per day is enough.
        for i in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: i, to: weekStart),
                  date <= effectiveToday
            else { continue }
            let key = Self.dateFmt.string(from: date)
            if weekSessions[key] != nil { continue }
            Task {
                if let r = try? await api.fetchSessions(date: key) {
                    self.weekSessions[key] = r
                }
            }
        }
    }

    /// Sessions to render for a specific day in week view.
    func weekDisplaySessions(for date: Date) -> [FocusSessionResponse] {
        weekSessions[Self.dateFmt.string(from: date)] ?? []
    }

    private func navigateToCurrentDate() {
        let date = dateString
        if let cached = cache[date] {
            sessions = cached
            isLoading = false
        } else {
            sessions = []
            isLoading = true
        }
        fetchSessions()
    }

    func selectSession(_ session: FocusSessionResponse) {
        selectedSession = session
    }

    func clearSelectedSession() {
        selectedSession = nil
    }

    // MARK: - Session rating (M8 stub — UserDefaults-backed)

    func rating(for session: FocusSessionResponse) -> Int {
        UserDefaults.standard.integer(forKey: "rating-\(session.id)")
    }

    func setRating(_ rating: Int, for session: FocusSessionResponse) {
        UserDefaults.standard.set(rating, forKey: "rating-\(session.id)")
        objectWillChange.send()
    }

    // MARK: - Review lookup (title/description per block)

    /// Returns the review record for a session, if any. Matches on the same
    /// block_key formula used server-side: sha256(date|start|end|category).
    func review(for session: FocusSessionResponse, on date: Date? = nil) -> SessionReviewResponse? {
        let d = date ?? selectedDate
        let dateStr = Self.dateFmt.string(from: d)
        let key = ReviewKey.make(
            date: dateStr,
            startTime: session.startTime,
            endTime: session.endTime,
            category: session.name)
        return reviewsByKey[key]
    }

    func label(for session: FocusSessionResponse, on date: Date? = nil) -> String {
        let r = review(for: session, on: date)
        return bestLabel(title: r?.title, aiTitle: r?.aiTitle, category: session.name)
    }

    // MARK: - Quality Score (M8 stub — refined in M10)

    func qualityScore(for session: FocusSessionResponse) -> Int {
        // Heuristic stub: deduct points for fragmented categories
        // (proxy for interrupters until SessionMergeService exposes them).
        let categoryCount = session.categories.count
        let deduction = max(0, (categoryCount - 1) * 8)
        return max(0, 100 - deduction)
    }

    private func fetchSessions() {
        let date = dateString
        activeFetchDate = date
        if cache[date] == nil { isLoading = true }

        Task {
            guard let result = try? await api.fetchSessions(date: date),
                activeFetchDate == date
            else { return }
            self.sessions = result
            self.cache[date] = result
            self.isLoading = false
        }

        // Day-level data for Daily Summary.
        Task {
            guard let stats = try? await api.fetchDayStats(date: date),
                activeFetchDate == date
            else { return }
            self.dayStats = stats
        }
        Task {
            guard let cats = try? await api.fetchCategories(date: date),
                activeFetchDate == date
            else { return }
            self.categoryBreakdown = cats
        }
        // Reviews: map block_key → review for title/description lookup in the UI.
        // Also triggers AI-draft generation for blocks that don't have one yet,
        // so the title shows up without the user needing to visit Review first.
        Task {
            guard let reviews = try? await api.fetchReviews(date: date, status: "all"),
                activeFetchDate == date
            else { return }
            self.reviewsByKey = Dictionary(uniqueKeysWithValues: reviews.map { ($0.blockKey, $0) })

            let needsDraft = reviews.contains { $0.aiTitle == nil || ($0.aiTitle?.isEmpty ?? true) }
            if needsDraft && !self.draftsRequestedDates.contains(date) {
                self.draftsRequestedDates.insert(date)
                if let refreshed = try? await self.api.generateMissingReviewInsights(date: date),
                   self.activeFetchDate == date {
                    self.reviewsByKey = Dictionary(
                        uniqueKeysWithValues: refreshed.map { ($0.blockKey, $0) })
                }
            }
        }
        Task {
            if availableCategoryNames.isEmpty,
               let cats = try? await api.fetchCategorySettings() {
                self.availableCategoryNames = cats.map(\.name)
            }
        }

        // Prefetch adjacent
        for offset in [-1, 1] {
            guard let adjDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate),
                adjDate <= effectiveToday
            else { continue }
            let adjStr = Self.dateFmt.string(from: adjDate)
            guard cache[adjStr] == nil else { continue }
            Task {
                if let r = try? await api.fetchSessions(date: adjStr) {
                    self.cache[adjStr] = r
                }
            }
        }
    }

    // MARK: - Display sessions

    /// Sessions for the currently selected day. Backend already windows to
    /// `[dayStartHour, dayStartHour + 24h)` so no client-side filtering needed.
    var displaySessions: [FocusSessionResponse] { sessions }

    // MARK: - Daily Summary computed data

    var totalFocusSeconds: Int {
        displaySessions.reduce(0) { $0 + $1.durationSeconds }
    }

    var totalFocusDuration: String {
        formatDuration(totalFocusSeconds)
    }

    var sessionCount: Int { sessions.count }

    var percentOfTarget: Double {
        let targetSecs = AppSettings.shared.targetHoursPerDay * 3600
        return targetSecs > 0 ? Double(totalFocusSeconds) / Double(targetSecs) * 100 : 0
    }

    // MARK: - Weekly Summary computed data

    var weekTotalFocusSeconds: Int {
        weekSessions.values.flatMap { $0 }.reduce(0) { $0 + $1.durationSeconds }
    }

    var weekTotalFocusDuration: String { formatDuration(weekTotalFocusSeconds) }

    var weekEntryCount: Int {
        weekSessions.values.map(\.count).reduce(0, +)
    }

    var weekCategoryBreakdown: [(category: String, totalSeconds: Int, percent: Int)] {
        var totals: [String: Int] = [:]
        for sessions in weekSessions.values {
            for s in sessions {
                for c in s.categories {
                    totals[c.category, default: 0] += c.totalSeconds
                }
            }
        }
        let grand = totals.values.reduce(0, +)
        guard grand > 0 else { return [] }
        return totals
            .map { (category: $0.key, totalSeconds: $0.value, percent: Int(round(Double($0.value) * 100 / Double(grand)))) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    // MARK: - Helpers

    func categoryColor(for category: String) -> Color {
        CategoryColors.color(for: category)
    }

    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) hr \(mins) min" }
        return "\(mins) min"
    }

    func parseTimeToHour(_ time: String) -> Double? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
            let h = Double(parts[0]),
            let m = Double(parts[1])
        else { return nil }
        return h + m / 60.0
    }
}
#endif
