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

    private let api = APIClient.shared
    private var refreshTimer: Timer?
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
            let type = entry.category.lowercased()
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

    // MARK: - Navigation

    func startRefreshing() {
        fetchAllIncremental()
        refreshTimer?.invalidate()
        if isToday {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) {
                [weak self] _ in
                Task { @MainActor in
                    self?.fetchAllIncremental()
                }
            }
        }
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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

    // MARK: - Incremental fetching

    private func fetchAllIncremental() {
        let date = dateString
        activeFetchDate = date

        if cache[date] == nil {
            isLoading = true
        }

        // Fire each endpoint independently — UI updates as each arrives
        Task {
            guard let s = try? await api.fetchDayStats(date: date),
                activeFetchDate == date
            else { return }
            self.dayStats = s
            self.cache[date, default: DayCache()].dayStats = s
            self.isLoading = false
        }
        Task {
            guard let t = try? await api.fetchTimeline(date: date),
                activeFetchDate == date
            else { return }
            self.timelineEntries = t
            self.cache[date, default: DayCache()].timelineEntries = t
            self.isLoading = false
        }
        Task {
            guard let a = try? await api.fetchActivity(date: date),
                activeFetchDate == date
            else { return }
            self.activityEntries = a
            self.cache[date, default: DayCache()].activityEntries = a
            self.isLoading = false
        }
        Task {
            guard let c = try? await api.fetchCategories(date: date),
                activeFetchDate == date
            else { return }
            self.categoryBreakdown = c
            self.cache[date, default: DayCache()].categoryBreakdown = c
            self.isLoading = false
        }
        Task {
            guard let w = try? await api.fetchWorkblocks(date: date),
                activeFetchDate == date
            else { return }
            self.workblockEntries = w
            self.cache[date, default: DayCache()].workblockEntries = w
            self.isLoading = false
        }

        // Prefetch adjacent days in background
        prefetchAdjacent()
    }

    private func prefetchAdjacent() {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!

        for date in [prev, next] {
            guard date <= Date() else { continue }
            let dateStr = Self.dateFmt.string(from: date)
            guard cache[dateStr] == nil else { continue }

            // Prefetch all endpoints for adjacent days
            Task {
                if let s = try? await api.fetchDayStats(date: dateStr) {
                    self.cache[dateStr, default: DayCache()].dayStats = s
                }
            }
            Task {
                if let t = try? await api.fetchTimeline(date: dateStr) {
                    self.cache[dateStr, default: DayCache()].timelineEntries = t
                }
            }
            Task {
                if let c = try? await api.fetchCategories(date: dateStr) {
                    self.cache[dateStr, default: DayCache()].categoryBreakdown = c
                }
            }
            Task {
                if let w = try? await api.fetchWorkblocks(date: dateStr) {
                    self.cache[dateStr, default: DayCache()].workblockEntries = w
                }
            }
            Task {
                if let a = try? await api.fetchActivity(date: dateStr) {
                    self.cache[dateStr, default: DayCache()].activityEntries = a
                }
            }
        }
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
