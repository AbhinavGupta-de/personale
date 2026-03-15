#if os(macOS)
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appTracker: AppTracker
    @State private var stats: DailyStatsResponse?
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personale")
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Current App")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appTracker.currentAppName)
                    .font(.body.bold())
                if !appTracker.currentBundleID.isEmpty {
                    Text(appTracker.currentBundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Text(appTracker.isIdle ? "Idle" : "Tracking")
                    .font(.caption.bold())
                    .foregroundStyle(appTracker.isIdle ? .orange : .green)
                Spacer()
                Text("Idle sessions: \(stats?.idleSessionCount ?? 0)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let stats = stats, !stats.apps.isEmpty {
                Divider()

                Text("Today — \(formatDuration(stats.totalTrackedSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(stats.apps.prefix(5), id: \.appName) { app in
                    HStack {
                        Text(app.appName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(formatDuration(app.totalSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if stats.apps.count > 5 {
                    Text("+\(stats.apps.count - 5) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 260)
        .onAppear { startRefreshing() }
        .onDisappear { stopRefreshing() }
    }

    private func startRefreshing() {
        fetchStats()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            fetchStats()
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func fetchStats() {
        let url = APIClient.shared.baseURL.appendingPathComponent("api/stats/today")
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return }
            if let decoded = try? JSONDecoder().decode(DailyStatsResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.stats = decoded
                }
            }
        }.resume()
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
#endif
