#if os(macOS)
import Combine
import Foundation
import SwiftUI

enum InsightsRange: String, CaseIterable, Identifiable {
    case last7 = "7 days"
    case last30 = "30 days"
    case last90 = "90 days"
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .last7: return 7
        case .last30: return 30
        case .last90: return 90
        }
    }
}

@MainActor
final class InsightsViewModel: ObservableObject {

    @Published var range: InsightsRange = .last30
    @Published var overview: InsightsOverviewResponse?
    @Published var narrative: InsightsNarrativeResponse?
    @Published var isLoading = false
    @Published var isGeneratingNarrative = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func selectRange(_ r: InsightsRange) {
        guard r != range else { return }
        range = r
        narrative = nil
        Task { await load() }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let cal = Calendar(identifier: .gregorian)
        let today = Date()
        guard let start = cal.date(byAdding: .day, value: -(range.days - 1), to: today) else { return }
        let from = Self.isoDate.string(from: start)
        let to = Self.isoDate.string(from: today)
        do {
            overview = try await api.fetchInsightsOverview(from: from, to: to)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load insights: \(error.localizedDescription)"
        }
    }

    func generateNarrative() async {
        guard let o = overview else { return }
        isGeneratingNarrative = true
        defer { isGeneratingNarrative = false }
        do {
            narrative = try await api.generateInsightsNarrative(from: o.from, to: o.to)
            errorMessage = nil
        } catch {
            errorMessage = "Narrative failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Derived

    var displayRangeLabel: String {
        guard let o = overview else { return range.rawValue }
        return "\(o.from) → \(o.to)"
    }

    var totalProductiveLabel: String { formatHours(overview?.totalProductiveSeconds ?? 0) }
    var totalTrackedLabel: String { formatHours(overview?.totalTrackedSeconds ?? 0) }
    var avgProductivePerDay: String {
        guard let o = overview, o.daysWithData > 0 else { return "—" }
        return formatHours(o.totalProductiveSeconds / o.daysWithData)
    }
    var avgSwitchesPerDay: String {
        guard let o = overview, o.daysWithData > 0 else { return "—" }
        return String(o.totalContextSwitches / o.daysWithData)
    }

    /// Best weekday by avg productive seconds.
    var bestWeekday: (label: String, hours: String)? {
        guard let dows = overview?.dayOfWeek.filter({ $0.days > 0 }),
              let best = dows.max(by: { $0.avgProductiveSeconds < $1.avgProductiveSeconds }),
              best.avgProductiveSeconds > 0 else { return nil }
        return (Self.weekdayLabel(best.weekday), formatHours(best.avgProductiveSeconds))
    }

    /// Heatmap peak cell (highest productive seconds across week).
    var peakHourCell: (label: String, hours: String)? {
        guard let cells = overview?.heatmap,
              let peak = cells.max(by: { $0.productiveSeconds < $1.productiveSeconds }),
              peak.productiveSeconds > 0 else { return nil }
        return ("\(Self.weekdayLabel(peak.weekday)) \(String(format: "%02d", peak.hour)):00",
                formatHours(peak.productiveSeconds))
    }

    var trendDelta: (label: String, positive: Bool)? {
        guard let o = overview else { return nil }
        let cur = o.categoryBreakdown.first { $0.percent > 0 }?.percent ?? 0
        let prior = o.categoryBreakdownPriorPeriod.first { $0.percent > 0 }?.percent ?? 0
        let d = cur - prior
        if d == 0 { return nil }
        return ("\(d > 0 ? "+" : "")\(d)% top category vs prior", d > 0)
    }

    static func weekdayLabel(_ weekday: Int) -> String {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        guard weekday >= 1 && weekday <= 7 else { return "?" }
        return names[weekday - 1]
    }

    func formatHours(_ secs: Int) -> String {
        if secs <= 0 { return "0" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}
#endif
