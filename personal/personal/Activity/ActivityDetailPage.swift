#if os(macOS)
import SwiftUI

// MARK: - Activity Detail Page

struct ActivityDetailPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.cardGap) {
                DateNavigator(
                    dateText: viewModel.displayDate,
                    isToday: viewModel.isToday,
                    isLoading: viewModel.isLoading,
                    onPrevious: { viewModel.goToPreviousDay() },
                    onNext: { viewModel.goToNextDay() },
                    onToday: { viewModel.goToToday() }
                )

                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                        // Left: Vertical timeline + Session list
                        VStack(spacing: AppMetrics.cardGap) {
                            SessionTimelineCard(
                                sessions: viewModel.sessions,
                                selectedSession: nil,
                                categoryColor: viewModel.categoryColor,
                                parseTime: viewModel.parseTimeToHour
                            ) { session in
                                viewModel.selectSession(session)
                            }

                            SessionListCard(
                                sessions: viewModel.sessions,
                                selectedSession: nil,
                                categoryColor: viewModel.categoryColor
                            ) { session in
                                viewModel.selectSession(session)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Right: Daily Summary
                        DailySummaryCard(viewModel: viewModel)
                            .frame(width: 360)
                    }
                }
            }
            .padding(AppMetrics.contentPadding)
        }
        .overlay {
            if viewModel.showSessionDetail, let session = viewModel.selectedSession {
                SessionDetailOverlay(
                    session: session,
                    categoryColor: viewModel.categoryColor,
                    formatDuration: viewModel.formatDuration
                ) {
                    viewModel.showSessionDetail = false
                }
            }
        }
        .onAppear { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))
            Text("No sessions recorded")
                .font(.system(size: 14))
                .foregroundStyle(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .dashboardCard()
    }
}

// MARK: - Session Timeline Card (vertical)

struct SessionTimelineCard: View {
    let sessions: [FocusSessionResponse]
    let selectedSession: FocusSessionResponse?
    let categoryColor: (String) -> Color
    let parseTime: (String) -> Double?
    let onSelect: (FocusSessionResponse) -> Void

    @Environment(\.theme) private var theme

    private let hourHeight: CGFloat = 44

    private var startHour: Int {
        guard !sessions.isEmpty else { return 0 }
        let earliest = sessions.compactMap { parseTime($0.startTime) }.min() ?? 0
        return max(0, Int(floor(earliest)))
    }

    private var endHour: Int {
        guard !sessions.isEmpty else { return 24 }
        let latest = sessions.compactMap { parseTime($0.endTime) }.max() ?? 24
        return min(24, Int(ceil(latest)) + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Activity")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines and labels — each row is hourHeight tall
                    // with content pinned to the TOP so the label's baseline
                    // aligns with y = hour * hourHeight (the same origin the
                    // session blocks use for their topOffset).
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HStack(alignment: .center, spacing: 8) {
                                Text(formatHourLabel(hour))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(theme.mutedForeground)
                                    .frame(width: 52, alignment: .trailing)

                                Rectangle()
                                    .fill(theme.border.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight, alignment: .top)
                        }
                    }

                    // Session blocks — use actual proportional height, min 3pt for visibility
                    ForEach(sessions) { session in
                        if let start = parseTime(session.startTime),
                            let end = parseTime(session.endTime),
                            end > start
                        {
                            let topOffset =
                                CGFloat(start - Double(startHour)) * hourHeight
                            let blockHeight =
                                CGFloat(end - start) * hourHeight

                            sessionBlock(session: session, height: max(blockHeight, 3))
                                .offset(x: 68, y: topOffset)
                        }
                    }
                }
                .frame(height: CGFloat(endHour - startHour) * hourHeight)
            }
            .frame(height: min(CGFloat(endHour - startHour) * hourHeight, 520))
            .padding(.horizontal, 8)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }

    private func sessionBlock(session: FocusSessionResponse, height: CGFloat) -> some View {
        let isSelected = selectedSession?.id == session.id
        let color = categoryColor(session.name)

        return Button { onSelect(session) } label: {
            ZStack(alignment: .topLeading) {
                // Background fills exact height
                RoundedRectangle(cornerRadius: height > 6 ? 6 : 2)
                    .fill(color.opacity(isSelected ? 0.9 : 0.6))

                // Labels only if block is tall enough
                if height >= 28 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        if height >= 40 {
                            Text("\(session.startTime) - \(session.endTime)")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: height > 6 ? 6 : 2))
            .overlay(
                RoundedRectangle(cornerRadius: height > 6 ? 6 : 2)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help("\(session.name) \(session.startTime)-\(session.endTime) (\(session.duration))")
    }

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12:00 AM" }
        if hour < 12 { return "\(hour):00 AM" }
        if hour == 12 { return "12:00 PM" }
        return "\(hour - 12):00 PM"
    }
}

// MARK: - Session List Card

struct SessionListCard: View {
    let sessions: [FocusSessionResponse]
    let selectedSession: FocusSessionResponse?
    let categoryColor: (String) -> Color
    let onSelect: (FocusSessionResponse) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Sessions")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    let isSelected = selectedSession?.id == session.id

                    Button { onSelect(session) } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColor(session.name))
                                .frame(width: 4, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.foreground)
                                Text("\(session.startTime) - \(session.endTime)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.mutedForeground)
                            }

                            Spacer()

                            Text(session.duration)
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Session Detail Card

