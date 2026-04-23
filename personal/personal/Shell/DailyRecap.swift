#if os(macOS)
import Foundation
import UserNotifications

/// Fires a local notification once per day summarizing yesterday's activity.
/// Scheduled for (dayStartHour + 1):00 local time. Repeats daily.
@MainActor
final class DailyRecapService {
    static let shared = DailyRecapService()

    private let api = APIClient.shared
    private var refreshTimer: Timer?

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    func start() {
        reschedule()
        // Re-check hourly in case dayStartHour or the enable flag changed.
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reschedule() }
        }
    }

    func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-recap"])
        guard AppSettings.shared.dailyRecapEnabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        Task { await self.scheduleNext() }
    }

    private func scheduleNext() async {
        let hour = AppSettings.shared.dayStartHour + 1
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        comps.hour = hour
        comps.minute = 0
        var fire = cal.date(from: comps) ?? now
        if fire <= now { fire = cal.date(byAdding: .day, value: 1, to: fire) ?? fire }

        // Build body from yesterday's range summary.
        let yesterday = cal.date(byAdding: .day, value: -1, to: fire)!
        let dayBefore = cal.date(byAdding: .day, value: -2, to: fire)!
        let fromStr = Self.dateFmt.string(from: dayBefore)
        let toStr = Self.dateFmt.string(from: yesterday)

        var body = "Check Personale for yesterday's breakdown."
        if let summary = try? await api.fetchRangeSummary(from: toStr, to: toStr) {
            body = recapBody(summary)
        } else if let summary = try? await api.fetchRangeSummary(from: fromStr, to: toStr) {
            body = recapBody(summary)
        }

        let content = UNMutableNotificationContent()
        content.title = "Yesterday's recap"
        content.body = body
        content.sound = .default

        let interval = fire.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, interval), repeats: false)
        let request = UNNotificationRequest(identifier: "daily-recap", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func recapBody(_ summary: RangeSummaryResponse) -> String {
        let total = summary.totalTrackedSeconds
        let h = total / 3600, m = (total % 3600) / 60
        let totalStr = h > 0 ? "\(h)h \(m)m" : "\(m)m"

        let top = summary.categoryBreakdown.prefix(2)
            .map { "\($0.category) \(formatShort($0.totalSeconds))" }
            .joined(separator: ", ")

        if top.isEmpty { return "Tracked \(totalStr) yesterday." }
        return "Tracked \(totalStr) yesterday — \(top)."
    }

    private func formatShort(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h\(m > 0 ? " \(m)m" : "")" : "\(m)m"
    }
}
#endif
