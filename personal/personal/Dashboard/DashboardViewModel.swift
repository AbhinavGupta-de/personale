#if os(macOS)
import Combine
import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false

    // Live data (nil = not yet loaded, use mock fallback)
    @Published var dayStats: DailyStatsResponse?
    @Published var timelineEntries: [TimelineEntryResponse]?
    @Published var activityEntries: [ActivityLogEntryResponse]?
    @Published var categoryBreakdown: [CategoryBreakdownResponse]?
    @Published var workblockEntries: [WorkblockEntryResponse]?

    // Break timer — ticks every second, computed client-side from existing data
    @Published var secondsSinceLastBreak: Int = 0

    private let stats = StatsEngine.shared
    private var refreshTimer: Timer?
    private var breakTickTimer: Timer?
    private var lastBreakEnd: Date?
    private var cache: [String: DayCache] = [:]
    private var activeFetchDate: String? // guards against stale responses

    private struct DayCache {
        var dayStats: DailyStatsResponse?
        var timelineEntries: [TimelineEntryResponse]?
        var activityEntries: [ActivityLogEntryResponse]?
        var categoryBreakdown: [CategoryBreakdownResponse]?
        var workblockEntries: [WorkblockEntryResponse]?

        var hasAnyData: Bool {
            dayStats != nil || timelineEntries != nil || activityEntries != nil
                || categoryBreakdown != nil || workblockEntries != nil
        }
    }

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

    // MARK: - Converted data for cards

    var timeline: [MockData.TimelineBlock] {
        guard let entries = timelineEntries, !entries.isEmpty else {
            return []
        }
        return entries.compactMap { entry in
            guard let startHour = parseTimeToHour(entry.startTime),
                let endHour = parseTimeToHour(entry.endTime),
                endHour > startHour
            else { return nil }
            let type = entry.category
            return MockData.TimelineBlock(
                start: startHour, end: endHour, type: type, label: entry.appName)
        }
    }

    var workHours: MockData.WorkHours {
        guard let stats = dayStats else {
            return MockData.WorkHours(
                totalWorked: "0 min", percentOfDay: 0,
                targetHours: "8 hr 0 min", trackingOn: true, trackingHours: "8:00 - 18:00")
        }
        let totalSecs = stats.totalTrackedSeconds
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let totalStr = hours > 0 ? "\(hours) hr \(mins) min" : "\(mins) min"
        let targetSecs = 8 * 3600
        let pct = targetSecs > 0 ? Double(totalSecs) / Double(targetSecs) * 100 : 0
        return MockData.WorkHours(
            totalWorked: totalStr,
            percentOfDay: pct,
            targetHours: "8 hr 0 min",
            trackingOn: true,
            trackingHours: "8:00 - 18:00"
        )
    }

    var activityLog: [MockData.ActivityEntry] {
        guard let entries = activityEntries, !entries.isEmpty else {
            return []
        }
        return entries.reversed().map { entry in
            MockData.ActivityEntry(
                time: entry.time,
                app: entry.appName,
                detail: entry.detail
            )
        }
    }

    var workblocks: [MockData.Workblock] {
        guard let entries = workblockEntries, !entries.isEmpty else {
            return []
        }
        return entries.map { entry in
            MockData.Workblock(
                time: entry.time,
                task: entry.task,
                duration: entry.duration,
                score: nil
            )
        }
    }

    var timeBreakdown: [MockData.TimeBreakdownEntry] {
        guard let categories = categoryBreakdown, !categories.isEmpty else {
            return []
        }
        return categories.map { cat in
            let secs = cat.totalSeconds
            let hours = secs / 3600
            let mins = (secs % 3600) / 60
            let timeStr = hours > 0 ? "\(hours) hr \(mins) min" : "\(mins) min"
            return MockData.TimeBreakdownEntry(
                category: cat.category,
                percent: cat.percent,
                time: timeStr,
                colorHex: CategoryColors.map[cat.category] ?? CategoryColors.fallback
            )
        }
    }

    // MARK: - Break Timer (client-side, no backend calls)

    /// Finds the end time of the last gap (break) in the timeline.
    /// A "break" is any gap >= 5 minutes between consecutive timeline blocks.
    private func computeLastBreakEnd() {
        guard isToday, let entries = timelineEntries, entries.count >= 2 else {
            lastBreakEnd = nil
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let minimumBreakSeconds: TimeInterval = 5 * 60  // 5-minute gap = break

        // Timeline entries are sorted by time; walk backwards to find last gap
        var lastGapEnd: Date?
        for i in stride(from: entries.count - 1, through: 1, by: -1) {
            guard let prevEnd = parseTimeToDate(entries[i - 1].endTime, relativeTo: today),
                  let currStart = parseTimeToDate(entries[i].startTime, relativeTo: today)
            else { continue }
            let gap = currStart.timeIntervalSince(prevEnd)
            if gap >= minimumBreakSeconds {
                lastGapEnd = currStart  // work resumed here → break ended
                break
            }
        }

        // If no gap found, the "last break" is start of first block (no break taken)
        if lastGapEnd == nil {
            lastGapEnd = parseTimeToDate(entries.first!.startTime, relativeTo: today)
        }

        lastBreakEnd = lastGapEnd
        updateSecondsSinceLastBreak()
    }

    private func updateSecondsSinceLastBreak() {
        guard let ref = lastBreakEnd else {
            secondsSinceLastBreak = 0
            return
        }
        secondsSinceLastBreak = max(0, Int(Date().timeIntervalSince(ref)))
    }

    var breakTimerText: String {
        let h = secondsSinceLastBreak / 3600
        let m = (secondsSinceLastBreak % 3600) / 60
        let s = secondsSinceLastBreak % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    var breakToWorkRatio: String {
        guard let stats = dayStats, stats.totalTrackedSeconds > 0 else {
            return "—"
        }
        let totalDaySoFar = Date().timeIntervalSince(
            Calendar.current.startOfDay(for: Date())
        )
        let workedSecs = Double(stats.totalTrackedSeconds)
        let breakSecs = max(0, totalDaySoFar - workedSecs)
        guard breakSecs > 0 else { return "0 / 1" }
        let ratio = workedSecs / breakSecs
        return ratio >= 1
            ? "1 / \(String(format: "%.1f", ratio))"
            : "\(String(format: "%.1f", breakSecs / workedSecs)) / 1"
    }

    private func startBreakTick() {
        breakTickTimer?.invalidate()
        guard isToday else { return }
        breakTickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.updateSecondsSinceLastBreak()
            }
        }
    }

    private func stopBreakTick() {
        breakTickTimer?.invalidate()
        breakTickTimer = nil
    }

    private func parseTimeToDate(_ time: String, relativeTo dayStart: Date) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1])
        else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: dayStart)
    }

    // MARK: - Navigation

    func startRefreshing() {
        fetchAll()
        refreshTimer?.invalidate()
        if isToday {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) {
                [weak self] _ in
                Task { @MainActor in
                    self?.fetchAll()
                }
            }
            startBreakTick()
        }
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        stopBreakTick()
    }

    func goToPreviousDay() {
        selectedDate =
            Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        navigateToCurrentDate()
    }

    func goToNextDay() {
        let tomorrow =
            Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if tomorrow <= Date() {
            selectedDate = tomorrow
            navigateToCurrentDate()
        }
    }

    func goToToday() {
        selectedDate = Date()
        navigateToCurrentDate()
    }

    private func navigateToCurrentDate() {
        let date = dateString

        // Immediately apply cached data (instant navigation)
        if let cached = cache[date] {
            dayStats = cached.dayStats
            timelineEntries = cached.timelineEntries
            activityEntries = cached.activityEntries
            categoryBreakdown = cached.categoryBreakdown
            workblockEntries = cached.workblockEntries
            isLoading = !cached.hasAnyData
        } else {
            dayStats = nil
            timelineEntries = nil
            activityEntries = nil
            categoryBreakdown = nil
            workblockEntries = nil
            isLoading = true
        }

        startRefreshing()
    }

    // MARK: - Data fetching (direct from SQLite)

    private func fetchAll() {
        let date = dateString
        activeFetchDate = date

        if cache[date] == nil {
            isLoading = true
        }

        // All queries are fast (local SQLite), run directly
        let s = stats.getTimePerApp(date: date)
        let t = stats.getTimeline(date: date)
        let a = stats.getActivityLog(date: date)
        let c = stats.getCategoryBreakdown(date: date)
        let w = stats.getWorkblocks(date: date)

        guard activeFetchDate == date else { return }

        self.dayStats = s
        self.timelineEntries = t
        self.activityEntries = a
        self.categoryBreakdown = c
        self.workblockEntries = w

        self.cache[date, default: DayCache()] = DayCache(
            dayStats: s, timelineEntries: t, activityEntries: a,
            categoryBreakdown: c, workblockEntries: w
        )
        self.isLoading = false
        self.computeLastBreakEnd()
    }

    // MARK: - Helpers

    private func parseTimeToHour(_ time: String) -> Double? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
            let h = Double(parts[0]),
            let m = Double(parts[1])
        else { return nil }
        return h + m / 60.0
    }
}
#endif
