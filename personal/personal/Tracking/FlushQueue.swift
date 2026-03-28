#if os(macOS)
import Foundation

final class FlushQueue {
    private let store: LocalEventStore
    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()

    private let flushLock = DispatchQueue(label: "com.abhinavgpt.personale.flushlock")
    private var _isFlushing = false
    private var retryTimer: Timer?
    private static let retryInterval: TimeInterval = 30
    private static let flushTimerInterval: TimeInterval = 60

    private var periodicTimer: Timer?

    var onServerReachabilityChanged: ((Bool) -> Void)?

    private(set) var isServerReachable: Bool = true {
        didSet {
            if oldValue != isServerReachable {
                onServerReachabilityChanged?(isServerReachable)
                if isServerReachable {
                    triggerFlush()
                }
            }
        }
    }

    init(store: LocalEventStore = .shared, baseURL: URL = AppSettings.shared.serverBaseURL) {
        self.store = store
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        startPeriodicFlush()
    }

    deinit {
        periodicTimer?.invalidate()
        retryTimer?.invalidate()
    }

    // MARK: - Flush Trigger

    func triggerFlush() {
        flushLock.async { [weak self] in
            guard let self = self else { return }
            guard !self._isFlushing else { return }
            self._isFlushing = true
            self.flushNext()
        }
    }

    // MARK: - Flush Loop

    private func flushNext() {
        let events = store.fetchUnsynced(limit: 1)
        guard let event = events.first else {
            finishFlushing()
            return
        }

        let request = buildRequest(for: event)
        guard let request = request else {
            store.markSynced(id: event.id)
            flushNext()
            return
        }

        let task = session.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }

            if let error = error {
                print("[FlushQueue] POST failed: \(error.localizedDescription)")
                self.isServerReachable = false
                self.scheduleRetry()
                self.finishFlushing()
                return
            }

            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    self.isServerReachable = true
                    self.store.markSynced(id: event.id)
                    self.flushNext()
                } else {
                    print("[FlushQueue] Server returned \(http.statusCode) for event \(event.id)")
                    self.scheduleRetry()
                    self.finishFlushing()
                }
            }
        }
        task.resume()
    }

    private func finishFlushing() {
        flushLock.async { [weak self] in
            self?._isFlushing = false
        }
    }

    // MARK: - Request Building

    private func buildRequest(for event: LocalEventStore.PendingEvent) -> URLRequest? {
        let path: String
        let body: Data?

        switch event.type {
        case "app_switch":
            path = "api/events"
            let payload = AppSwitchPayload(
                appName: event.appName ?? "Unknown",
                bundleId: event.bundleId,
                windowTitle: event.windowTitle,
                timestamp: event.timestamp
            )
            body = try? encoder.encode(payload)

        case "session_close":
            path = "api/events/close"
            let payload = ClosePayload(
                timestamp: event.timestamp,
                bundleId: event.bundleId,
                sessionStartedAt: event.sessionStartedAt
            )
            body = try? encoder.encode(payload)

        default:
            print("[FlushQueue] Unknown event type: \(event.type)")
            return nil
        }

        guard let body = body else { return nil }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    // MARK: - Retry

    private func scheduleRetry() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.retryTimer?.invalidate()
            self.retryTimer = Timer.scheduledTimer(withTimeInterval: Self.retryInterval, repeats: false) { [weak self] _ in
                self?.triggerFlush()
            }
        }
    }

    // MARK: - Periodic Flush + Health Check

    private func startPeriodicFlush() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.periodicTimer = Timer.scheduledTimer(withTimeInterval: Self.flushTimerInterval, repeats: true) { [weak self] _ in
                self?.checkHealth()
                self?.triggerFlush()
            }
        }
    }

    func checkHealth() {
        let url = baseURL.appendingPathComponent("api/health")
        let task = session.dataTask(with: url) { [weak self] _, response, error in
            guard let self = self else { return }
            if error != nil {
                self.isServerReachable = false
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                self.isServerReachable = true
            } else {
                self.isServerReachable = false
            }
        }
        task.resume()
    }
}

// Shared payload types (also used by EventClient)
struct AppSwitchPayload: Encodable {
    let appName: String
    let bundleId: String?
    let windowTitle: String?
    let timestamp: String
}

struct ClosePayload: Encodable {
    let timestamp: String
    let bundleId: String?
    let sessionStartedAt: String?
}
#endif