struct SessionDetailCard: View {
    let session: FocusSessionResponse
    let categoryColor: (String) -> Color
    let formatDuration: (Int) -> String

    @Environment(\.theme) private var theme

    private var allDomains: [DomainTimeResponse] {
        session.topDomains ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.foreground)
                    Text("\(session.startTime) – \(session.endTime)")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                }
                Spacer()
                Text(session.duration)
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }
            .padding(16)

            Divider().opacity(0.3).padding(.horizontal, 16)

            // ── Category donut + stats ──
            HStack(spacing: 20) {
                // Mini donut chart
                ZStack {
                    ForEach(Array(session.categories.enumerated()), id: \.offset) { i, cat in
                        let startAngle = categoryStartAngle(index: i)
                        let endAngle = startAngle + Angle(degrees: Double(cat.percent) * 3.6)
                        Circle()
                            .trim(from: CGFloat(startAngle.degrees / 360),
                                  to: CGFloat(endAngle.degrees / 360))
                            .stroke(categoryColor(cat.category), lineWidth: 8)
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 0) {
                        Text("\(session.apps.count)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.foreground)
                        Text("apps")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
                .frame(width: 72, height: 72)

                // Category legend
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(session.categories.enumerated()), id: \.offset) { _, cat in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColor(cat.category))
                                .frame(width: 8, height: 8)
                            Text(cat.category)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                            Spacer()
                            Text("\(cat.percent)%")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                            Text(formatDuration(cat.totalSeconds))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground.opacity(0.7))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)

            Divider().opacity(0.3).padding(.horizontal, 16)

            // ── Top Apps ──
            VStack(alignment: .leading, spacing: 6) {
                Text("TOP APPS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(theme.mutedForeground)

                ForEach(session.apps.prefix(6)) { app in
                    sessionAppRow(app: app)
                }
                if session.apps.count > 6 {
                    Text("+\(session.apps.count - 6) more")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedForeground.opacity(0.6))
                        .padding(.leading, 40)
                }
            }
            .padding(16)

            // ── Top Domains (if any browser usage) ──
            if !allDomains.isEmpty {
                Divider().opacity(0.3).padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP SITES")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(theme.mutedForeground)

                    ForEach(allDomains) { domain in
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                                .frame(width: 20)

                            Text(domain.domain)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)

                            Spacer()

                            Text(formatDuration(domain.seconds))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(16)
            }

            Spacer(minLength: 8)
        }
        .dashboardCard()
    }

    // ── Helpers ──

    private func sessionAppRow(app: SessionAppBreakdownResponse) -> some View {
        HStack(spacing: 8) {
            Text("\(app.percent)%")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 30, alignment: .trailing)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(categoryColor(app.category))
                    .frame(width: max(2, CGFloat(app.percent) / 100.0 * geo.size.width))
            }
            .frame(width: 50, height: 5)

            Text(app.appName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)

            Spacer()

            Text(formatDuration(app.totalSeconds))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
        }
    }

    private func categoryStartAngle(index: Int) -> Angle {
        let preceding = session.categories.prefix(index).reduce(0) { $0 + $1.percent }
        return Angle(degrees: Double(preceding) * 3.6)
    }
}

// MARK: - Daily Summary Card

struct DailySummaryCard: View {
    @ObservedObject var viewModel: ActivityViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Daily Summary")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider().opacity(0.3).padding(.horizontal, 16)

            // Focus headline
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Focus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text(viewModel.totalFocusDuration)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }
                Text("Automatically created based on your activity.")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.mutedForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Percent of Target
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Percent of Target")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedForeground)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f%%", viewModel.percentOfTarget))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(theme.foreground)
                        Text("of 8 hr 0 min")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().opacity(0.3).padding(.horizontal, 16)

            // Stats grid
            HStack(spacing: 24) {
                summaryStatItem(label: "Focus Time", value: viewModel.totalFocusDuration)
                summaryStatItem(label: "Sessions", value: "\(viewModel.sessionCount)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.3).padding(.horizontal, 16)

            // Categories
            VStack(alignment: .leading, spacing: 8) {
                Text("Categories")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.bottom, 2)

                ForEach(Array(viewModel.categoryBreakdown.enumerated()), id: \.offset) { _, cat in
                    HStack(spacing: 8) {
                        Text("\(cat.percent)%")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 28, alignment: .trailing)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(CategoryColors.color(for: cat.category))
                            .frame(width: 10, height: 10)

                        Text(cat.category)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.foreground)

                        Spacer()

                        Text(viewModel.formatDuration(cat.totalSeconds))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }

    private func summaryStatItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(theme.mutedForeground)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.foreground)
        }
    }
}

// MARK: - Session Detail Overlay

struct SessionDetailOverlay: View {
    let session: FocusSessionResponse
    let categoryColor: (String) -> Color
    let formatDuration: (Int) -> String
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Dimmed backdrop — click to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Modal card
            ScrollView {
                SessionDetailCard(
                    session: session,
                    categoryColor: categoryColor,
                    formatDuration: formatDuration
                )
            }
            .frame(maxHeight: 620)
            .frame(width: 480)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.5), radius: 20)
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
}
#endif
