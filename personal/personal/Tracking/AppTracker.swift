#if os(macOS)
import AppKit
import ApplicationServices
import Combine
import CoreGraphics

class AppTracker: ObservableObject {
    @Published var currentAppName: String = ""
    @Published var currentBundleID: String = ""
    @Published var currentCategory: String = "Other"
    @Published var lastSwitchTime: Date = Date()
    @Published var isIdle: Bool = false

    private var cancellables = Set<AnyCancellable>()
    let eventClient: EventClient
    private var idleTimer: Timer?

    // Bundle→category map fetched from backend
    private var categoryMap: [String: String] = [:]
    private var lastCategoryFetch: Date?
    private static let categoryRefreshInterval: TimeInterval = 30 * 60 // 30 minutes

    private static let defaultIdleThreshold: TimeInterval = 120
    private static let pollInterval: TimeInterval = 5

    // Debounce: prevent rapid duplicate events
    private var lastSentBundleID: String?
    private var lastSentTime: Date?
    private static let debounceInterval: TimeInterval = 1

    // System apps that indicate the user is away — close session, don't track
    private static let blockedBundleIDs: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.apple.ScreenSaver",
        "com.apple.SecurityAgent",
        "com.apple.UserNotificationCenter",
    ]

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var currentIdleThreshold: TimeInterval {
        AppSettings.shared.idleThresholds[currentCategory] ?? Self.defaultIdleThreshold
    }

    init(eventClient: EventClient = EventClient()) {
        self.eventClient = eventClient

        let nc = NSWorkspace.shared.notificationCenter

        nc.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.handleAppSwitch(app)
            }
            .store(in: &cancellables)

        nc.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSleep()
            }
            .store(in: &cancellables)

        nc.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWake()
            }
            .store(in: &cancellables)

        // Load category map from backend, then capture initial state
        fetchCategoryMap {
            if let app = NSWorkspace.shared.frontmostApplication {
                self.handleAppSwitch(app)
            }
        }

        startIdlePolling()
        startCategoryRefreshTimer()
    }

    // MARK: - Category Map

    private struct CategorySettingsResponse: Decodable {
        let mappings: [String: String]
    }

    private func fetchCategoryMap(completion: (() -> Void)? = nil) {
        let url = eventClient.baseURL.appendingPathComponent("/api/settings/categories")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let decoded = try? JSONDecoder().decode(CategorySettingsResponse.self, from: data)
            else {
                DispatchQueue.main.async { completion?() }
                return
            }
            DispatchQueue.main.async {
                self?.categoryMap = decoded.mappings
                self?.lastCategoryFetch = Date()
                completion?()
            }
        }.resume()
    }

    private var categoryRefreshTimer: Timer?

    private func startCategoryRefreshTimer() {
        categoryRefreshTimer = Timer.scheduledTimer(withTimeInterval: Self.categoryRefreshInterval, repeats: true) { [weak self] _ in
            self?.fetchCategoryMap()
        }
    }

    private func resolveCategory(for bundleId: String?) -> String {
        guard let bid = bundleId else { return "Other" }
        return categoryMap[bid] ?? "Other"
    }

    // MARK: - Idle Detection

    private func startIdlePolling() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    private func checkIdleState() {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let idleKeyboard = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let idle = min(idleSeconds, idleKeyboard)

        if idle >= currentIdleThreshold && !isIdle {
            isIdle = true
            let lastInputTime = Date().addingTimeInterval(-idle)
            let timestamp = dateFormatter.string(from: lastInputTime)
            print("[\(dateFormatter.string(from: Date()))] User idle for \(Int(idle))s (threshold: \(Int(currentIdleThreshold))s/\(currentCategory)) — closing session")
            eventClient.sendSessionClose(
                timestamp: timestamp,
                bundleId: currentBundleID.isEmpty ? nil : currentBundleID,
                sessionStartedAt: dateFormatter.string(from: lastSwitchTime)
            )
        } else if idle < currentIdleThreshold && isIdle {
            isIdle = false
            let timestamp = dateFormatter.string(from: Date())
            print("[\(timestamp)] User returned from idle — re-registering frontmost app")
            if let app = NSWorkspace.shared.frontmostApplication {
                handleAppSwitch(app)
            }
        }
    }

    // MARK: - Window Title Capture

    private func captureWindowTitle(for app: NSRunningApplication) -> String? {
        guard AXIsProcessTrusted() else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success else { return nil }

        var titleValue: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &titleValue)
        guard titleResult == .success, let title = titleValue as? String, !title.isEmpty else { return nil }

        return title
    }

    // MARK: - App Switch

    private func handleAppSwitch(_ app: NSRunningApplication) {
        isIdle = false
        let name = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier
        let now = Date()
        let timestamp = dateFormatter.string(from: now)

        // Skip nil bundleId — suspicious/unknown process
        guard let bid = bundleID else {
            print("[\(timestamp)] Ignoring app with nil bundleId: \(name)")
            return
        }

        // Blocked apps — close session, mark idle
        if Self.blockedBundleIDs.contains(bid) {
            print("[\(timestamp)] \(name) activated — closing active session (blocked app)")
            eventClient.sendSessionClose(
                timestamp: timestamp,
                bundleId: currentBundleID.isEmpty ? nil : currentBundleID,
                sessionStartedAt: dateFormatter.string(from: lastSwitchTime)
            )
            isIdle = true
            return
        }

        // Debounce: skip if same bundle within 1 second
        if bid == lastSentBundleID,
           let lastTime = lastSentTime,
           now.timeIntervalSince(lastTime) < Self.debounceInterval {
            return
        }

        // Resolve category for idle threshold
        currentCategory = resolveCategory(for: bid)

        // Capture window title if Accessibility is granted
        let windowTitle = captureWindowTitle(for: app)

        print("[\(timestamp)] Switched to: \(name) (\(bid)) [\(currentCategory)]\(windowTitle.map { " — \($0)" } ?? "")")

        eventClient.sendAppSwitch(
            appName: name,
            bundleId: bid,
            windowTitle: windowTitle,
            timestamp: timestamp
        )

        // Update state
        currentAppName = name
        currentBundleID = bid
        lastSwitchTime = now
        lastSentBundleID = bid
        lastSentTime = now
    }

    // MARK: - Sleep / Wake

    private func handleSleep() {
        isIdle = true
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] Mac going to sleep — closing active session")
        eventClient.sendSessionClose(
            timestamp: timestamp,
            bundleId: currentBundleID.isEmpty ? nil : currentBundleID,
            sessionStartedAt: dateFormatter.string(from: lastSwitchTime)
        )
    }

    private func handleWake() {
        isIdle = false
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] Mac woke up — re-registering frontmost app")
        eventClient.triggerFlush()
        fetchCategoryMap()
        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppSwitch(app)
        }
    }

    deinit {
        idleTimer?.invalidate()
        categoryRefreshTimer?.invalidate()
    }
}
#endif
