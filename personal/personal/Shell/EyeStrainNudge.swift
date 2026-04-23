#if os(macOS)
import Combine
import Foundation
import UserNotifications

/// 20-20-20 eye-strain rule: every N minutes of continuous screen activity,
/// nudge the user to look 20 ft away for 20 sec. Suppressed during active
/// pomodoros — Mark et al. 2008 showed interruptions cost ~23 min of flow
/// recovery, so we protect the focus block.
@MainActor
final class EyeStrainNudgeService {
    static let shared = EyeStrainNudgeService()

    private var timer: Timer?
    private var lastNudgeAt: Date = Date()
    private weak var appTracker: AppTracker?
    private weak var pomodoro: PomodoroViewModel?

    private var hasRequestedAuth = false

    func wire(appTracker: AppTracker, pomodoro: PomodoroViewModel) {
        self.appTracker = appTracker
        self.pomodoro = pomodoro
        reschedule()
    }

    func reschedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        lastNudgeAt = Date()
    }

    private func tick() {
        let settings = AppSettings.shared
        guard settings.eyeStrainNudgesEnabled else { return }
        guard let tracker = appTracker, !tracker.isIdle else { return }
        // Don't interrupt flow — pomodoros get immunity.
        if pomodoro?.isRunning == true { return }

        let intervalSec = TimeInterval(settings.eyeStrainIntervalMinutes * 60)
        guard Date().timeIntervalSince(lastNudgeAt) >= intervalSec else { return }

        let center = UNUserNotificationCenter.current()
        if !hasRequestedAuth {
            hasRequestedAuth = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        let content = UNMutableNotificationContent()
        content.title = "20-20-20"
        content.body = "Look 20 feet away for 20 seconds to rest your eyes."
        content.sound = nil
        center.add(UNNotificationRequest(
            identifier: "eyestrain-\(UUID().uuidString)",
            content: content, trigger: nil), withCompletionHandler: nil)
        lastNudgeAt = Date()
    }
}
#endif
