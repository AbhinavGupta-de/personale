#if os(macOS)
import Combine
import Foundation
import ServiceManagement

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    @Published var idleThresholds: [String: TimeInterval] {
        didSet {
            if let data = try? JSONEncoder().encode(idleThresholds) {
                UserDefaults.standard.set(data, forKey: "idleThresholds")
            }
        }
    }

    @Published var dayStartHour: Int {
        didSet {
            let clamped = max(0, min(23, dayStartHour))
            if clamped != dayStartHour { dayStartHour = clamped; return }
            UserDefaults.standard.set(dayStartHour, forKey: "dayStartHour")
        }
    }

    @Published var targetHoursPerDay: Int {
        didSet {
            let clamped = max(1, min(24, targetHoursPerDay))
            if clamped != targetHoursPerDay { targetHoursPerDay = clamped; return }
            UserDefaults.standard.set(targetHoursPerDay, forKey: "targetHoursPerDay")
        }
    }

    // MARK: - Distraction Blocker (M14)

    enum BlockerType: String { case popup, notification }

    @Published var blockerType: BlockerType {
        didSet { UserDefaults.standard.set(blockerType.rawValue, forKey: "blockerType") }
    }

    @Published var distractionCategories: Set<String> {
        didSet {
            let array = Array(distractionCategories)
            UserDefaults.standard.set(array, forKey: "distractionCategories")
        }
    }

    /// Accumulated seconds in a distraction category within a focus session
    /// before the blocker triggers.
    @Published var blockerThresholdSeconds: Int {
        didSet { UserDefaults.standard.set(blockerThresholdSeconds, forKey: "blockerThresholdSeconds") }
    }

    @Published var urgeSurfing: Bool {
        didSet { UserDefaults.standard.set(urgeSurfing, forKey: "urgeSurfing") }
    }

    // MARK: - Breaks (M15)

    @Published var autoDetectBreaks: Bool {
        didSet { UserDefaults.standard.set(autoDetectBreaks, forKey: "autoDetectBreaks") }
    }

    @Published var defaultBreakMinutes: Int {
        didSet { UserDefaults.standard.set(defaultBreakMinutes, forKey: "defaultBreakMinutes") }
    }

    @Published var maxBreakMinutes: Int {
        didSet { UserDefaults.standard.set(maxBreakMinutes, forKey: "maxBreakMinutes") }
    }

    @Published var fullScreenBreakMode: Bool {
        didSet { UserDefaults.standard.set(fullScreenBreakMode, forKey: "fullScreenBreakMode") }
    }

    @Published var smartBreakNotifications: Bool {
        didSet { UserDefaults.standard.set(smartBreakNotifications, forKey: "smartBreakNotifications") }
    }

    @Published var smartBreakIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(smartBreakIntervalMinutes, forKey: "smartBreakIntervalMinutes") }
    }

    // MARK: - Daily Recap (research pick)

    @Published var dailyRecapEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyRecapEnabled, forKey: "dailyRecapEnabled") }
    }

    @Published var calendarOverlayEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarOverlayEnabled, forKey: "calendarOverlayEnabled") }
    }

    // MARK: - Eye-strain (20-20-20 rule)

    @Published var eyeStrainNudgesEnabled: Bool {
        didSet { UserDefaults.standard.set(eyeStrainNudgesEnabled, forKey: "eyeStrainNudgesEnabled") }
    }

    @Published var eyeStrainIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(eyeStrainIntervalMinutes, forKey: "eyeStrainIntervalMinutes") }
    }

    static let defaultServerURL = "http://localhost:8696"

    static let defaultThresholds: [String: TimeInterval] = [
        "Code": 180,
        "Design": 150,
        "Writing": 150,
        "Reading": 180,
        "Communication": 120,
        "Browsing": 90,
        "Media": 60,
        "Utilities": 60,
        "Other": 120,
    ]

    // MARK: - Launch at Login

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
        } catch {
            print("[AppSettings] Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    // MARK: - Init

    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? Self.defaultServerURL

        if let data = UserDefaults.standard.data(forKey: "idleThresholds"),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            self.idleThresholds = decoded
        } else {
            self.idleThresholds = Self.defaultThresholds
        }

        let storedStart = UserDefaults.standard.object(forKey: "dayStartHour") as? Int
        self.dayStartHour = storedStart ?? 6

        let storedTarget = UserDefaults.standard.object(forKey: "targetHoursPerDay") as? Int
        self.targetHoursPerDay = storedTarget ?? 8

        // Blocker (M14)
        let blockerRaw = UserDefaults.standard.string(forKey: "blockerType")
        self.blockerType = BlockerType(rawValue: blockerRaw ?? "") ?? .popup
        let distraction = UserDefaults.standard.stringArray(forKey: "distractionCategories")
            ?? ["Media", "Entertainment", "Gaming"]
        self.distractionCategories = Set(distraction)
        self.blockerThresholdSeconds =
            (UserDefaults.standard.object(forKey: "blockerThresholdSeconds") as? Int) ?? 120
        self.urgeSurfing =
            (UserDefaults.standard.object(forKey: "urgeSurfing") as? Bool) ?? false

        // Breaks (M15)
        self.autoDetectBreaks =
            (UserDefaults.standard.object(forKey: "autoDetectBreaks") as? Bool) ?? true
        self.defaultBreakMinutes =
            (UserDefaults.standard.object(forKey: "defaultBreakMinutes") as? Int) ?? 5
        self.maxBreakMinutes =
            (UserDefaults.standard.object(forKey: "maxBreakMinutes") as? Int) ?? 30
        self.fullScreenBreakMode =
            (UserDefaults.standard.object(forKey: "fullScreenBreakMode") as? Bool) ?? false
        self.smartBreakNotifications =
            (UserDefaults.standard.object(forKey: "smartBreakNotifications") as? Bool) ?? false
        self.smartBreakIntervalMinutes =
            (UserDefaults.standard.object(forKey: "smartBreakIntervalMinutes") as? Int) ?? 45

        self.dailyRecapEnabled =
            (UserDefaults.standard.object(forKey: "dailyRecapEnabled") as? Bool) ?? true

        self.calendarOverlayEnabled =
            (UserDefaults.standard.object(forKey: "calendarOverlayEnabled") as? Bool) ?? false

        self.eyeStrainNudgesEnabled =
            (UserDefaults.standard.object(forKey: "eyeStrainNudgesEnabled") as? Bool) ?? false
        self.eyeStrainIntervalMinutes =
            (UserDefaults.standard.object(forKey: "eyeStrainIntervalMinutes") as? Int) ?? 20
    }

    var serverBaseURL: URL {
        URL(string: serverURL) ?? URL(string: Self.defaultServerURL)!
    }
}
#endif
