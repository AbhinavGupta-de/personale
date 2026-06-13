#if os(macOS)
import AppKit
import Combine
import SwiftUI
import UserNotifications

// MARK: - Model

struct BreakRecord: Identifiable {
    let id = UUID()
    let startedAt: Date
    let endedAt: Date
    let classification: Classification

    enum Classification: String { case breakSession = "Break", away = "Away" }

    var durationSeconds: Int { max(0, Int(endedAt.timeIntervalSince(startedAt))) }
}

// MARK: - Service

@MainActor
final class BreakDetectionService: ObservableObject {
    static let shared = BreakDetectionService()

    @Published private(set) var breaks: [BreakRecord] = []
    @Published private(set) var overlayShowing = false
    @Published private(set) var lastWorkResumedAt: Date = Date()

    private var tickCancellable: AnyCancellable?
    private var idleCancellable: AnyCancellable?
    private var idleStart: Date?
    private var overlayWindow: NSWindow?
    private var lastSmartNudgeAt: Date?

    private weak var appTracker: AppTracker?
    private var hasRequestedNotificationAuth = false

    func wire(appTracker: AppTracker) {
        self.appTracker = appTracker
        idleCancellable = appTracker.$isIdle
            .removeDuplicates()
            .sink { [weak self] idle in self?.onIdleChange(idle) }
        tickCancellable = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkSmartNudge() }
    }

    private func onIdleChange(_ idle: Bool) {
        let settings = AppSettings.shared
        guard settings.autoDetectBreaks else { return }

        if idle {
            idleStart = Date()
            if settings.fullScreenBreakMode {
                showOverlay()
            }
        } else if let start = idleStart {
            let now = Date()
            let seconds = now.timeIntervalSince(start)
            let maxSeconds = TimeInterval(settings.maxBreakMinutes * 60)
            let defaultSeconds = TimeInterval(settings.defaultBreakMinutes * 60)
            // Anything shorter than default break is noise — ignore.
            if seconds >= defaultSeconds {
                let classification: BreakRecord.Classification = seconds >= maxSeconds ? .away : .breakSession
                breaks.insert(BreakRecord(startedAt: start, endedAt: now, classification: classification), at: 0)
            }
            idleStart = nil
            lastWorkResumedAt = now
            lastSmartNudgeAt = nil
            dismissOverlay()
        }
    }

    // MARK: Smart nudge

    private func checkSmartNudge() {
        let settings = AppSettings.shared
        guard settings.smartBreakNotifications, appTracker?.isIdle == false else { return }
        let intervalSec = TimeInterval(settings.smartBreakIntervalMinutes * 60)
        let elapsed = Date().timeIntervalSince(lastWorkResumedAt)
        guard elapsed >= intervalSec else { return }
        // Debounce: only nudge once per interval window
        if let last = lastSmartNudgeAt, Date().timeIntervalSince(last) < intervalSec { return }
        sendNudge(elapsed: Int(elapsed))
        lastSmartNudgeAt = Date()
    }

    private func sendNudge(elapsed: Int) {
        let center = UNUserNotificationCenter.current()
        if !hasRequestedNotificationAuth {
            hasRequestedNotificationAuth = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        let content = UNMutableNotificationContent()
        content.title = "Time for a break"
        let m = elapsed / 60
        content.body = "You've been working \(m) min straight. Stand up, stretch, drink water."
        content.sound = .default
        center.add(UNNotificationRequest(
            identifier: "break-nudge-\(UUID().uuidString)",
            content: content, trigger: nil), withCompletionHandler: nil)
    }

    // MARK: Full-screen overlay

    private func showOverlay() {
        guard !overlayShowing else { return }
        overlayShowing = true

        let content = BreakOverlayView(
            defaultMinutes: AppSettings.shared.defaultBreakMinutes,
            onEnd: { [weak self] in self?.dismissOverlay() }
        )
        let host = NSHostingController(rootView: content)
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let window = NSWindow(
            contentRect: screen,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = host
        window.isMovable = false
        window.level = .mainMenu + 1
        window.backgroundColor = NSColor(white: 0.02, alpha: 0.96)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setFrame(screen, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow = window
    }

    func dismissOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        overlayShowing = false
    }
}

// MARK: - Overlay view

private struct BreakOverlayView: View {
    let defaultMinutes: Int
    let onEnd: () -> Void

    @State private var elapsedSeconds = 0
    @State private var ticker: AnyCancellable?

    private var targetSeconds: Int { defaultMinutes * 60 }
    private var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / Double(targetSeconds))
    }
    private var remainingText: String {
        let rem = max(0, targetSeconds - elapsedSeconds)
        let m = rem / 60, s = rem % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(spacing: Spacing.space9) {
                Text("Break Time")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.white)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(remainingText)
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 320, height: 320)

                Text("Step away. Rest your eyes. Drink water.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.7))

                Button("End Break") { onEnd() }
                    .font(AppFont.text(FontSize.md, .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22).padding(.vertical, Spacing.space4)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape)
            }
        }
        .onAppear {
            ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                .sink { _ in elapsedSeconds += 1 }
        }
        .onDisappear { ticker?.cancel() }
    }
}
#endif
