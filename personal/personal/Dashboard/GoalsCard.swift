#if os(macOS)
import SwiftUI

struct GoalsCard: View {
    let categories: [CategoryResponse]
    let breakdown: [CategoryBreakdownResponse]
    @Environment(\.theme) private var theme

    private var goalRows: [(CategoryResponse, Int)] {
        let progressMap = Dictionary(uniqueKeysWithValues:
            breakdown.map { ($0.category, $0.totalSeconds) })
        return categories
            .filter(\.hasGoal)
            .map { ($0, progressMap[$0.name] ?? 0) }
            .sorted { $0.0.name < $1.0.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Goals")
                .padding(.horizontal, Spacing.space7).padding(.top, Spacing.space6).padding(.bottom, Spacing.space4)

            if goalRows.isEmpty {
                Text("No category goals set yet. Add goals in Settings → Categories.")
                    .font(AppFont.text(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                HStack(alignment: .top, spacing: Spacing.space8) {
                    ForEach(goalRows, id: \.0.id) { (cat, current) in
                        GoalRing(category: cat, currentSeconds: current)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.space7)
                .padding(.bottom, Spacing.space6)
            }
        }
        .dashboardCard()
    }
}

private struct GoalRing: View {
    let category: CategoryResponse
    let currentSeconds: Int
    @Environment(\.theme) private var theme

    private var progress: Double {
        guard category.dailyGoalSeconds > 0 else { return 0 }
        return min(1.0, Double(currentSeconds) / Double(category.dailyGoalSeconds))
    }

    private var tint: Color {
        if category.goalIsMax {
            // Ceiling: green while under, red as it fills.
            return progress >= 1.0 ? theme.warning
                : progress >= 0.8 ? theme.accent
                : theme.success
        } else {
            // Floor: red until close, green when met.
            return progress >= 1.0 ? theme.success
                : progress >= 0.5 ? theme.accent
                : theme.mutedForeground
        }
    }

    private var statusText: String {
        let pct = Int(round(progress * 100))
        if category.goalIsMax {
            return progress >= 1.0 ? "Over limit" : "\(pct)% of cap"
        }
        return progress >= 1.0 ? "Goal met" : "\(pct)% of goal"
    }

    private func fmt(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var body: some View {
        VStack(spacing: Spacing.space2) {
            ZStack {
                Circle()
                    .stroke(theme.border.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(fmt(currentSeconds))
                        .font(AppFont.text(FontSize.sm, .bold).monospacedDigit())
                        .foregroundStyle(theme.foreground)
                    Text("/ \(fmt(category.dailyGoalSeconds))")
                        .font(AppFont.mono(FontSize.xs2))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
            .frame(width: 72, height: 72)

            HStack(spacing: Spacing.space1) {
                Circle().fill(CategoryColors.color(for: category.name)).frame(width: 6, height: 6)
                Text(category.name)
                    .font(AppFont.text(FontSize.sm, .medium))
                    .foregroundStyle(theme.foreground)
            }
            Text(statusText)
                .font(AppFont.text(FontSize.xs2))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
        }
        .frame(width: 100)
    }
}
#endif
