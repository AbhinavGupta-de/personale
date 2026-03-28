#if os(macOS)
import Foundation

class EventClient {
    let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    init(baseURL: URL = URL(string: "http://localhost:8696")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }

    func sendAppSwitch(appName: String, bundleId: String?, windowTitle: String?, timestamp: String) {
        let url = baseURL.appendingPathComponent("api/events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AppSwitchPayload(
            appName: appName,
            bundleId: bundleId,
            windowTitle: windowTitle,
            timestamp: timestamp
        )

        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            print("[EventClient] Failed to encode payload: \(error)")
            return
        }

        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[EventClient] POST failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[EventClient] Server returned \(http.statusCode)")
                return
            }
        }
        task.resume()
    }

    func sendSessionClose(timestamp: String) {
        let url = baseURL.appendingPathComponent("api/events/close")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ClosePayload(timestamp: timestamp)

        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            print("[EventClient] Failed to encode close payload: \(error)")
            return
        }

        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[EventClient] Close POST failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[EventClient] Server returned \(http.statusCode)")
                return
            }
        }
        task.resume()
    }
}

private struct AppSwitchPayload: Encodable {
    let appName: String
    let bundleId: String?
    let windowTitle: String?
    let timestamp: String
}

private struct ClosePayload: Encodable {
    let timestamp: String
}
#endif
