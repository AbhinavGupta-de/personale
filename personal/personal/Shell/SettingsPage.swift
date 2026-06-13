#if os(macOS)
import SwiftUI

struct SettingsPage: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject var appTracker: AppTracker

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space9) {
                Text("Settings")
                    .font(AppFont.text(FontSize.xl2, .bold))
                    .foregroundStyle(theme.foreground)

                generalSection
                workDaySection
                calendarSection
                categoriesSection
                trackingRulesSection
                trackingSection
                distractionBlockerSection
                breaksSection
                dataSection
                aboutSection
            }
            .padding(Spacing.space9)
        }
        .background(theme.background)
    }

    // MARK: - General

    private var generalSection: some View {
        settingsCard(title: "General") {
            VStack(alignment: .leading, spacing: Spacing.space7) {
                // Server URL
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Server URL")
                        .font(AppFont.text(FontSize.base, .medium))
                        .foregroundStyle(theme.mutedForeground)
                    TextField("http://localhost:8696", text: $settings.serverURL)
                        .textFieldStyle(.plain)
                        .font(AppFont.mono(FontSize.md))
                        .foregroundStyle(theme.foreground)
                        .padding(Spacing.space3)
                        .background(theme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(theme.border.opacity(0.6), lineWidth: 1)
                        )
                }

                Divider().opacity(0.4)

                // Server status
                HStack(spacing: Spacing.space3) {
                    Circle()
                        .fill(appTracker.eventClient.isServerReachable ? theme.success : theme.warning)
                        .frame(width: 8, height: 8)
                    Text(appTracker.eventClient.isServerReachable ? "Server Online" : "Server Offline")
                        .font(AppFont.text(FontSize.base))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                }

                Divider().opacity(0.4)

                // Launch at login
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(AppFont.text(FontSize.md, .medium))
                            .foregroundStyle(theme.foreground)
                        Text("Start Personale automatically when you log in")
                            .font(AppFont.text(FontSize.sm))
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

                Divider().opacity(0.4)

                // Daily recap notification
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Recap Notification")
                            .font(AppFont.text(FontSize.md, .medium))
                            .foregroundStyle(theme.foreground)
                        Text("Summary of yesterday's tracked time, fired 1 hour after your day starts")
                            .font(AppFont.text(FontSize.sm))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.dailyRecapEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.dailyRecapEnabled) { _, _ in
                            DailyRecapService.shared.reschedule()
                        }
                }

                Divider().opacity(0.4)

                // 20-20-20 eye-strain nudge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("20-20-20 Eye Strain Nudge")
                            .font(AppFont.text(FontSize.md, .medium))
                            .foregroundStyle(theme.foreground)
                        Text("Every 20 min of active work, look 20 ft away for 20 sec. Suppressed during focus sessions.")
                            .font(AppFont.text(FontSize.sm))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.eyeStrainNudgesEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.eyeStrainNudgesEnabled) { _, _ in
                            EyeStrainNudgeService.shared.reschedule()
                        }
                }
            }
        }
    }

    // MARK: - Work Day

    private var workDaySection: some View {
        settingsCard(title: "Work Day") {
            VStack(alignment: .leading, spacing: Spacing.space7) {
                HStack {
                    Text("Day Start")
                        .font(AppFont.text(FontSize.base))
                        .foregroundStyle(theme.foreground)
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: $settings.dayStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                    Spacer()
                }

                HStack {
                    Text("Target Hours")
                        .font(AppFont.text(FontSize.base))
                        .foregroundStyle(theme.foreground)
                        .frame(width: 120, alignment: .leading)
                    Stepper("\(settings.targetHoursPerDay) hr", value: $settings.targetHoursPerDay, in: 1...24)
                        .font(AppFont.mono(FontSize.base))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        settingsCard(title: "Calendar") {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Calendar Overlay")
                        .font(AppFont.text(FontSize.md, .medium))
                        .foregroundStyle(theme.foreground)
                    Text("Show local calendar events on the day activity timeline")
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.mutedForeground)
                }
                Spacer()
                Toggle("", isOn: $settings.calendarOverlayEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: settings.calendarOverlayEnabled) { _, enabled in
                        if enabled {
                            Task { _ = await CalendarService.shared.requestAccess() }
                        }
                    }
            }
        }
    }

    // MARK: - Categories (M12)

    private var categoriesSection: some View {
        settingsCard(title: "Categories") {
            CategoriesSettingsCard()
        }
    }

    // MARK: - Tracking Rules (M13)

    private var trackingRulesSection: some View {
        settingsCard(title: "Tracking Rules") {
            TrackingRulesCard()
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        settingsCard(title: "Tracking") {
            VStack(alignment: .leading, spacing: Spacing.space5) {
                Text("Idle Thresholds")
                    .font(AppFont.text(FontSize.base, .medium))
                    .foregroundStyle(theme.mutedForeground)
                Text("Seconds of inactivity before a session is closed, per category")
                    .font(AppFont.text(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground.opacity(0.7))

                let categories = settings.idleThresholds.keys.sorted()
                ForEach(categories, id: \.self) { category in
                    HStack {
                        Text(category)
                            .font(AppFont.text(FontSize.base))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 120, alignment: .leading)
                        TextField("seconds", value: Binding(
                            get: { Int(settings.idleThresholds[category] ?? 120) },
                            set: { settings.idleThresholds[category] = TimeInterval($0) }
                        ), format: .number)
                            .textFieldStyle(.plain)
                            .font(AppFont.mono(FontSize.base))
                            .foregroundStyle(theme.foreground)
                            .frame(width: 60)
                            .padding(.horizontal, Spacing.space3)
                            .padding(.vertical, Spacing.space1)
                            .background(theme.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.xs)
                                    .stroke(theme.border.opacity(0.6), lineWidth: 1)
                            )
                        Text("s")
                            .font(AppFont.text(FontSize.sm))
                            .foregroundStyle(theme.mutedForeground)
                        Spacer()
                    }
                }

                Button("Reset to Defaults") {
                    settings.idleThresholds = AppSettings.defaultThresholds
                }
                .font(AppFont.text(FontSize.sm))
                .foregroundStyle(theme.primary)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Distraction Blocker (M14) / Breaks (M15)

    private var distractionBlockerSection: some View {
        settingsCard(title: "Distraction Blocker") {
            DistractionBlockerCard()
        }
    }

    private var breaksSection: some View {
        settingsCard(title: "Breaks") {
            BreaksSettingsCard()
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        settingsCard(title: "Data") {
            VStack(alignment: .leading, spacing: Spacing.space5) {
                HStack {
                    Text("Pending Events")
                        .font(AppFont.text(FontSize.base))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text("\(appTracker.eventClient.pendingCount)")
                        .font(AppFont.mono(FontSize.base))
                        .foregroundStyle(theme.mutedForeground)
                }

                HStack(spacing: Spacing.space3) {
                    Button("Force Sync") {
                        appTracker.eventClient.triggerFlush()
                    }
                    .font(AppFont.text(FontSize.base, .medium))
                    .foregroundStyle(theme.primaryForeground)
                    .padding(.horizontal, Spacing.space6)
                    .padding(.vertical, Spacing.space2)
                    .background(theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    .buttonStyle(.plain)

                    Button("Export Last 30 Days (CSV)") {
                        Task { await CSVExport.exportLast30Days() }
                    }
                    .font(AppFont.text(FontSize.base, .medium))
                    .foregroundStyle(theme.foreground)
                    .padding(.horizontal, Spacing.space6)
                    .padding(.vertical, Spacing.space2)
                    .background(theme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        settingsCard(title: "About") {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                HStack {
                    Text("Version")
                        .font(AppFont.text(FontSize.base))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(AppFont.mono(FontSize.base))
                        .foregroundStyle(theme.mutedForeground)
                }
                HStack {
                    Text("Build")
                        .font(AppFont.text(FontSize.base))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(AppFont.mono(FontSize.base))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
        }
    }

    // MARK: - Card Helper

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space7) {
            Text(title.uppercased())
                .font(AppFont.text(FontSize.sm, .semibold))
                .tracking(1)
                .foregroundStyle(theme.mutedForeground)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(Spacing.space7)
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
