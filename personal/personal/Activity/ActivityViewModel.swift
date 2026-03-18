#if os(macOS)
import Combine
import Foundation
import SwiftUI

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var sessions: [FocusSessionResponse] = []
    @Published var selectedSession: FocusSessionResponse?
    @Published var showSessionDetail = false
    @Published var dayStats: DailyStatsResponse?
    @Published var categoryBreakdown: [CategoryBreakdownResponse] = []

    private let stats = StatsEngine.shared
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
        Calendar.current.isDateInToday(selectedDate)
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
        if tomorrow <= Date() {
            selectedDate = tomorrow
            selectedSession = nil
            showSessionDetail = false
            navigateToCurrentDate()
        }
    }

    func goToToday() {
        selectedDate = Date()
        selectedSession = nil
        showSessionDetail = false
        navigateToCurrentDate()
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
        showSessionDetail = true
    }

    private func fetchSessions() {
        let date = dateString
        activeFetchDate = date
        if cache[date] == nil { isLoading = true }

        // All queries are fast (local SQLite), run directly
        let result = stats.getFocusSessions(date: date)
        guard activeFetchDate == date else { return }
        self.sessions = result
        self.cache[date] = result
        self.isLoading = false

        self.dayStats = stats.getTimePerApp(date: date)
        self.categoryBreakdown = stats.getCategoryBreakdown(date: date)
    }

    // MARK: - Daily Summary computed data

    var totalFocusSeconds: Int {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }

    var totalFocusDuration: String {
        formatDuration(totalFocusSeconds)
    }

    var sessionCount: Int { sessions.count }

    var percentOfTarget: Double {
        let targetSecs = 8 * 3600
        return targetSecs > 0 ? Double(totalFocusSeconds) / Double(targetSecs) * 100 : 0
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
