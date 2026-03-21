#if os(macOS)
import Combine
import SwiftUI

// MARK: - Main App Shell

struct AppShell: View {
    @Environment(\.theme) private var theme
    @State private var activePage = "dashboard"

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                Sidebar(activePage: $activePage)
                VStack(spacing: 0) {
                    TopHeader()
                    Group {
                        switch activePage {
                        case "activity":
                            ActivityDetailPage()
                        case "productivity":
                            ProductivityPage()
                        default:
                            DashboardPage()
                        }
                    }
                    .padding(.bottom, AppMetrics.bottomBarHeight)
                }
            }
            BottomBar()
                .padding(.leading, AppMetrics.sidebarWidth)
        }
        .background(theme.background)
        .frame(minWidth: 1100, minHeight: 700)
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Environment(\.theme) private var theme
    @Binding var activePage: String

    private var topItems: [(id: String, icon: String, label: String)] {
        var items: [(id: String, icon: String, label: String)] = [
            ("dashboard", "house", "Dashboard"),
        ]
        if SidebarFeatures.showActivity {
            items.append(("activity", "timer", "Activity"))
        }
        if SidebarFeatures.showFocus {
            items.append(("focus", "waveform.path.ecg", "Focus"))
        }
        if SidebarFeatures.showGoals {
            items.append(("goals", "target", "Goals"))
        }
        if SidebarFeatures.showCalendar {
            items.append(("calendar", "calendar", "Calendar"))
        }
        if SidebarFeatures.showTasks {
            items.append(("tasks", "list.clipboard", "Tasks"))
        }
        if SidebarFeatures.showHabits {
            items.append(("habits", "checkmark.square", "Habits"))
        }
        if SidebarFeatures.showProductivity {
            items.append(("productivity", "chart.bar", "Productivity"))
        }
        return items
    }

    private var bottomItems: [(id: String, icon: String, label: String)] {
        var items: [(id: String, icon: String, label: String)] = []
        if SidebarFeatures.showTeam {
            items.append(("team", "person.2", "Team"))
        }
        items.append(("settings", "gear", "Settings"))
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top nav
            VStack(spacing: 2) {
                ForEach(topItems, id: \.id) { item in
                    sidebarButton(item: item)
                }
            }
            .padding(.top, 12)

            Spacer()

            // Bottom nav
            VStack(spacing: 2) {
                ForEach(bottomItems, id: \.id) { item in
                    sidebarButton(item: item)
                }
            }
            .padding(.bottom, 12)
        }
        .frame(width: AppMetrics.sidebarWidth)
        .background(theme.card)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.border.opacity(0.6))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func sidebarButton(item: (id: String, icon: String, label: String)) -> some View {
        let isActive = activePage == item.id

        Button {
            activePage = item.id
        } label: {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 36, height: 36)
                .foregroundStyle(isActive ? theme.primary : theme.mutedForeground)
                .background(
                    isActive
                        ? theme.primary.opacity(0.12)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(item.label)
    }
}

// MARK: - Top Header

struct TopHeader: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            // Left: nav arrows
            HStack(spacing: 2) {
                headerButton(icon: "chevron.left")
                headerButton(icon: "chevron.right")
            }

            Spacer()

            // Center: brand
            Text("PERSONALE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(3)
                .foregroundStyle(theme.foreground.opacity(0.8))

            Spacer()

            // Right: avatar
            Circle()
                .fill(theme.primary)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("A")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.primaryForeground)
                )
        }
        .padding(.horizontal, 20)
        .frame(height: AppMetrics.topHeaderHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.opacity(0.4))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func headerButton(icon: String) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Bar

struct BottomBar: View {
    @Environment(\.theme) private var theme
    @State private var focusActive = true
    @State private var secondsRemaining = 1174

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            // Left: power + continue + timer
            HStack(spacing: 10) {
                // Power
                Button {} label: {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.success)
                }
                .buttonStyle(.plain)

                // Continue
                Button {} label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.success)
                }
                .buttonStyle(.plain)

                // Timer ring + time
                HStack(spacing: 8) {
                    timerRing
                    Text(formatTime(secondsRemaining))
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.accent)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("FOCUS TIME")
                            .font(.system(size: 7, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(theme.mutedForeground)
                        Text("REMAINING")
                            .font(.system(size: 7, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
                .padding(.leading, 4)

                // End/Start Focus
                Button {
                    focusActive.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Text(focusActive ? "End Focus" : "Start Focus")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                            .opacity(0.6)
                    }
                    .foregroundStyle(theme.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(theme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.border.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right: ambient controls
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.secondary.opacity(0.8))
                    .frame(width: 24, height: 24)

                Text("Silence")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)

                Button {} label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "message")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: AppMetrics.bottomBarHeight)
        .background(theme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.border.opacity(0.4))
                .frame(height: 1)
        }
        .onReceive(timer) { _ in
            if focusActive && secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
    }

    private var timerRing: some View {
        let progress = Double(secondsRemaining) / 1800.0
        return ZStack {
            Circle()
                .stroke(theme.border, lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
    }

    private func formatTime(_ total: Int) -> String {
        let m = total / 60
        let s = total % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Date Navigator

struct DateNavigator: View {
    let dateText: String
    let views: [String]
    var isToday: Bool
    var isLoading: Bool
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onToday: (() -> Void)?
    @State private var activeView: String
    @Environment(\.theme) private var theme

    init(dateText: String, views: [String] = ["Day", "Week"], defaultView: String = "Day",
         isToday: Bool = true, isLoading: Bool = false,
         onPrevious: (() -> Void)? = nil, onNext: (() -> Void)? = nil, onToday: (() -> Void)? = nil) {
        self.dateText = dateText
        self.views = views
        self.isToday = isToday
        self.isLoading = isLoading
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onToday = onToday
        self._activeView = State(initialValue: defaultView)
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text(dateText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.foreground)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // View toggle
                HStack(spacing: 0) {
                    ForEach(views, id: \.self) { view in
                        Button {
                            activeView = view
                        } label: {
                            Text(view)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(activeView == view ? theme.foreground : theme.mutedForeground)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    activeView == view
                                        ? theme.card
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(theme.secondary.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                // Calendar icon (future: date picker)
                headerIconButton(icon: "calendar", action: nil)

                // Today button — only shown when viewing a past date
                if !isToday {
                    Button { onToday?() } label: {
                        Text("Today")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                // Prev/Next
                HStack(spacing: 0) {
                    headerIconButton(icon: "chevron.left", action: onPrevious)
                    headerIconButton(icon: "chevron.right", action: onNext)
                }
            }
        }
    }

    @ViewBuilder
    private func headerIconButton(icon: String, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
#endif
