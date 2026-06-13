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

    func sendAppSwitch(appName: String, bundleId: String?, windowTitle: String?,
                       enrichedContext: String?, timestamp: String) {
        store.insertAppSwitch(appName: appName, bundleId: bundleId, windowTitle: windowTitle,
                              enrichedContext: enrichedContext, timestamp: timestamp)
        flushQueue.triggerFlush()
    }

    func sendSessionClose(timestamp: String, bundleId: String? = nil, sessionStartedAt: String? = nil) {
        store.insertSessionClose(timestamp: timestamp, bundleId: bundleId, sessionStartedAt: sessionStartedAt)
        flushQueue.triggerFlush()
    }

    func sendIdleBlock(start: String, end: String) {
        let payload = IdleBlockPayload(startedAt: start, endedAt: end)
        guard let body = try? JSONEncoder().encode(payload) else { return }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/events/idle"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {
                print("[EventClient] Idle block POST failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isServerReachable = false
                }
                return
            }
            if let http = response as? HTTPURLResponse {
                DispatchQueue.main.async {
                    self?.isServerReachable = http.statusCode == 200
                }
            }
        }.resume()
    }

    func triggerFlush() {
        flushQueue.triggerFlush()
    }

    var pendingCount: Int {
        store.unsyncedCount()
    }
}

private struct IdleBlockPayload: Encodable {
    let startedAt: String
    let endedAt: String
}
#endif
