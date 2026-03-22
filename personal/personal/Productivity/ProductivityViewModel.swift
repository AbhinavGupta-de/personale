#if os(macOS)
import Combine
import Foundation
import SwiftUI

enum PeriodMode: String, CaseIterable {
    case week = "Week"
    case month = "Month"
}

@MainActor
class ProductivityViewModel: ObservableObject {
    @Published var periodMode: PeriodMode = .month
    @Published var isLoading = false
    @Published var rangeData: RangeResponse?
    @Published var summaryData: RangeSummaryResponse?

    // The anchor date for the current period (any day within the period)
    @Published var anchorDate: Date = Date()

    private let api = APIClient.shared
    private var cache: [String: (RangeResponse, RangeSummaryResponse)] = [:]
    private var activeFetchKey: String?

    private static let dateFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    // MARK: - Period bounds

    var periodFrom: Date {
        let cal = Calendar.current
        switch periodMode {
        case .month:
            return cal.date(from: cal.dateComponents([.year, .month], from: anchorDate))!
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDate)
            return cal.date(from: comps)!
        }
    }

    var periodTo: Date {
        let cal = Calendar.current
        switch periodMode {
        case .month:
            return cal.date(byAdding: DateComponents(month: 1, day: -1), to: periodFrom)!
        case .week:
            return cal.date(byAdding: .day, value: 6, to: periodFrom)!
        }
    }

    var fromString: String { Self.dateFmt.string(from: periodFrom) }
    var toString: String { Self.dateFmt.string(from: min(periodTo, Date())) }

    var displayPeriod: String {
        let fmt = DateFormatter()
        switch periodMode {
        case .month:
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: periodFrom)
        case .week:
            fmt.dateFormat = "MMM d"
            let start = fmt.string(from: periodFrom)
            let end = fmt.string(from: periodTo)
            return "\(start) – \(end)"
        }
    }

    var isCurrentPeriod: Bool {
        let cal = Calendar.current
        switch periodMode {
        case .month:
            return cal.isDate(anchorDate, equalTo: Date(), toGranularity: .month)
        case .week:
            return cal.isDate(anchorDate, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    private var cacheKey: String { "\(periodMode.rawValue)-\(fromString)" }

    // MARK: - Navigation

    func load() { fetchData() }

    func goToPreviousPeriod() {
        let cal = Calendar.current
        switch periodMode {
        case .month:
            anchorDate = cal.date(byAdding: .month, value: -1, to: anchorDate)!
        case .week:
            anchorDate = cal.date(byAdding: .weekOfYear, value: -1, to: anchorDate)!
        }
        fetchData()
    }

    func goToNextPeriod() {
        let cal = Calendar.current
        let next: Date
        switch periodMode {
        case .month:
            next = cal.date(byAdding: .month, value: 1, to: anchorDate)!
        case .week:
            next = cal.date(byAdding: .weekOfYear, value: 1, to: anchorDate)!
        }
        guard next <= Date() else { return }
        anchorDate = next
        fetchData()
    }

    func goToCurrentPeriod() {
        anchorDate = Date()
        fetchData()
    }

    func switchPeriodMode(_ mode: PeriodMode) {
        periodMode = mode
        fetchData()
    }

    // MARK: - Data fetching

    private func fetchData() {
        let key = cacheKey
        activeFetchKey = key

        if let cached = cache[key] {
            rangeData = cached.0
            summaryData = cached.1
            isLoading = false
            return
        }

        isLoading = true
        let from = fromString
        let to = toString

        Task {
            guard let range = try? await api.fetchRange(from: from, to: to),
                  activeFetchKey == key
            else { return }
            self.rangeData = range

            guard let summary = try? await api.fetchRangeSummary(from: from, to: to),
                  activeFetchKey == key
            else { return }
            self.summaryData = summary
            self.cache[key] = (range, summary)
            self.isLoading = false
        }
    }

    // MARK: - Computed display data

    /// Per-day chart data grouped into display buckets
    var chartDays: [(date: String, productive: Double, communication: Double, other: Double)] {
        guard let range = rangeData else { return [] }
        return range.days.map { day in
            var productive: Double = 0
            var communication: Double = 0
            var other: Double = 0

            for cat in day.categories {
                let hours = Double(cat.seconds) / 3600.0
                switch cat.category {
                case "Code", "Design", "Writing", "Reading":
                    productive += hours
                case "Communication":
                    communication += hours
                default:
                    other += hours
                }
            }
            // Shorten date for x-axis label
            let label = String(day.date.suffix(5)) // "MM-DD"
            return (label, productive, communication, other)
        }
    }

    var totalTrackedFormatted: String {
        guard let s = summaryData else { return "—" }
        return formatDuration(s.totalTrackedSeconds)
    }

    var avgPerDayFormatted: String {
        guard let s = summaryData else { return "—" }
        return formatDuration(s.avgSecondsPerDay)
    }

    var avgPerWeekFormatted: String {
        guard let s = summaryData else { return "—" }
        return formatDuration(s.avgSecondsPerWeek)
    }

    /// Breakdown donuts: productive, communication, other
    var donutData: [(label: String, percent: Int, seconds: Int, color: String)] {
        guard let s = summaryData, s.totalTrackedSeconds > 0 else { return [] }
        var productive = 0, communication = 0, other = 0
        for cat in s.categoryBreakdown {
            switch cat.category {
            case "Code", "Design", "Writing", "Reading":
                productive += cat.totalSeconds
            case "Communication":
                communication += cat.totalSeconds
            default:
                other += cat.totalSeconds
            }
        }
        let total = s.totalTrackedSeconds
        return [
            ("Productive", pct(productive, total), productive, "purple"),
            ("Communication", pct(communication, total), communication, "cyan"),
            ("Other", pct(other, total), other, "gray"),
        ]
    }

    // MARK: - Helpers

    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h) hr \(m) min" }
        return "\(m) min"
    }

    private func pct(_ value: Int, _ total: Int) -> Int {
        total > 0 ? Int(round(Double(value) * 100.0 / Double(total))) : 0
    }
}
#endif
