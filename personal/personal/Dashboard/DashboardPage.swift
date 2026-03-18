#if os(macOS)
import SwiftUI

// MARK: - Dashboard Page

struct DashboardPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = DashboardViewModel()

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

                // 2-column layout: main content left, right sidebar column
                HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                    // ── Left main area ──
                    VStack(spacing: AppMetrics.cardGap) {
                        // Timeline (full width of main area)
                        TimelineCard(data: viewModel.timeline)

                        // Break Timer + Workblocks row
                        if DashboardFeatures.showBreakTimer || DashboardFeatures.showWorkblocks {
                            HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                                if DashboardFeatures.showBreakTimer {
                                    BreakTimerCard(
                                        timeSinceBreak: viewModel.breakTimerText,
                                        breakToWorkRatio: viewModel.breakToWorkRatio
                                    )
                                    .frame(width: 260)
                                }
                                if DashboardFeatures.showWorkblocks {
                                    WorkblocksCard(data: viewModel.workblocks)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        // Activity + Projects row
                        HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                            ActivityLogCard(data: viewModel.activityLog)
                                .frame(maxWidth: .infinity)
                            if DashboardFeatures.showProjects {
                                ProjectsCard(data: MockData.projects)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // ── Right column (consistent width, spans all rows) ──
                    VStack(spacing: AppMetrics.cardGap) {
                        WorkHoursCard(data: viewModel.workHours)

                        if DashboardFeatures.showScores {
                            ScoresCard(data: MockData.scores)
                        }

                        TimeBreakdownCard(data: viewModel.timeBreakdown)
                    }
                    .frame(width: 320)
                }
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.startRefreshing() }
        .onDisappear { viewModel.stopRefreshing() }
    }
}

// MARK: - Timeline Card

struct TimelineCard: View {
    let data: [MockData.TimelineBlock]
    @Environment(\.theme) private var theme

    private var startHour: Double {
        guard !data.isEmpty else { return 6 }
        let minStart = data.map(\.start).min() ?? 6
        return max(0, floor(minStart) - 1)
    }

    private var endHour: Double {
        guard !data.isEmpty else { return 20 }
        let maxEnd = data.map(\.end).max() ?? 20
        return min(24, ceil(maxEnd) + 1)
    }

    private var totalHours: Double {
        endHour - startHour
    }

    private var hourLabels: [Int] {
        let start = Int(startHour)
        let end = Int(endHour)
        // Choose a step that keeps labels readable (every 2 hours)
        let step = 2
        let alignedStart = start % step == 0 ? start : start + (step - start % step)
        return stride(from: alignedStart, through: end, by: step).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Timeline")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Timeline bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.secondary.opacity(0.6))
                    .frame(height: 36)

                GeometryReader { geo in
                    ForEach(Array(data.enumerated()), id: \.offset) { _, block in
                        let left = (block.start - startHour) / totalHours * geo.size.width
                        let width = (block.end - block.start) / totalHours * geo.size.width
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.activityColor(for: block.type).opacity(0.85))
                            .frame(width: max(width, 2), height: 36)
                            .offset(x: left)
                            .help(block.label)
                    }
                }
                .frame(height: 36)
            }
            .padding(.horizontal, 16)

            // Hour labels
            HStack {
                ForEach(hourLabels, id: \.self) { hour in
                    Text(hourLabelText(hour))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(theme.mutedForeground)
                    if hour != hourLabels.last { Spacer() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }

    private func hourLabelText(_ hour: Int) -> String {
        if hour == 0 { return "12:00" }
        if hour == 24 { return "12:00" }
        return hour > 12 ? "\(hour - 12):00" : "\(hour):00"
    }
}

// MARK: - Work Hours Card

struct WorkHoursCard: View {
    let data: MockData.WorkHours
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Work Hours")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Metrics row
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total time worked")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedForeground)
                    Text(data.totalWorked)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Percent of work day")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedForeground)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(String(format: "%.1f", data.percentOfDay))%")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(theme.foreground)
                        Text("of \(data.targetHours)")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 14)
        }
        .dashboardCard()
    }

}

