#if os(macOS)
import SwiftUI

struct InsightsPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var vm = InsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetrics.cardGap) {
                header
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.warning)
                }
                if vm.overview == nil && vm.isLoading {
                    HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                        .padding(.top, 60)
                } else if let o = vm.overview {
                    headlineRow(o)
                    HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                        HeatmapCard(cells: o.heatmap)
                        DayOfWeekCard(stats: o.dayOfWeek)
                    }
                    HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                        TrendCard(trend: o.dailyTrend)
                        StreakCard(stats: o.streaks, daysCount: o.daysWithData)
                    }
                    HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                        DistractionsCard(items: o.topDistractions, formatHours: vm.formatHours)
                        LongestFocusCard(items: o.longestFocusSessions, formatHours: vm.formatHours)
                    }
                    HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                        CategoryMixCard(
                            current: o.categoryBreakdown,
                            prior: o.categoryBreakdownPriorPeriod,
                            formatHours: vm.formatHours)
                    }
                    NarrativeCard(
                        narrative: vm.narrative,
                        isGenerating: vm.isGeneratingNarrative,
                        onGenerate: { Task { await vm.generateNarrative() } }
                    )
                }
            }
            .padding(AppMetrics.contentPadding)
        }
        .task { await vm.load() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Text("Insights")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.foreground)

            HStack(spacing: 2) {
                ForEach(InsightsRange.allCases) { r in
                    Button { vm.selectRange(r) } label: {
                        Text(r.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(vm.range == r ? theme.foreground : theme.mutedForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(vm.range == r ? theme.secondary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            if vm.isLoading {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }
            Text(vm.displayRangeLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.mutedForeground)
        }
    }

    @ViewBuilder
    private func headlineRow(_ o: InsightsOverviewResponse) -> some View {
        HStack(spacing: AppMetrics.cardGap) {
            HeadlineStat(title: "Productive", value: vm.totalProductiveLabel,
                         caption: "of \(vm.totalTrackedLabel) tracked")
            HeadlineStat(title: "Avg / Day", value: vm.avgProductivePerDay,
                         caption: "\(o.daysWithData) days with data")
            HeadlineStat(title: "Switches / Day", value: vm.avgSwitchesPerDay,
                         caption: "\(o.totalContextSwitches) total")
            if let best = vm.bestWeekday {
                HeadlineStat(title: "Best day", value: best.label,
                             caption: "\(best.hours) avg productive")
            }
            if let peak = vm.peakHourCell {
                HeadlineStat(title: "Peak hour", value: peak.label,
                             caption: peak.hours)
            }
        }
    }
}

// MARK: - Headline tile

private struct HeadlineStat: View {
    let title: String
    let value: String
    let caption: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(theme.mutedForeground)
            Text(value)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .dashboardCard()
    }
}

// MARK: - Heatmap

private struct HeatmapCard: View {
    let cells: [InsightsOverviewResponse.HeatmapCell]
    @Environment(\.theme) private var theme

    private var maxValue: Int { cells.map { $0.productiveSeconds }.max() ?? 0 }

    private var grid: [[InsightsOverviewResponse.HeatmapCell]] {
        var rows: [[InsightsOverviewResponse.HeatmapCell]] = Array(
            repeating: [], count: 7)
        for cell in cells {
            let row = cell.weekday - 1
            if row >= 0 && row < 7 {
                rows[row].append(cell)
            }
        }
        for i in 0..<7 { rows[i].sort { $0.hour < $1.hour } }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Productive Hours · Weekday × Hour")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if maxValue == 0 {
                Text("No productive sessions yet for this range.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        Color.clear.frame(width: 30, height: 8)
                        ForEach(0..<24, id: \.self) { h in
                            Text(h % 6 == 0 ? "\(h)" : "")
                                .font(.system(size: 8).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(0..<7, id: \.self) { row in
                        HStack(spacing: 2) {
                            Text(InsightsViewModel.weekdayLabel(row + 1))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 30, alignment: .leading)
                            ForEach(grid[row]) { cell in
                                cellRect(cell)
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        Text("less")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.mutedForeground)
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(theme.chartPurple.opacity(0.15 + Double(i) * 0.21))
                                .frame(width: 12, height: 8)
                        }
                        Text("more")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }

    @ViewBuilder
    private func cellRect(_ cell: InsightsOverviewResponse.HeatmapCell) -> some View {
        let intensity = maxValue > 0 ? Double(cell.productiveSeconds) / Double(maxValue) : 0
        let opacity = cell.productiveSeconds == 0 ? 0.06 : 0.18 + intensity * 0.82
        RoundedRectangle(cornerRadius: 2)
            .fill(theme.chartPurple.opacity(opacity))
            .frame(maxWidth: .infinity)
            .frame(height: 16)
            .help("\(InsightsViewModel.weekdayLabel(cell.weekday)) \(String(format: "%02d", cell.hour)):00 — \(cell.productiveSeconds / 60) min productive")
    }
}

// MARK: - Day of week

private struct DayOfWeekCard: View {
    let stats: [InsightsOverviewResponse.DayOfWeekStat]
    @Environment(\.theme) private var theme

    private var maxAvg: Int { stats.map { $0.avgProductiveSeconds }.max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Average by Weekday")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if maxAvg == 0 {
                Text("Not enough data yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(stats) { s in
                        HStack(spacing: 8) {
                            Text(InsightsViewModel.weekdayLabel(s.weekday))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 32, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.secondary.opacity(0.5))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.chartPurple)
                                        .frame(width: maxAvg > 0
                                               ? CGFloat(s.avgProductiveSeconds) / CGFloat(maxAvg) * geo.size.width
                                               : 0)
                                }
                            }
                            .frame(height: 8)
                            Text(formatHours(s.avgProductiveSeconds))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
        .frame(width: 320)
        .dashboardCard()
    }

    private func formatHours(_ secs: Int) -> String {
        if secs <= 0 { return "0" }
        let h = secs / 3600, m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Trend lines

private struct TrendCard: View {
    let trend: [InsightsOverviewResponse.DailyTrendPoint]
    @Environment(\.theme) private var theme

    private var maxProductive: Int {
        max(1, trend.map { $0.productiveSeconds }.max() ?? 1)
    }
    private var maxSwitches: Int {
        max(1, trend.map { $0.contextSwitches }.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Daily Trend")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if trend.isEmpty {
                Text("No data.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        legend("Productive hrs", color: theme.chartPurple)
                        legend("Context switches", color: theme.chartCyan)
                    }
                    GeometryReader { geo in
                        let barWidth = max(2, (geo.size.width - 32) / CGFloat(trend.count) - 2)
                        let chartH: CGFloat = 130
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(trend) { p in
                                VStack(spacing: 1) {
                                    ZStack(alignment: .bottom) {
                                        // Productive
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(theme.chartPurple)
                                            .frame(height: CGFloat(p.productiveSeconds) / CGFloat(maxProductive) * chartH)
                                        // Switches as a thin overlay line proxy on right
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(theme.chartCyan.opacity(0.65))
                                            .frame(width: 2, height: CGFloat(p.contextSwitches) / CGFloat(maxSwitches) * chartH)
                                            .offset(x: barWidth / 2 - 1)
                                    }
                                }
                                .frame(width: barWidth, height: chartH, alignment: .bottom)
                                .help("\(p.date): \(formatHours(p.productiveSeconds)) productive · \(p.contextSwitches) switches")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 140)
                }
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }

    @ViewBuilder
    private func legend(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 9)).foregroundStyle(theme.mutedForeground)
        }
        .padding(.leading, 16)
    }

    private func formatHours(_ secs: Int) -> String {
        if secs <= 0 { return "0" }
        let h = secs / 3600, m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Streaks

private struct StreakCard: View {
    let stats: InsightsOverviewResponse.StreakStats
    let daysCount: Int
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Productive Streak")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 14) {
                bigNumber(value: stats.currentStreak, label: "current")
                bigNumber(value: stats.longestStreak, label: "longest")
                Text("Day counts toward streak when you log \(stats.thresholdSeconds / 3600)+ productive hrs.")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.mutedForeground)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
        .frame(width: 220)
        .dashboardCard()
    }

    @ViewBuilder
    private func bigNumber(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(value)")
                .font(.system(size: 26, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.foreground)
            Text("day\(value == 1 ? "" : "s") \(label)")
                .font(.system(size: 11))
                .foregroundStyle(theme.mutedForeground)
        }
    }
}

// MARK: - Distractions

private struct DistractionsCard: View {
    let items: [InsightsOverviewResponse.DistractionEntry]
    let formatHours: (Int) -> String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Top Distractions · Last 7 days")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            if items.isEmpty {
                Text("Clean slate. No distractions logged.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(items) { d in
                        HStack(spacing: 8) {
                            Text(d.appName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            Text("· \(d.category)")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.mutedForeground)
                                .lineLimit(1)
                            Spacer()
                            Text("\(d.sessionCount)×")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                            Text(formatHours(d.totalSeconds))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }
}

// MARK: - Longest focus

private struct LongestFocusCard: View {
    let items: [InsightsOverviewResponse.LongestFocusEntry]
    let formatHours: (Int) -> String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Longest Focus Blocks")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            if items.isEmpty {
                Text("No deep-work blocks yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(items) { f in
                        HStack(spacing: 8) {
                            Text(f.date)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 80, alignment: .leading)
                            Text("\(f.startTime)–\(f.endTime)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 80, alignment: .leading)
                            Text(f.category)
                                .font(.system(size: 10))
                                .foregroundStyle(CategoryColors.color(for: f.category))
                                .lineLimit(1)
                            Spacer()
                            Text(formatHours(f.durationSeconds))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.foreground)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }
}

// MARK: - Category mix

private struct CategoryMixCard: View {
    let current: [CategoryBreakdownResponse]
    let prior: [CategoryBreakdownResponse]
    let formatHours: (Int) -> String
    @Environment(\.theme) private var theme

    private func priorPct(_ name: String) -> Int? {
        prior.first { $0.category == name }?.percent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Category Mix · vs Prior Period")
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            if current.isEmpty {
                Text("No data.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(current.prefix(8).enumerated()), id: \.offset) { _, cat in
                        let prior = priorPct(cat.category)
                        let delta = prior.map { cat.percent - $0 }
                        HStack(spacing: 8) {
                            Text("\(cat.percent)%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 36, alignment: .trailing)
                            Text(cat.category)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .frame(width: 110, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.secondary.opacity(0.5))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(CategoryColors.color(for: cat.category))
                                        .frame(width: CGFloat(cat.percent) / 100 * geo.size.width)
                                }
                            }
                            .frame(height: 6)
                            if let d = delta {
                                Text(d > 0 ? "+\(d)%" : "\(d)%")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(d > 0 ? theme.success : (d < 0 ? theme.warning : theme.mutedForeground))
                                    .frame(width: 40, alignment: .trailing)
                            } else {
                                Text("new")
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.mutedForeground)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            Text(formatHours(cat.totalSeconds))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }
}

// MARK: - AI Narrative

private struct NarrativeCard: View {
    let narrative: InsightsNarrativeResponse?
    let isGenerating: Bool
    let onGenerate: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle(text: "AI Narrative")
                Spacer()
                Button(action: onGenerate) {
                    HStack(spacing: 5) {
                        if isGenerating {
                            ProgressView().controlSize(.small).scaleEffect(0.6)
                        } else {
                            Image(systemName: "sparkles").font(.system(size: 10))
                        }
                        Text(narrative == nil ? "Generate" : "Regenerate")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(theme.primaryForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            if let n = narrative {
                VStack(alignment: .leading, spacing: 12) {
                    if !n.summary.isEmpty {
                        Text(n.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.foreground)
                            .lineSpacing(2)
                    }
                    if !n.patterns.isEmpty {
                        section(title: "Patterns", items: n.patterns, color: theme.chartPurple)
                    }
                    if !n.wins.isEmpty {
                        section(title: "Wins", items: n.wins, color: theme.success)
                    }
                    if !n.watchouts.isEmpty {
                        section(title: "Watchouts", items: n.watchouts, color: theme.warning)
                    }
                    Text("Generated \(n.generatedAt) · \(n.model)")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.mutedForeground)
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            } else {
                Text("Hit Generate for an AI-written recap of this period — patterns, wins, and watchouts grounded in your data.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            }
        }
        .dashboardCard()
    }

    @ViewBuilder
    private func section(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(color)
            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(color).frame(width: 4, height: 4).padding(.top, 6)
                    Text(line)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
#endif
