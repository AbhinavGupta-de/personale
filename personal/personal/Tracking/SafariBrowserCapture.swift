#if os(macOS)
import AppKit
import Foundation

/// Closes the browser-tracking gap for Safari (we don't ship a Safari extension).
/// Polls Safari's frontmost tab via AppleScript while Safari is the frontmost
/// macOS app, debouncing repeats and posting `/api/events/browser` events that
/// match the Chromium extension's payload shape — server treats them
/// indistinguishably.
///
/// First-time AppleScript run triggers the macOS "allow Personale to control
/// Safari?" prompt. Subsequent runs are silent. App Sandbox requires the
/// `com.apple.security.temporary-exception.apple-events` entitlement targeting
/// `com.apple.Safari`.
@MainActor
final class SafariBrowserCapture {
    static let shared = SafariBrowserCapture()

    private static let SAFARI_BUNDLE = "com.apple.Safari"
    private static let POLL_INTERVAL: TimeInterval = 5
    private static let DEBOUNCE_INTERVAL: TimeInterval = 1

    private var timer: Timer?
    private var lastDomain: String?
    private var lastEventAt: Date?
    private weak var appTracker: AppTracker?

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 5
        return URLSession(configuration: cfg)
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func wire(appTracker: AppTracker) {
        self.appTracker = appTracker
        // React to focus changes the same way DistractionBlocker / BreakDetection
        // do — observe AppTracker's published bundle id.
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
            Task { @MainActor in self?.frontmostChanged(to: app) }
        }
        // Seed from current frontmost on launch.
        if let cur = NSWorkspace.shared.frontmostApplication {
            frontmostChanged(to: cur)
        }
    }

    private func frontmostChanged(to app: NSRunningApplication) {
        if app.bundleIdentifier == Self.SAFARI_BUNDLE {
            startPolling()
            // Capture immediately on switch-in to avoid up-to-5s blind window.
            tick()
        } else {
            stopPolling()
        }
    }

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.POLL_INTERVAL, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        lastDomain = nil
    }

    private func tick() {
        // Don't capture while the user is idle — AppTracker already closes the
        // session in that case, so a captured URL would attribute to nothing.
        if appTracker?.isIdle == true { return }

        guard let (urlStr, title) = currentSafariTab() else { return }
        guard let url = URL(string: urlStr),
              let host = url.host,
              url.scheme == "http" || url.scheme == "https"
        else { return }

        // Debounce same-domain bursts (page-refresh, hash navigations).
        let now = Date()
        if let last = lastEventAt, host == lastDomain,
           now.timeIntervalSince(last) < Self.DEBOUNCE_INTERVAL {
            return
        }
        lastDomain = host
        lastEventAt = now

        post(domain: host, title: title, url: truncateURL(url), at: now)
    }

    /// Run the AppleScript and return (url, title). Returns nil on any failure.
    private func currentSafariTab() -> (String, String)? {
        let script = """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                set theURL to URL of current tab of window 1
                set theName to name of current tab of window 1
                return (theURL & "\u{2028}" & theName)
            end tell
            """
        var errInfo: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&errInfo)
        if let _ = errInfo {
            return nil
        }
        let value = result.stringValue ?? ""
        let parts = value.components(separatedBy: "\u{2028}")
        guard parts.count == 2, !parts[0].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    private func truncateURL(_ url: URL) -> String {
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        c?.query = nil
        c?.fragment = nil
        return c?.string ?? url.absoluteString
    }

    private func post(domain: String, title: String, url: String, at: Date) {
        guard let server = URL(string: "/api/events/browser",
                                relativeTo: AppSettings.shared.serverBaseURL)
        else { return }
        struct Payload: Encodable {
            let domain: String; let title: String; let url: String
            let browser: String; let timestamp: String
        }
        let body = Payload(
            domain: domain, title: title, url: url,
            browser: "safari",
            timestamp: Self.isoFormatter.string(from: at))
        var req = URLRequest(url: server)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)
        session.dataTask(with: req).resume()
    }
}
#endif
