#if os(macOS)
import Combine
import Foundation

class EventClient: ObservableObject {
    let baseURL: URL
    private let store: LocalEventStore
    private let flushQueue: FlushQueue

    @Published var isServerReachable: Bool = true

    init(baseURL: URL = AppSettings.shared.serverBaseURL) {
        self.baseURL = baseURL
        self.store = .shared
        self.flushQueue = FlushQueue(store: .shared, baseURL: baseURL)

        self.flushQueue.onServerReachabilityChanged = { [weak self] reachable in
            DispatchQueue.main.async {
                self?.isServerReachable = reachable
            }
        }

        // Check server health on launch
        flushQueue.checkHealth()

        // Flush any events left over from previous session
        flushQueue.triggerFlush()

        // Run cleanup on launch
        store.deleteOldSyncedEvents()
    }

    func sendAppSwitch(appName: String, bundleId: String?, windowTitle: String?, timestamp: String) {
        store.insertAppSwitch(appName: appName, bundleId: bundleId, windowTitle: windowTitle, timestamp: timestamp)
        flushQueue.triggerFlush()
    }

    func sendSessionClose(timestamp: String, bundleId: String? = nil, sessionStartedAt: String? = nil) {
        store.insertSessionClose(timestamp: timestamp, bundleId: bundleId, sessionStartedAt: sessionStartedAt)
        flushQueue.triggerFlush()
    }

    func triggerFlush() {
        flushQueue.triggerFlush()
    }

    var pendingCount: Int {
        store.unsyncedCount()
    }
}
#endif
