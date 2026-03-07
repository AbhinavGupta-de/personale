#if os(macOS)
import AppKit
import Combine

class AppTracker: ObservableObject {
    @Published var currentAppName: String = ""
    @Published var currentBundleID: String = ""
    @Published var lastSwitchTime: Date = Date()

    private var cancellables = Set<AnyCancellable>()
    private let eventClient: EventClient

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
    }

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

    private func handleSleep() {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] Mac going to sleep — closing active session")
        eventClient.sendSessionClose(timestamp: timestamp)
    }

    private func handleWake() {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] Mac woke up — re-registering frontmost app")
        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppSwitch(app)
        }
    }
}
#endif
