#if os(macOS)
import SwiftUI

// MARK: - Horizontal Timeline Card (single-row hour bar)

struct HorizontalTimelineCard: View {
    let blocks: [MockData.TimelineBlock]
    let dayStartHour: Int

    @Environment(\.theme) private var theme

    private var hourLabels: [Int] {
        // Every 2 hours from dayStartHour through +24, rendered as % 24
        stride(from: 0, through: 24, by: 2).map { (dayStartHour + $0) % 24 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Timeline")
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space6)
                .padding(.bottom, Spacing.space4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(theme.secondary.opacity(0.4))
                        .frame(height: 36)

                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        let shiftedStart = (block.start - Double(dayStartHour) + 24)
                            .truncatingRemainder(dividingBy: 24)
                        let left = shiftedStart / 24 * geo.size.width
                        let width = (block.end - block.start) / 24 * geo.size.width
                        RoundedRectangle(cornerRadius: Radius.progressBar)
                            .fill(theme.activityColor(for: block.type).opacity(0.85))
                            .frame(width: max(width, 2), height: 36)
                            .offset(x: left)
                            .help(block.label)
                    }
                }
            }
            .frame(height: 36)
            .padding(.horizontal, Spacing.space7)

            HStack(spacing: 0) {
                ForEach(Array(hourLabels.enumerated()), id: \.offset) { i, hour in
                    Text(hourLabelText(hour))
                        .font(AppFont.text(FontSize.xs2).monospacedDigit())
                        .foregroundStyle(theme.mutedForeground)
                    if i < hourLabels.count - 1 { Spacer() }
                }
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.top, Spacing.space2)
            .padding(.bottom, Spacing.space6)
        }
        .dashboardCard()
    }

    private func hourLabelText(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}

// MARK: - Pie Chart Card (category donut)

struct PieChartCard: View {
    let totalSeconds: Int
    let segments: [CategoryBreakdownResponse]
    let formatDuration: (Int) -> String

    @Environment(\.theme) private var theme

    private var totalText: String { formatDuration(totalSeconds) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Pie Chart")
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space6)
                .padding(.bottom, Spacing.space4)

            Spacer(minLength: 0)

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { i, seg in
                    let startAngle = segments.prefix(i).reduce(0.0) { $0 + Double($1.percent) } * 3.6
                    let endAngle = startAngle + Double(seg.percent) * 3.6
                    Circle()
                        .trim(from: CGFloat(startAngle / 360), to: CGFloat(endAngle / 360))
                        .stroke(
                            CategoryColors.color(for: seg.category),
                            style: StrokeStyle(lineWidth: 18, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }
                Text(totalText)
                    .font(AppFont.text(FontSize.md, .bold).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }
            .frame(width: 140, height: 140)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.space7)

            Spacer(minLength: 0)
        }
        .frame(height: 260)
        .dashboardCard()
    }
}

// MARK: - Categories List Card

