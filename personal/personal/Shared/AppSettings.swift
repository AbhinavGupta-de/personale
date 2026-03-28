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
    }

    var serverBaseURL: URL {
        URL(string: serverURL) ?? URL(string: Self.defaultServerURL)!
    }
}
#endif
