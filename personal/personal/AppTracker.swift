#if os(macOS)
import AppKit
import Combine
import CoreGraphics

class AppTracker: ObservableObject {
    @Published var currentAppName: String = ""
    @Published var currentBundleID: String = ""
    @Published var lastSwitchTime: Date = Date()
    @Published var isIdle: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let eventClient: EventClient
    private var idleTimer: Timer?

    private static let idleThreshold: TimeInterval = 30
    private static let pollInterval: TimeInterval = 5

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(eventClient: EventClient = EventClient()) {
        self.eventClient = eventClient

        let nc = NSWorkspace.shared.notificationCenter

        // Subscribe to app activation events
        nc.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.handleAppSwitch(app)
            }
            .store(in: &cancellables)

        // Close active session when Mac goes to sleep
        nc.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSleep()
            }
            .store(in: &cancellables)

        // Re-register frontmost app when Mac wakes
        nc.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWake()
            }
            .store(in: &cancellables)

        // Capture initial state and send to backend
        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppSwitch(app)
        }

        startIdlePolling()
    }

    // MARK: - Idle Detection

    private func startIdlePolling() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    private func checkIdleState() {
        let idleSeconds = CGEventSource.secondsSinceLastCombinedInput(.combinedSessionState)

        if idleSeconds >= Self.idleThreshold && !isIdle {
            // User just went idle — close session at the time they stopped interacting
            isIdle = true
            let lastInputTime = Date().addingTimeInterval(-idleSeconds)
            let timestamp = dateFormatter.string(from: lastInputTime)
            print("[\(dateFormatter.string(from: Date()))] User idle for \(Int(idleSeconds))s — closing session (last input at \(timestamp))")
            eventClient.sendSessionClose(timestamp: timestamp)
        } else if idleSeconds < Self.idleThreshold && isIdle {
            // User returned from idle — re-register frontmost app
            isIdle = false
            let timestamp = dateFormatter.string(from: Date())
            print("[\(timestamp)] User returned from idle — re-registering frontmost app")
            if let app = NSWorkspace.shared.frontmostApplication {
                handleAppSwitch(app)
            }
        }
    }

    // MARK: - App Switch

    private func handleAppSwitch(_ app: NSRunningApplication) {
        let name = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier
        let now = Date()
        let timestamp = dateFormatter.string(from: now)

        print("[\(timestamp)] Switched to: \(name) (\(bundleID ?? "nil"))")

        // POST to backend
        eventClient.sendAppSwitch(
            appName: name,
            bundleId: bundleID,
            windowTitle: nil,
            timestamp: timestamp
        )

        // Update published state for UI
        currentAppName = name
        currentBundleID = bundleID ?? ""
        lastSwitchTime = now
    }

    // MARK: - Sleep / Wake

    private func handleSleep() {
        isIdle = true  // prevent idle poll from sending a duplicate close
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] Mac going to sleep — closing active session")
        eventClient.sendSessionClose(timestamp: timestamp)
    }

    private func handleWake() {
        isIdle = false
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] Mac woke up — re-registering frontmost app")
        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppSwitch(app)
        }
    }

    deinit {
        idleTimer?.invalidate()
    }
}
#endif
