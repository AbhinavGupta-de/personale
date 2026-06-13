#if os(macOS)
import AppKit
import Combine
import SwiftUI
import UserNotifications

// MARK: - Service

@MainActor
final class DistractionBlockerService: ObservableObject {
    static let shared = DistractionBlockerService()

    /// Seconds accumulated in distraction categories within the current
    /// pomodoro session. Resets to 0 when a pomodoro ends or the user leaves
    /// all distraction categories.
    @Published private(set) var accumulatedDistractionSeconds: Int = 0
    @Published private(set) var isBlockerShowing = false

    private var tickCancellable: AnyCancellable?
    private var overlayWindow: NSWindow?
    private weak var appTracker: AppTracker?
    private weak var pomodoro: PomodoroViewModel?

    private var hasRequestedNotificationAuth = false

    func wire(appTracker: AppTracker, pomodoro: PomodoroViewModel) {
        self.appTracker = appTracker
        self.pomodoro = pomodoro
        startTicking()
    }

    private func startTicking() {
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let tracker = appTracker, let pomo = pomodoro else { return }

        // Blocker only operates during a focus session.
        guard pomo.isRunning, !tracker.isIdle else {
            if accumulatedDistractionSeconds != 0 { accumulatedDistractionSeconds = 0 }
            return
        }

        let settings = AppSettings.shared
        let inDistraction = settings.distractionCategories.contains(tracker.currentCategory)
        if inDistraction {
            accumulatedDistractionSeconds += 1
            if accumulatedDistractionSeconds == settings.blockerThresholdSeconds {
                trigger(category: tracker.currentCategory, appName: tracker.currentAppName)
            }
        } else if accumulatedDistractionSeconds > 0 {
            // User moved away from distractions — decay quickly.
            accumulatedDistractionSeconds = max(0, accumulatedDistractionSeconds - 3)
        }
    }

    private func trigger(category: String, appName: String) {
        let settings = AppSettings.shared
        switch settings.blockerType {
        case .notification:
            sendNotification(category: category, appName: appName)
        case .popup:
            showOverlay(category: category, appName: appName)
        }
    }

    // MARK: Popup

    private func showOverlay(category: String, appName: String) {
        guard !isBlockerShowing else { return }
        isBlockerShowing = true

        let content = BlockerOverlayView(
            category: category,
            appName: appName,
            urgeSurfing: AppSettings.shared.urgeSurfing,
            onDismiss: { [weak self] in self?.dismissOverlay() }
        )

        let host = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovable = false
        window.level = .floating
        window.setContentSize(NSSize(width: 520, height: 340))
        window.center()
        window.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow = window
    }

    func dismissOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        isBlockerShowing = false
        // Grace period so we don't re-fire immediately on the next tick.
        accumulatedDistractionSeconds = 0
    }

    // MARK: Notification

    private func sendNotification(category: String, appName: String) {
        let center = UNUserNotificationCenter.current()
        if !hasRequestedNotificationAuth {
            hasRequestedNotificationAuth = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        let content = UNMutableNotificationContent()
        content.title = "Back to focus"
        content.body = "\(appName) (\(category)) — you're drifting during a focus session."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "blocker-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
        // Reset so notifications don't fire every second.
        accumulatedDistractionSeconds = 0
    }
}

// MARK: - Overlay view

private struct BlockerOverlayView: View {
    let category: String
    let appName: String
    let urgeSurfing: Bool
    let onDismiss: () -> Void

    @State private var remainingLock: Int
    @State private var lockTimer: AnyCancellable?

    init(category: String, appName: String, urgeSurfing: Bool, onDismiss: @escaping () -> Void) {
        self.category = category
        self.appName = appName
        self.urgeSurfing = urgeSurfing
        self.onDismiss = onDismiss
        _remainingLock = State(initialValue: urgeSurfing ? 10 : 0)
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "eye.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.white.opacity(0.85))

            Text("Back to focus")
                .font(AppFont.text(FontSize.xl2, .semibold))
                .foregroundStyle(Color.white)

            VStack(spacing: Spacing.space1) {
                Text("\(appName) • \(category)")
                    .font(AppFont.mono(FontSize.md))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text("You've crossed your distraction threshold in this focus session.")
                    .font(AppFont.text(FontSize.base))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.space8)
            }

            Button {
                if remainingLock == 0 { onDismiss() }
            } label: {
                Text(remainingLock > 0 ? "Dismiss in \(remainingLock)s" : "Dismiss")
                    .font(AppFont.text(FontSize.md, .medium))
                    .foregroundStyle(remainingLock > 0 ? Color.white.opacity(0.4) : Color.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, Spacing.space3)
                    .background(remainingLock > 0 ? Color.white.opacity(0.2) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(remainingLock > 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.space9)
        .background(Color.black.opacity(0.9))
        .onAppear { startLockTimer() }
    }

    private func startLockTimer() {
        guard remainingLock > 0 else { return }
        lockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { _ in
                if remainingLock > 0 { remainingLock -= 1 }
                if remainingLock == 0 { lockTimer?.cancel() }
            }
    }
}
#endif
