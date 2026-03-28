#if os(macOS)
import SwiftUI

struct SettingsPage: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject var appTracker: AppTracker

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.foreground)

                generalSection
                trackingSection
                dataSection
                aboutSection
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - General

    private var generalSection: some View {
        settingsCard(title: "General") {
            VStack(alignment: .leading, spacing: 16) {
                // Server URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("Server URL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.mutedForeground)
                    TextField("http://localhost:8696", text: $settings.serverURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                        .padding(8)
                        .background(theme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(theme.border.opacity(0.6), lineWidth: 1)
                        )
                }

                Divider().opacity(0.4)

                // Server status
                HStack(spacing: 8) {
                    Circle()
                        .fill(appTracker.eventClient.isServerReachable ? theme.success : theme.warning)
                        .frame(width: 8, height: 8)
                    Text(appTracker.eventClient.isServerReachable ? "Server Online" : "Server Offline")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                }

                Divider().opacity(0.4)

                // Launch at login
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.foreground)
                        Text("Start Personale automatically when you log in")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.isLaunchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        settingsCard(title: "Tracking") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Idle Thresholds")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                Text("Seconds of inactivity before a session is closed, per category")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground.opacity(0.7))

                let categories = settings.idleThresholds.keys.sorted()
                ForEach(categories, id: \.self) { category in
                    HStack {
                        Text(category)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 120, alignment: .leading)
                        TextField("seconds", value: Binding(
                            get: { Int(settings.idleThresholds[category] ?? 120) },
                            set: { settings.idleThresholds[category] = TimeInterval($0) }
                        ), format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.border.opacity(0.6), lineWidth: 1)
                            )
                        Text("s")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                        Spacer()
                    }
                }

                Button("Reset to Defaults") {
                    settings.idleThresholds = AppSettings.defaultThresholds
                }
                .font(.system(size: 11))
                .foregroundStyle(theme.primary)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        settingsCard(title: "Data") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pending Events")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text("\(appTracker.eventClient.pendingCount)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.mutedForeground)
                }

                Button("Force Sync") {
                    appTracker.eventClient.triggerFlush()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.primaryForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        settingsCard(title: "About") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Version")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.mutedForeground)
                }
                HStack {
                    Text("Build")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
        }
    }

    // MARK: - Card Helper

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(theme.mutedForeground)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.border.opacity(0.4), lineWidth: 1)
            )
        }
    }
}
#endif
