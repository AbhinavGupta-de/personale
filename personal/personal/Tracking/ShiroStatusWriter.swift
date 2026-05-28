#if os(macOS)
import Combine
import Foundation

/// Continuously publishes the user's live activity so the Shiro desktop-pet app
/// can mirror the work day. Two sinks:
///   A. Writes `~/.personale/status.json` atomically every ~15s (the 7-field
///      contract from `GET /api/activity/current`, re-encoded verbatim).
///   B. Fires forget-and-forget POSTs to Shiro's local MCP server on
///      celebration (hit daily target) / alert (context-switch spike) edges.
final class ShiroStatusWriter: ObservableObject {

    private var timer: Timer?

    // Edge-detection state for Option B transitions.
    private var lastTargetPct: Double?
    private var lastSwitches: Int?

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()

    /// Destination for the atomic status file: `~/.personale/status.json`.
    private var statusFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".personale")
            .appendingPathComponent("status.json")
    }

    func start() {
        // Fire immediately so the file exists ASAP, then every 15s.
        Task { await poll() }
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() async {
        // Backend may be down (built in parallel) — that's a silent no-op.
        guard let activity = try? await APIClient.shared.fetchCurrentActivity() else { return }

        writeStatusFile(activity)
        detectTransitions(activity)
    }

    /// Atomically write the 7-field schema to `~/.personale/status.json`.
    /// `Data.write(to:options:.atomic)` writes to a temp file and renames into
    /// place, so readers never see a partial file.
    private func writeStatusFile(_ activity: CurrentActivityResponse) {
        let dir = statusFileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
            let data = try encoder.encode(activity)
            try data.write(to: statusFileURL, options: .atomic)
        } catch {
            // Disk/permission hiccups shouldn't kill the polling loop.
        }
    }

    /// Option B: detect rising edges and notify Shiro.
    private func detectTransitions(_ activity: CurrentActivityResponse) {
        if let last = lastTargetPct, last < 1.0, activity.dailyTargetPct >= 1.0 {
            sendReaction("celebrate", ttl: 300)
        }
        if let last = lastSwitches, last < 20, activity.contextSwitchesLastHour >= 20 {
            sendReaction("alert", ttl: 120)
        }
        lastTargetPct = activity.dailyTargetPct
        lastSwitches = activity.contextSwitchesLastHour
    }

    /// Fire-and-forget POST to Shiro's local MCP server. All errors swallowed —
    /// connection-refused when Shiro isn't running is expected and fine.
    private func sendReaction(_ reaction: String, ttl: Int) {
        guard let url = URL(string: "http://127.0.0.1:47655/mcp") else { return }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": [
                "name": "set_reaction",
                "arguments": [
                    "reaction": reaction,
                    "ttlSeconds": ttl
                ]
            ]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 0.5
        req.httpBody = body

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.5
        let session = URLSession(configuration: config)

        Task.detached {
            _ = try? await session.data(for: req)
        }
    }
}
#endif