// MARK: - Break Timer Card

struct BreakTimerCard: View {
    let timeSinceBreak: String
    let breakToWorkRatio: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Break Timer")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time since last break")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(theme.mutedForeground)
                    Text(timeSinceBreak)
                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.foreground)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Break to work ratio")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(theme.mutedForeground)
                    Text(breakToWorkRatio)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 14)
        }
        .dashboardCard()
    }
}

// MARK: - Workblocks Card

struct WorkblocksCard: View {
    let data: [MockData.Workblock]
    @Environment(\.theme) private var theme

    private func borderColor(for task: String) -> Color {
        CategoryColors.color(for: task)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Workblocks")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, block in
                        HStack {
                            Text(block.time)
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 44, alignment: .leading)

                            Text(block.task)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(block.duration)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 80, alignment: .trailing)

                            if let score = block.score {
                                Text(String(format: "%.1f", score))
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(theme.foreground)
                                    .frame(width: 40, alignment: .trailing)
                            } else {
                                Text("-")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(borderColor(for: block.task))
                                .frame(width: 3)
                        }
                    }
                }
            }
            .frame(height: 250)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Activity Log Card

struct ActivityLogCard: View {
    let data: [MockData.ActivityEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Activity")
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 0) {
                            Text(entry.time)
                                .font(.system(size: 10, design: .monospaced).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 60, alignment: .leading)

                            Text(entry.app)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 84, alignment: .leading)

                            Text(entry.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.mutedForeground)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(height: 250)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Projects Card

struct ProjectsCard: View {
    let data: [MockData.Project]
    @Environment(\.theme) private var theme

    private func projectColor(_ name: String) -> Color {
        switch name {
        case "purple": theme.chartPurple
        case "pink": theme.chartPink
        case "teal": theme.chartTeal
        default: theme.chartGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Projects")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(spacing: 12) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, project in
                    HStack(spacing: 12) {
                        Text("\(project.percent)%")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 32, alignment: .trailing)

                        Text(project.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.foreground)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Progress bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.secondary.opacity(0.8))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(projectColor(project.color))
                                .frame(width: CGFloat(project.percent) / 100.0 * 112, height: 6)
                        }
                        .frame(width: 112)

                        Text(project.time)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Scores Card

struct ScoresCard: View {
    let data: MockData.ScoreSet
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Scores")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            HStack {
                Spacer()
                scoreItem(label: "Focus", percent: data.focus.percent, time: data.focus.time,
                          color: theme.chartCyan, labelColor: theme.accent)
                Spacer()
                scoreItem(label: "Meetings", percent: data.meetings.percent, time: data.meetings.time,
                          color: theme.chartPurple, labelColor: theme.primary)
                Spacer()
                scoreItem(label: "Breaks", percent: data.breaks.percent, time: data.breaks.time,
                          color: theme.chartTeal, labelColor: theme.chartTeal)
                Spacer()
            }
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }

    private func scoreItem(label: String, percent: Int, time: String, color: Color, labelColor: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                CircularProgress(value: Double(percent), size: 52, strokeWidth: 4, color: color)
                Text("\(percent)%")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(labelColor)
            Text(time)
                .font(.system(size: 9))
                .foregroundStyle(theme.mutedForeground)
        }
    }
}

// MARK: - Time Breakdown Card

struct TimeBreakdownCard: View {
    let data: [MockData.TimeBreakdownEntry]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Time Breakdown")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Text("\(item.percent)%")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 28, alignment: .trailing)

                            Text(item.category)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 112, alignment: .leading)
                                .lineLimit(1)

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(theme.secondary.opacity(0.6))
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color(hex: item.colorHex))
                                        .frame(width: min(CGFloat(item.percent) * 2.2 / 100 * geo.size.width, geo.size.width))
                                }
                            }
                            .frame(height: 5)

                            Text(item.time)
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 64, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(height: 210)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}
#endif