struct CategoriesListCard: View {
    let categories: [CategoryBreakdownResponse]
    let formatDuration: (Int) -> String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Categories")
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space6)
                .padding(.bottom, Spacing.space4)

            VStack(spacing: Spacing.space2) {
                ForEach(Array(categories.enumerated()), id: \.offset) { _, cat in
                    HStack(spacing: Spacing.space3) {
                        Text("\(cat.percent)%")
                            .font(AppFont.text(FontSize.sm).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 32, alignment: .trailing)
                        RoundedRectangle(cornerRadius: Radius.progressBar)
                            .fill(CategoryColors.color(for: cat.category).opacity(0.8))
                            .frame(width: 44, height: 6)
                        Text(cat.category)
                            .font(AppFont.text(FontSize.sm))
                            .foregroundStyle(theme.foreground)
                        Spacer()
                        Text(formatDuration(cat.totalSeconds))
                            .font(AppFont.text(FontSize.sm).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
                if categories.isEmpty {
                    Text("No categories yet")
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.bottom, Spacing.space6)
        }
        .frame(minHeight: 260, alignment: .top)
        .dashboardCard()
    }
}

// MARK: - Websites / Domains Card (M9.5)

struct WebsitesCard: View {
    let categoryDetails: [CategoryDetail]
    let total: Int
    let formatDuration: (Int) -> String

    @Environment(\.theme) private var theme

    /// Flatten every "domain" source across all categories into one ranked list.
    private var rows: [(domain: String, category: String, seconds: Int)] {
        categoryDetails
            .flatMap { cat in
                cat.sources
                    .filter { $0.type == "domain" }
                    .map { (domain: $0.name, category: cat.category, seconds: $0.seconds) }
            }
            .sorted { $0.seconds > $1.seconds }
    }

    private func pct(_ s: Int) -> Int {
        total > 0 ? Int(round(Double(s) * 100 / Double(total))) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Websites")
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space6)
                .padding(.bottom, Spacing.space4)

            let list = rows
            if list.isEmpty {
                Text("No browser activity yet")
                    .font(AppFont.text(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: Spacing.space2) {
                    ForEach(Array(list.prefix(10).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: Spacing.space3) {
                            Text("\(pct(row.seconds))%")
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 32, alignment: .trailing)
                            Circle()
                                .fill(CategoryColors.color(for: row.category))
                                .frame(width: 6, height: 6)
                            Text(row.domain)
                                .font(AppFont.mono(FontSize.sm))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(formatDuration(row.seconds))
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, Spacing.space7)
                .padding(.bottom, Spacing.space6)
            }
        }
        .frame(minHeight: 260, alignment: .top)
        .dashboardCard()
    }
}

// MARK: - Today's Sessions Strip (M9.5)

struct TodaySessionsStrip: View {
    let sessions: [FocusSessionResponse]
    let formatDuration: (Int) -> String
    var reviewsByKey: [String: SessionReviewResponse] = [:]
    var dateString: String = ""

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Today's Sessions")
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space6)
                .padding(.bottom, Spacing.space4)

            if sessions.isEmpty {
                Text("No focus sessions yet")
                    .font(AppFont.text(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Spacing.space4) {
                        ForEach(sessions) { session in
                            let key = ReviewKey.make(
                                date: dateString,
                                startTime: session.startTime,
                                endTime: session.endTime,
                                category: session.name)
                            let review = reviewsByKey[key]
                            SessionMiniCard(
                                session: session,
                                formatDuration: formatDuration,
                                label: bestLabel(
                                    title: review?.title,
                                    aiTitle: review?.aiTitle,
                                    category: session.name)
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.space7)
                }
            }
        }
        .padding(.bottom, Spacing.space6)
        .dashboardCard()
    }
}

private struct SessionMiniCard: View {
    let session: FocusSessionResponse
    let formatDuration: (Int) -> String
    var label: String = ""

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            HStack(spacing: Spacing.space2) {
                Circle()
                    .fill(CategoryColors.color(for: session.name))
                    .frame(width: 8, height: 8)
                Text(label.isEmpty ? session.name : label)
                    .font(AppFont.text(FontSize.sm, .semibold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(2)
            }
            Text("\(session.startTime) – \(session.endTime)")
                .font(AppFont.mono(FontSize.xs))
                .foregroundStyle(theme.mutedForeground)
            Text(formatDuration(session.durationSeconds))
                .font(AppFont.text(FontSize.md, .bold).monospacedDigit())
                .foregroundStyle(theme.foreground)

            Divider().opacity(0.25)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(session.apps.prefix(3)) { app in
                    HStack(spacing: Spacing.space1) {
                        Text(app.appName)
                            .font(AppFont.text(FontSize.xs))
                            .foregroundStyle(theme.mutedForeground)
                            .lineLimit(1)
                        Spacer()
                        Text("\(app.percent)%")
                            .font(AppFont.mono(FontSize.xs))
                            .foregroundStyle(theme.mutedForeground.opacity(0.8))
                    }
                }
            }
        }
        .padding(Spacing.space4)
        .frame(width: 200, alignment: .topLeading)
        .background(theme.secondary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(theme.border.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Apps & Websites Card

struct AppsWebsitesCard: View {
    let entries: [AppTimeEntry]
    let total: Int
    let formatDuration: (Int) -> String

    @Environment(\.theme) private var theme

    private func pct(_ s: Int) -> Int {
        total > 0 ? Int(round(Double(s) * 100 / Double(total))) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "Apps & Websites")
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space6)
                .padding(.bottom, Spacing.space4)

            VStack(spacing: Spacing.space2) {
                ForEach(entries.prefix(8), id: \.appName) { e in
                    HStack(spacing: Spacing.space3) {
                        Text("\(pct(e.totalSeconds))%")
                            .font(AppFont.text(FontSize.sm).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 32, alignment: .trailing)
                        RoundedRectangle(cornerRadius: Radius.progressBar)
                            .fill(theme.chartPurple.opacity(0.6))
                            .frame(width: 44, height: 6)
                        Text(e.appName)
                            .font(AppFont.text(FontSize.sm))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(1)
                        Spacer()
                        Text(formatDuration(e.totalSeconds))
                            .font(AppFont.text(FontSize.sm).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
                if entries.isEmpty {
                    Text("No apps tracked yet")
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.bottom, Spacing.space6)
        }
        .frame(minHeight: 260, alignment: .top)
        .dashboardCard()
    }
}
#endif
