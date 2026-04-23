#if os(macOS)
import SwiftUI

// MARK: - Productivity Page

enum ProductivityTab: String, CaseIterable {
    case focus = "Focus"
    case breaks = "Breaks"
    case meetings = "Meetings"
    case goals = "Goals"
}

struct ProductivityPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = ProductivityViewModel()
    @State private var activeTab: ProductivityTab = .focus

    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.cardGap) {
                // Header: title + section tabs
                HStack(spacing: 12) {
                    Text("Productivity")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.foreground)

                    HStack(spacing: 2) {
                        ForEach(ProductivityTab.allCases, id: \.self) { tab in
                            Button { activeTab = tab } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(activeTab == tab ? theme.foreground : theme.mutedForeground)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(activeTab == tab ? theme.secondary : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // Period toggle
                    HStack(spacing: 2) {
                        ForEach(PeriodMode.allCases, id: \.self) { mode in
                            Button { viewModel.switchPeriodMode(mode) } label: {
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(viewModel.periodMode == mode ? theme.foreground : theme.mutedForeground)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(viewModel.periodMode == mode ? theme.secondary : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                DateNavigator(
                    dateText: viewModel.displayPeriod,
                    activeView: .constant("Day"),
                    isToday: viewModel.isCurrentPeriod,
                    isLoading: viewModel.isLoading,
                    onPrevious: { viewModel.goToPreviousPeriod() },
                    onNext: { viewModel.goToNextPeriod() },
                    onToday: { viewModel.goToCurrentPeriod() }
                )

                switch activeTab {
                case .focus:
                    focusContent
                case .breaks:
                    breaksContent
                case .meetings, .goals:
                    comingSoon(title: activeTab.rawValue)
                }
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private var focusContent: some View {
        FocusScoreRow(
            averageScore: viewModel.averageFocusScore,
            perDayScores: viewModel.focusScorePerDay,
            topInterruptors: viewModel.topInterruptors
        )

        BreakdownChartCard(data: viewModel.chartDays)

        HStack(alignment: .top, spacing: AppMetrics.cardGap) {
            WorkCategoriesCard(
                categories: viewModel.summaryData?.categoryBreakdown ?? [],
                formatDuration: viewModel.formatDuration
            )
            BreakdownDonutsCard(data: viewModel.donutData, formatDuration: viewModel.formatDuration)
            WorkHoursStatsCard(
                avgPerDay: viewModel.avgPerDayFormatted,
                avgPerWeek: viewModel.avgPerWeekFormatted
            )
        }
    }

    @ViewBuilder
    private var breaksContent: some View {
        BreaksListCard()
    }

    @ViewBuilder
    private func comingSoon(title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(theme.mutedForeground.opacity(0.6))
            Text("\(title) — coming soon")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .dashboardCard()
    }
}

// MARK: - Focus Score Row (M10)

struct FocusScoreRow: View {
    let averageScore: Int
    let perDayScores: [(label: String, score: Int)]
    let topInterruptors: [(name: String, count: Int)]

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: AppMetrics.cardGap) {
            averageCard
            perDayCard
            interruptorsCard
        }
    }

    private var averageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Avg Focus Score")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            Spacer(minLength: 0)
            ZStack {
                CircularProgress(value: Double(averageScore), size: 120, strokeWidth: 10,
                                 color: theme.chartPurple)
                VStack(spacing: 0) {
                    Text("\(averageScore)")
                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.foreground)
                    Text("score")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            Spacer(minLength: 0)
        }
        .frame(width: 220, height: 240)
        .dashboardCard()
    }

    private var perDayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Focus Score / Day")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if perDayScores.isEmpty {
                emptyState("No data")
            } else {
                GeometryReader { geo in
                    let maxScore: Double = 100
                    let barWidth = max(3, (geo.size.width - 32) / CGFloat(perDayScores.count) - 3)
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(perDayScores.enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.chartPurple)
                                    .frame(height: CGFloat(day.score) / maxScore * 160)
                                Text(day.label)
                                    .font(.system(size: 8).monospacedDigit())
                                    .foregroundStyle(theme.mutedForeground)
                            }
                            .frame(width: barWidth)
                            .help("\(day.score)%")
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 190)
            }
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }

    private var interruptorsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Top Interruptors")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            if topInterruptors.isEmpty {
                emptyState("No interruptions logged")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(topInterruptors.prefix(6).enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.name)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)×")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(width: 260, height: 240)
        .dashboardCard()
    }

    @ViewBuilder
    private func emptyState(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 11))
            .foregroundStyle(theme.mutedForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Breaks List Card (M15)

struct BreaksListCard: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var svc = BreakDetectionService.shared

    private var completedBreaks: [BreakRecord] {
        svc.breaks.filter { $0.classification == .breakSession }
    }
    private var awaySessions: [BreakRecord] {
        svc.breaks.filter { $0.classification == .away }
    }
    private var avgBreakSeconds: Int {
        guard !completedBreaks.isEmpty else { return 0 }
        return completedBreaks.map(\.durationSeconds).reduce(0, +) / completedBreaks.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.cardGap) {
            HStack(spacing: AppMetrics.cardGap) {
                statCard(title: "Breaks Taken", value: "\(completedBreaks.count)")
                statCard(title: "Avg Length", value: formatDuration(avgBreakSeconds))
                statCard(title: "Away Sessions", value: "\(awaySessions.count)")
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(text: "Today's Breaks")
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                if svc.breaks.isEmpty {
                    Text("No breaks recorded yet")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                } else {
                    VStack(spacing: 0) {
                        ForEach(svc.breaks) { b in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(b.classification == .breakSession ? theme.success : theme.warning)
                                    .frame(width: 6, height: 6)
                                Text(b.classification.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(theme.foreground)
                                    .frame(width: 60, alignment: .leading)
                                Text("\(formatTime(b.startedAt)) – \(formatTime(b.endedAt))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.mutedForeground)
                                Spacer()
                                Text(formatDuration(b.durationSeconds))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.foreground)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            Divider().opacity(0.2)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .dashboardCard()
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(theme.mutedForeground)
            Text(value)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dashboardCard()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m == 0 { return "\(s)s" }
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Breakdown Chart Card (Stacked Bars)

struct BreakdownChartCard: View {
    let data: [(date: String, productive: Double, communication: Double, other: Double)]
    @Environment(\.theme) private var theme

    private var maxValue: Double {
        data.map { $0.productive + $0.communication + $0.other }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Breakdown Chart")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if data.isEmpty {
                Text("No data for this period")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                GeometryReader { geo in
                    let barWidth = max(4, (geo.size.width - 32) / CGFloat(data.count) - 3)
                    let chartHeight: CGFloat = 240

                    VStack(spacing: 4) {
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(data.enumerated()), id: \.offset) { _, day in
                                let total = day.productive + day.communication + day.other
                                let scale = maxValue > 0 ? chartHeight / maxValue : 0

                                VStack(spacing: 0) {
                                    // Other (gray) — top
                                    if day.other > 0 {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(theme.chartGray)
                                            .frame(height: CGFloat(day.other) * scale)
                                    }
                                    // Communication (cyan)
                                    if day.communication > 0 {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(theme.chartCyan)
                                            .frame(height: CGFloat(day.communication) * scale)
                                    }
                                    // Productive (purple) — bottom
                                    if day.productive > 0 {
                                        RoundedRectangle(cornerRadius: total == day.productive ? 2 : 1)
                                            .fill(theme.chartPurple)
                                            .frame(height: CGFloat(day.productive) * scale)
                                    }
                                }
                                .frame(width: barWidth)
                                .help(String(format: "%.1fh", total))
                            }
                        }
                        .frame(height: chartHeight)
                        .padding(.horizontal, 16)

                        // X-axis labels (show every few days)
                        HStack(spacing: 3) {
                            let step = max(1, data.count / 7)
                            ForEach(Array(data.enumerated()), id: \.offset) { i, day in
                                if i % step == 0 {
                                    Text(day.date)
                                        .font(.system(size: 8).monospacedDigit())
                                        .foregroundStyle(theme.mutedForeground)
                                }
                                if i % step == 0 && i + step < data.count {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(height: 280)
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: theme.chartPurple, label: "Productive")
                legendItem(color: theme.chartCyan, label: "Communication")
                legendItem(color: theme.chartGray, label: "Other")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.mutedForeground)
        }
    }
}

// MARK: - Work Categories Card

struct WorkCategoriesCard: View {
    let categories: [CategoryBreakdownResponse]
    let formatDuration: (Int) -> String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Work Categories")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(categories.enumerated()), id: \.offset) { _, cat in
                        HStack(spacing: 8) {
                            Text("\(cat.percent)%")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 28, alignment: .trailing)

                            Text(cat.category)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 100, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.secondary.opacity(0.5))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(CategoryColors.color(for: cat.category))
                                        .opacity(0.45 + Double(cat.percent) / 50.0)
                                        .frame(width: min(CGFloat(cat.percent) * 3.5 / 100 * geo.size.width, geo.size.width))
                                }
                            }
                            .frame(height: 4)

                            Text(formatDuration(cat.totalSeconds))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 76, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(height: 320)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Breakdown Donuts Card

struct BreakdownDonutsCard: View {
    let data: [(label: String, percent: Int, seconds: Int, color: String)]
    let formatDuration: (Int) -> String
    @Environment(\.theme) private var theme

    private func ringColor(_ colorName: String) -> Color {
        switch colorName {
        case "purple": theme.chartPurple
        case "cyan": theme.chartCyan
        case "gray": theme.chartGray
        default: theme.chartGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Breakdown")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(spacing: 16) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 12) {
                        ZStack {
                            CircularProgress(
                                value: Double(item.percent),
                                size: 48,
                                strokeWidth: 4.5,
                                color: ringColor(item.color)
                            )
                            Text("\(item.percent)%")
                                .font(.system(size: 8, weight: .bold).monospacedDigit())
                                .foregroundStyle(theme.foreground)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            HStack(spacing: 4) {
                                Text("\(item.percent)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(theme.foreground)
                                Text(formatDuration(item.seconds))
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.mutedForeground)
                            }
                        }

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}

// MARK: - Work Hours Stats Card

struct WorkHoursStatsCard: View {
    let avgPerDay: String
    let avgPerWeek: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Work Hours")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg. Work Hours per week")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedForeground)
                    Text(avgPerWeek)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg. time worked per day")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedForeground)
                    Text(avgPerDay)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .dashboardCard()
    }
}
#endif
