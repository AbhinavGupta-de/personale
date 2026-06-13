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
                    dateText: viewModel.displayPeriod,
                    activeView: Binding(
                        get: { viewModel.viewMode.rawValue },
                        set: { viewModel.switchViewMode(ActivityViewModel.ViewMode(rawValue: $0) ?? .day) }
                    ),
                    isToday: viewModel.isCurrentPeriod,
                    isLoading: viewModel.isLoading,
                    onPrevious: { viewModel.goToPrevious() },
                    onNext: { viewModel.goToNext() },
                    onToday: { viewModel.goToCurrent() }
                )

                if viewModel.viewMode == .day && viewModel.displaySessions.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                        if viewModel.viewMode == .day {
                            DayTimelineCard(
                                sessions: viewModel.displaySessions,
                                dayStartHour: viewModel.dayStartHour,
                                categoryColor: viewModel.categoryColor,
                                parseTime: viewModel.parseTimeToHour,
                                formatDuration: viewModel.formatDuration,
                                labelFor: { viewModel.label(for: $0) },
                                dateString: viewModel.dateString,
                                reviewsByKey: viewModel.reviewsByKey,
                                availableCategories: viewModel.availableCategoryNames,
                                selectedSession: $viewModel.selectedSession
                            )
                            .frame(maxWidth: .infinity)

                            DailySummaryCard(viewModel: viewModel)
                                .frame(width: 360)
                        } else {
                            WeekTimelineCard(
                                weekDates: viewModel.weekDates,
                                sessionsForDate: { date in viewModel.weekDisplaySessions(for: date) },
                                dayStartHour: viewModel.dayStartHour,
                                categoryColor: viewModel.categoryColor,
                                parseTime: viewModel.parseTimeToHour,
                                formatDuration: viewModel.formatDuration,
                                selectedSession: $viewModel.selectedSession
                            )
                            .frame(maxWidth: .infinity)

                            WeeklySummaryCard(viewModel: viewModel)
                                .frame(width: 360)
                        }
                    }
                }
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.space5) {
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

// MARK: - Hour Ruler

struct HourRuler: View {
    let dayStartHour: Int
    let hourHeight: CGFloat

    @Environment(\.theme) private var theme

    var body: some View {
        // 25 labels at positions 0..24 * hourHeight so the ruler closes at the
        // same dayStartHour (6 AM → 6 AM) instead of stopping at 5 AM.
        ZStack(alignment: .topLeading) {
            Color.clear.frame(height: 24 * hourHeight)

            ForEach(0...24, id: \.self) { i in
                let hour = (dayStartHour + i) % 24
                HStack(spacing: 0) {
                    Text(formatHourLabel(hour))
                        .font(AppFont.mono(FontSize.xs2))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 52, alignment: .trailing)
                    Rectangle()
                        .fill(theme.border.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
                .offset(y: CGFloat(i) * hourHeight)
            }
        }
    }

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12:00 AM" }
        if hour < 12 { return "\(hour):00 AM" }
        if hour == 12 { return "12:00 PM" }
        return "\(hour - 12):00 PM"
    }
}

// MARK: - Day Timeline Column (wired to sessions)

struct DayTimelineColumn: View {
    let sessions: [FocusSessionResponse]
    let dayStartHour: Int
    let hourHeight: CGFloat
    let parseTime: (String) -> Double?
    let categoryColor: (String) -> Color
    let formatDuration: (Int) -> String
    var labelFor: (FocusSessionResponse) -> String = { $0.name }
    var dateString: String = ""
    var reviewsByKey: [String: SessionReviewResponse] = [:]
    var availableCategories: [String] = []
    @Binding var selectedSession: FocusSessionResponse?

    @Environment(\.theme) private var theme

    private func yOffset(_ hour: Double) -> CGFloat {
        let shifted = (hour - Double(dayStartHour) + 24).truncatingRemainder(dividingBy: 24)
        return CGFloat(shifted) * hourHeight
    }

    /// User-overridden review category wins over the auto-detected one.
    private func effectiveCategory(for session: FocusSessionResponse) -> String {
        let key = ReviewKey.make(
            date: dateString,
            startTime: session.startTime,
            endTime: session.endTime,
            category: session.name)
        return reviewsByKey[key]?.category ?? session.name
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.clear).frame(height: 24 * hourHeight)

            ForEach(sessions) { session in
                if let start = parseTime(session.startTime) {
                    // Use authoritative durationSeconds rather than end-start so blocks
                    // crossing midnight (e.g. 20:41 → 00:26) render at their true height.
                    let top = yOffset(start)
                    let hours = Double(session.durationSeconds) / 3600.0
                    let height = CGFloat(hours) * hourHeight
                    sessionBlock(session: session, height: max(height, 3))
                        .offset(y: top)
                        .padding(.horizontal, Spacing.space1)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionBlock(session: FocusSessionResponse, height: CGFloat) -> some View {
        let color = categoryColor(effectiveCategory(for: session))
        let isSelected = selectedSession?.id == session.id
        Button {
            selectedSession = isSelected ? nil : session
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: height > 6 ? 6 : 2)
                    .fill(color.opacity(isSelected ? 0.85 : 0.6))
                if height >= 28 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(labelFor(session))
                            .font(AppFont.text(FontSize.sm, .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        if height >= 40 {
                            Text("\(session.startTime) - \(session.endTime)")
                                .font(AppFont.text(FontSize.xs2))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, Spacing.space4)
                    .padding(.vertical, Spacing.space1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: height > 6 ? 6 : 2))
        }
        .buttonStyle(.plain)
        .help("\(session.name) \(session.startTime)-\(session.endTime) (\(session.duration))")
        .popover(isPresented: Binding(
            get: { isSelected },
            set: { if !$0 { selectedSession = nil } }
        ), arrowEdge: .leading) {
            let key = ReviewKey.make(
                date: dateString,
                startTime: session.startTime,
                endTime: session.endTime,
                category: session.name)
            InlineReviewPopover(
                session: session,
                dateString: dateString,
                availableCategories: availableCategories,
                initialReview: reviewsByKey[key],
                formatDuration: formatDuration,
                onDismiss: {
                    // Defer past the current view update to avoid the
                    // "Publishing changes from within view updates" warning
                    // that SwiftUI emits when a popover's dismiss triggers
                    // a @Published binding write during the same frame.
                    DispatchQueue.main.async { selectedSession = nil }
                }
            )
        }
    }
}

// MARK: - Sessions Strip Column (compact colored blocks)

struct SessionsStripColumn: View {
    let sessions: [FocusSessionResponse]
    let dayStartHour: Int
    let hourHeight: CGFloat
    let parseTime: (String) -> Double?
    let categoryColor: (String) -> Color
    let formatDuration: (Int) -> String
    var dateString: String = ""
    var reviewsByKey: [String: SessionReviewResponse] = [:]
    var availableCategories: [String] = []
    @Binding var selectedSession: FocusSessionResponse?

    @Environment(\.theme) private var theme

    private func yOffset(_ hour: Double) -> CGFloat {
        let shifted = (hour - Double(dayStartHour) + 24).truncatingRemainder(dividingBy: 24)
        return CGFloat(shifted) * hourHeight
    }

    private func effectiveCategory(for session: FocusSessionResponse) -> String {
        let key = ReviewKey.make(
            date: dateString,
            startTime: session.startTime,
            endTime: session.endTime,
            category: session.name)
        return reviewsByKey[key]?.category ?? session.name
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.clear).frame(height: 24 * hourHeight)
            ForEach(sessions) { session in
                if let start = parseTime(session.startTime) {
                    let top = yOffset(start)
                    let hours = Double(session.durationSeconds) / 3600.0
                    let height = CGFloat(hours) * hourHeight
                    stripBlock(session: session, height: max(height, 2))
                        .offset(y: top)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func stripBlock(session: FocusSessionResponse, height: CGFloat) -> some View {
        let isSelected = selectedSession?.id == session.id
        Button {
            selectedSession = isSelected ? nil : session
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(categoryColor(effectiveCategory(for: session)).opacity(isSelected ? 1.0 : 0.85))
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(.plain)
        .help("\(session.name) \(session.startTime)-\(session.endTime) (\(session.duration))")
        .popover(isPresented: Binding(
            get: { isSelected },
            set: { if !$0 { selectedSession = nil } }
        ), arrowEdge: .trailing) {
            let key = ReviewKey.make(
                date: dateString,
                startTime: session.startTime,
                endTime: session.endTime,
                category: session.name)
            InlineReviewPopover(
                session: session,
                dateString: dateString,
                availableCategories: availableCategories,
                initialReview: reviewsByKey[key],
                formatDuration: formatDuration,
                onDismiss: {
                    // Defer past the current view update to avoid the
                    // "Publishing changes from within view updates" warning
                    // that SwiftUI emits when a popover's dismiss triggers
                    // a @Published binding write during the same frame.
                    DispatchQueue.main.async { selectedSession = nil }
                }
            )
        }
    }
}

// MARK: - Placeholder Column (Tasks / Calendar)

struct PlaceholderColumn: View {
    let title: String
    let icon: String
    let hourHeight: CGFloat

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear).frame(height: 24 * hourHeight)
            VStack(spacing: Spacing.space2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
                Text("No \(title.lowercased()) tracked")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground.opacity(0.6))
                Text("Coming soon")
                    .font(AppFont.text(FontSize.xs2))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
            }
        }
    }
}

// MARK: - Day Timeline Card (3-column day view)

struct DayTimelineCard: View {
    let sessions: [FocusSessionResponse]
    let dayStartHour: Int
    let categoryColor: (String) -> Color
    let parseTime: (String) -> Double?
    let formatDuration: (Int) -> String
    var labelFor: (FocusSessionResponse) -> String = { $0.name }
    var dateString: String = ""
    var reviewsByKey: [String: SessionReviewResponse] = [:]
    var availableCategories: [String] = []
    @Binding var selectedSession: FocusSessionResponse?

    @Environment(\.theme) private var theme
    private let hourHeight: CGFloat = 44
    private let cardHeight: CGFloat = 620

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 60)
                Color.clear.frame(width: 24)  // sessions strip
                columnHeader(text: "Time Entries", icon: "list.bullet")
                columnHeader(text: "Tasks", icon: "checkmark.square")
                columnHeader(text: "Calendar", icon: "calendar")
            }
            .padding(.horizontal, Spacing.space3)
            .padding(.top, Spacing.space5)
            .padding(.bottom, Spacing.space1)

            Divider().opacity(0.3)

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    HourRuler(dayStartHour: dayStartHour, hourHeight: hourHeight)
                        .frame(width: 60)
                    SessionsStripColumn(
                        sessions: sessions,
                        dayStartHour: dayStartHour,
                        hourHeight: hourHeight,
                        parseTime: parseTime,
                        categoryColor: categoryColor,
                        formatDuration: formatDuration,
                        dateString: dateString,
                        reviewsByKey: reviewsByKey,
                        availableCategories: availableCategories,
                        selectedSession: $selectedSession
                    )
                    .frame(width: 24)
                    DayTimelineColumn(
                        sessions: sessions,
                        dayStartHour: dayStartHour,
                        hourHeight: hourHeight,
                        parseTime: parseTime,
                        categoryColor: categoryColor,
                        formatDuration: formatDuration,
                        labelFor: labelFor,
                        dateString: dateString,
                        reviewsByKey: reviewsByKey,
                        availableCategories: availableCategories,
                        selectedSession: $selectedSession
                    )
                    .frame(maxWidth: .infinity)
                    PlaceholderColumn(title: "Tasks", icon: "checkmark.square", hourHeight: hourHeight)
                        .frame(maxWidth: .infinity)
                    PlaceholderColumn(title: "Calendar", icon: "calendar", hourHeight: hourHeight)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Spacing.space3)
            }
            .scrollIndicators(.hidden)
            .frame(height: cardHeight)
        }
        .dashboardCard()
    }

    @ViewBuilder
    private func columnHeader(text: String, icon: String) -> some View {
        HStack(spacing: Spacing.space2) {
            Image(systemName: icon)
                .font(AppFont.text(FontSize.xs))
                .foregroundStyle(theme.mutedForeground)
            Text(text)
                .font(AppFont.text(FontSize.sm, .semibold))
                .foregroundStyle(theme.foreground)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.space3)
    }
}

// MARK: - Week Timeline Card (7-day grid)

struct WeekTimelineCard: View {
    let weekDates: [Date]
    let sessionsForDate: (Date) -> [FocusSessionResponse]
    let dayStartHour: Int
    let categoryColor: (String) -> Color
    let parseTime: (String) -> Double?
    let formatDuration: (Int) -> String
    @Binding var selectedSession: FocusSessionResponse?

    @Environment(\.theme) private var theme
    private let hourHeight: CGFloat = 44
    private let cardHeight: CGFloat = 620

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 58)
                        HourRuler(dayStartHour: dayStartHour, hourHeight: hourHeight)
                    }
                    .frame(width: 60)

                    ForEach(weekDates, id: \.self) { date in
                        WeekActivityColumn(
                            date: date,
                            sessions: sessionsForDate(date),
                            dayStartHour: dayStartHour,
                            hourHeight: hourHeight,
                            parseTime: parseTime,
                            categoryColor: categoryColor,
                            formatDuration: formatDuration,
                            selectedSession: $selectedSession
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Spacing.space3)
                .padding(.vertical, Spacing.space5)
            }
            .scrollIndicators(.hidden)
            .frame(height: cardHeight)
        }
        .dashboardCard()
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    @ObservedObject var viewModel: ActivityViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Weekly Summary")
                .font(AppFont.text(FontSize.lg, .bold))
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, Spacing.space7)
                .padding(.top, Spacing.space7)
                .padding(.bottom, Spacing.space5)

            Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

            VStack(alignment: .leading, spacing: Spacing.space1) {
                Text("Weekly hours logged")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
                Text(viewModel.weekTotalFocusDuration)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.foreground)
                Text("\(viewModel.weekEntryCount) entries")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.vertical, Spacing.space4)

            Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

            VStack(alignment: .leading, spacing: Spacing.space3) {
                Text("Categories")
                    .font(AppFont.text(FontSize.xs2, .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.mutedForeground)

                ForEach(Array(viewModel.weekCategoryBreakdown.enumerated()), id: \.offset) { _, cat in
                    HStack(spacing: Spacing.space3) {
                        Text("\(cat.percent)%")
                            .font(AppFont.text(FontSize.sm).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                            .frame(width: 28, alignment: .trailing)
                        RoundedRectangle(cornerRadius: Radius.progressBar)
                            .fill(CategoryColors.color(for: cat.category))
                            .frame(width: 10, height: 10)
                        Text(cat.category)
                            .font(AppFont.text(FontSize.sm))
                            .foregroundStyle(theme.foreground)
                        Spacer()
                        Text(viewModel.formatDuration(cat.totalSeconds))
                            .font(AppFont.text(FontSize.sm).monospacedDigit())
                            .foregroundStyle(theme.mutedForeground)
                    }
                }
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.top, Spacing.space4)
            .padding(.bottom, Spacing.space6)
        }
        .dashboardCard()
    }
}

// MARK: - Session Popover Card (appears on click next to session block)

struct SessionPopoverCard: View {
    let session: FocusSessionResponse
    let formatDuration: (Int) -> String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            HStack(alignment: .top) {
                Text(session.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text(session.duration)
                    .font(AppFont.text(FontSize.md, .semibold).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }

            if !session.categories.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Categories")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                    ForEach(Array(session.categories.prefix(5).enumerated()), id: \.offset) { _, cat in
                        rowLine(
                            percent: cat.percent,
                            color: CategoryColors.color(for: cat.category),
                            label: cat.category,
                            value: formatDuration(cat.totalSeconds)
                        )
                    }
                }
            }

            if !session.apps.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Apps & Websites")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                    ForEach(session.apps.prefix(6)) { app in
                        rowLine(
                            percent: app.percent,
                            color: CategoryColors.color(for: app.category),
                            label: app.appName,
                            value: formatDuration(app.totalSeconds)
                        )
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(theme.card)
    }

    @ViewBuilder
    private func rowLine(percent: Int, color: Color, label: String, value: String) -> some View {
        HStack(spacing: Spacing.space4) {
            Text("\(percent)%")
                .font(AppFont.text(FontSize.sm).monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 30, alignment: .trailing)
            RoundedRectangle(cornerRadius: Radius.progressBar)
                .fill(color.opacity(0.7))
                .frame(width: 40, height: 6)
            Text(label)
                .font(AppFont.text(FontSize.sm))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(AppFont.text(FontSize.sm).monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
        }
    }
}

// MARK: - Session Summary Card (replaces DailySummary when a session is selected)

struct SessionSummaryCard: View {
    let session: FocusSessionResponse
    @ObservedObject var viewModel: ActivityViewModel
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    private var qualityScore: Int { viewModel.qualityScore(for: session) }
    private var rating: Int { viewModel.rating(for: session) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header with close ──
            HStack {
                Image(systemName: "timer")
                    .font(AppFont.text(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
                Text("Session Summary")
                    .font(AppFont.text(FontSize.md, .semibold))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 24, height: 24)
                        .background(theme.secondary.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.top, Spacing.space6)
            .padding(.bottom, Spacing.space5)

            Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

            // ── Title + total duration ──
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.foreground)
                    Text("\(session.startTime) – \(session.endTime)")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                }
                Spacer()
                Text(session.duration)
                    .font(AppFont.text(FontSize.lg, .bold).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.vertical, Spacing.space5)

            // ── Quality Score donut + stats ──
            HStack(alignment: .center, spacing: Spacing.space7) {
                ZStack {
                    Circle()
                        .stroke(theme.secondary.opacity(0.4), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(qualityScore) / 100)
                        .stroke(theme.chartCyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(qualityScore)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: Spacing.space2) {
                    summaryRow(label: "Quality Score", value: "\(qualityScore).0")
                    summaryRow(label: "Focus Time", value: session.duration)
                    summaryRow(label: "Focus Time (%)", value: "100%")
                    summaryRow(label: "Interruptions", value: "\(max(0, session.categories.count - 1))")
                }
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.bottom, Spacing.space5)

            Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

            // ── Categories ──
            if !session.categories.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Categories")
                        .font(AppFont.text(FontSize.xs2, .semibold))
                        .tracking(0.5)
                        .foregroundStyle(theme.mutedForeground)

                    ForEach(Array(session.categories.enumerated()), id: \.offset) { _, cat in
                        HStack(spacing: Spacing.space3) {
                            Text("\(cat.percent)%")
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 28, alignment: .trailing)
                            RoundedRectangle(cornerRadius: Radius.progressBar)
                                .fill(CategoryColors.color(for: cat.category))
                                .frame(width: 10, height: 10)
                            Text(cat.category)
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.foreground)
                            Spacer()
                            Text(viewModel.formatDuration(cat.totalSeconds))
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, Spacing.space7)
                .padding(.vertical, Spacing.space4)

                Divider().opacity(0.3).padding(.horizontal, Spacing.space7)
            }

            // ── Top Apps ──
            if !session.apps.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Top Apps")
                        .font(AppFont.text(FontSize.xs2, .semibold))
                        .tracking(0.5)
                        .foregroundStyle(theme.mutedForeground)

                    ForEach(session.apps.prefix(5)) { app in
                        HStack(spacing: Spacing.space3) {
                            Text("\(app.percent)%")
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                                .frame(width: 28, alignment: .trailing)
                            Text(app.appName)
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            Spacer()
                            Text(viewModel.formatDuration(app.totalSeconds))
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, Spacing.space7)
                .padding(.vertical, Spacing.space4)

                Divider().opacity(0.3).padding(.horizontal, Spacing.space7)
            }

            // ── Top Domains (Interrupters proxy) ──
            if let domains = session.topDomains, !domains.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("Top Sites")
                        .font(AppFont.text(FontSize.xs2, .semibold))
                        .tracking(0.5)
                        .foregroundStyle(theme.mutedForeground)

                    ForEach(domains.prefix(5)) { d in
                        HStack(spacing: Spacing.space3) {
                            Image(systemName: "globe")
                                .font(AppFont.text(FontSize.xs2))
                                .foregroundStyle(theme.mutedForeground.opacity(0.6))
                            Text(d.domain)
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            Spacer()
                            Text(viewModel.formatDuration(d.seconds))
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, Spacing.space7)
                .padding(.vertical, Spacing.space4)

                Divider().opacity(0.3).padding(.horizontal, Spacing.space7)
            }

            // ── Rating ──
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text("Rating")
                    .font(AppFont.text(FontSize.xs2, .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.mutedForeground)
                HStack(spacing: Spacing.space1) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            viewModel.setRating(star == rating ? 0 : star, for: session)
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundStyle(star <= rating ? theme.chartCyan : theme.mutedForeground.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.space7)
            .padding(.top, Spacing.space4)
            .padding(.bottom, Spacing.space6)
        }
        .dashboardCard()
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.text(FontSize.sm))
                .foregroundStyle(theme.foreground)
            Spacer()
            Text(value)
                .font(AppFont.text(FontSize.sm, .medium).monospacedDigit())
                .foregroundStyle(theme.foreground)
        }
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
                VStack(alignment: .leading, spacing: Spacing.space1) {
                    Text(session.name)
                        .font(AppFont.text(FontSize.xl, .bold))
                        .foregroundStyle(theme.foreground)
                    Text("\(session.startTime) – \(session.endTime)")
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.mutedForeground)
                }
                Spacer()
                Text(session.duration)
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }
            .padding(Spacing.space7)

            Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

            // ── Category donut + stats ──
            HStack(spacing: Spacing.space8) {
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
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    ForEach(Array(session.categories.enumerated()), id: \.offset) { _, cat in
                        HStack(spacing: Spacing.space2) {
                            RoundedRectangle(cornerRadius: Radius.progressBar)
                                .fill(categoryColor(cat.category))
                                .frame(width: 8, height: 8)
                            Text(cat.category)
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.foreground)
                            Spacer()
                            Text("\(cat.percent)%")
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                            Text(formatDuration(cat.totalSeconds))
                                .font(AppFont.text(FontSize.xs).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground.opacity(0.7))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(Spacing.space7)

            Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

            // ── Top Apps ──
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text("TOP APPS")
                    .font(AppFont.text(FontSize.xs2, .semibold))
                    .tracking(0.8)
                    .foregroundStyle(theme.mutedForeground)

                ForEach(session.apps.prefix(6)) { app in
                    sessionAppRow(app: app)
                }
                if session.apps.count > 6 {
                    Text("+\(session.apps.count - 6) more")
                        .font(AppFont.text(FontSize.xs2))
                        .foregroundStyle(theme.mutedForeground.opacity(0.6))
                        .padding(.leading, 40)
                }
            }
            .padding(Spacing.space7)

            // ── Top Domains (if any browser usage) ──
            if !allDomains.isEmpty {
                Divider().opacity(0.3).padding(.horizontal, Spacing.space7)

                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text("TOP SITES")
                        .font(AppFont.text(FontSize.xs2, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(theme.mutedForeground)

                    ForEach(allDomains) { domain in
                        HStack(spacing: Spacing.space3) {
                            Image(systemName: "globe")
                                .font(AppFont.text(FontSize.xs2))
                                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                                .frame(width: 20)

                            Text(domain.domain)
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)

                            Spacer()

                            Text(formatDuration(domain.seconds))
                                .font(AppFont.text(FontSize.sm).monospacedDigit())
                                .foregroundStyle(theme.mutedForeground)
                        }
                    }
                }
                .padding(Spacing.space7)
            }

            Spacer(minLength: 8)
        }
        .dashboardCard()
    }

    // ── Helpers ──

    private func sessionAppRow(app: SessionAppBreakdownResponse) -> some View {
        HStack(spacing: Spacing.space3) {
            Text("\(app.percent)%")
                .font(AppFont.text(FontSize.sm).monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 30, alignment: .trailing)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(categoryColor(app.category))
                    .frame(width: max(2, CGFloat(app.percent) / 100.0 * geo.size.width))
            }
            .frame(width: 50, height: 5)

            Text(app.appName)
                .font(AppFont.text(FontSize.sm, .medium))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)

            Spacer()

            Text(formatDuration(app.totalSeconds))
                .font(AppFont.text(FontSize.sm).monospacedDigit())
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

    private var headerText: String {
        viewModel.isToday ? "Summary · Day - Today" : "Summary · Day"
    }

    private var targetSeconds: Int { AppSettings.shared.targetHoursPerDay * 3600 }

    private var topCategories: [CategoryBreakdownResponse] {
        Array(viewModel.categoryBreakdown.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space5) {
            header
            workHoursCard
            productivityMetricsCard
            contextSwitchCard
            topCategoriesCard
        }
    }

    // MARK: - Context Switches

    private var contextSwitchCard: some View {
        let total = viewModel.totalContextSwitches
        let peak = viewModel.peakSwitchHour
        return VStack(alignment: .leading, spacing: Spacing.space3) {
            HStack {
                Text("Context Switches")
                    .font(AppFont.text(FontSize.sm, .semibold))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text("\(total) today")
                    .font(AppFont.mono(FontSize.sm))
                    .foregroundStyle(theme.mutedForeground)
            }
            // Sparkline of switches per hour
            GeometryReader { geo in
                let maxV = max(1, viewModel.contextSwitches.map(\.switches).max() ?? 1)
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(viewModel.contextSwitches) { row in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(row.switches > 0 ? theme.chartPurple.opacity(
                                0.35 + 0.65 * Double(row.switches) / Double(maxV))
                                  : theme.secondary.opacity(0.4))
                            .frame(height: max(2, geo.size.height
                                * CGFloat(Double(row.switches) / Double(maxV))))
                            .help("\(row.hour):00 — \(row.switches) switches")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 36)

            if let peak {
                Text("Peak: \(String(format: "%02d:00", peak.hour)) (\(peak.count) switches)")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
            } else if total == 0 {
                Text("Single-app focus all day. Nice.")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
            }
        }
        .padding(Spacing.space6)
        .dashboardCard()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chevron.right.2")
                .font(AppFont.text(FontSize.xs))
                .foregroundStyle(theme.mutedForeground)
            Text(headerText)
                .font(AppFont.text(FontSize.md, .semibold))
                .foregroundStyle(theme.foreground)
            Spacer()
            Image(systemName: "gearshape")
                .font(AppFont.text(FontSize.sm))
                .foregroundStyle(theme.mutedForeground)
        }
        .padding(.horizontal, Spacing.space1)
        .padding(.top, Spacing.space1)
    }

    // MARK: - Work Hours

    private var workHoursCard: some View {
        HStack(alignment: .top, spacing: Spacing.space7) {
            VStack(alignment: .leading, spacing: Spacing.space1) {
                Text("Work Hours")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
                Text(viewModel.totalFocusDuration)
                    .font(AppFont.text(FontSize.xl2, .bold))
                    .foregroundStyle(theme.foreground)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.space1) {
                Text("Percent of Target")
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.mutedForeground)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.space1) {
                    Text(String(format: "%.0f%%", viewModel.percentOfTarget))
                        .font(AppFont.text(FontSize.xl2, .bold))
                        .foregroundStyle(theme.foreground)
                    Text("of \(viewModel.formatDuration(targetSeconds))")
                        .font(AppFont.text(FontSize.xs))
                        .foregroundStyle(theme.mutedForeground)
                }
            }
        }
        .padding(Spacing.space7)
        .dashboardCard()
    }

    // MARK: - Productivity Metrics

    private var productivityMetricsCard: some View {
        let focus = viewModel.totalFocusSeconds
        let grandTotal = max(focus, 1)
        return VStack(alignment: .leading, spacing: Spacing.space4) {
            Text("Productivity Metrics")
                .font(AppFont.text(FontSize.sm, .semibold))
                .foregroundStyle(theme.foreground)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.chartCyan)
                        .frame(width: geo.size.width * CGFloat(Double(focus) / Double(grandTotal)))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 8)
                .background(theme.secondary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 8)

            HStack(spacing: Spacing.space7) {
                metricLegend(color: theme.chartCyan, label: "Focus", value: viewModel.formatDuration(focus))
                metricLegend(color: theme.chartPurple, label: "Meetings", value: "0 min")
                metricLegend(color: theme.chartGray, label: "Breaks", value: "0 min")
                metricLegend(color: theme.mutedForeground.opacity(0.4), label: "Other", value: "0 min")
            }
        }
        .padding(Spacing.space6)
        .dashboardCard()
    }

    @ViewBuilder
    private func metricLegend(color: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.space1) {
                RoundedRectangle(cornerRadius: Radius.progressBar)
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(AppFont.text(FontSize.xs))
                    .foregroundStyle(theme.foreground)
            }
            Text(value)
                .font(AppFont.text(FontSize.xs).monospacedDigit())
                .foregroundStyle(theme.mutedForeground)
        }
    }

    // MARK: - Top Categories

    private var topCategoriesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            Text("Top Categories")
                .font(AppFont.text(FontSize.sm, .semibold))
                .foregroundStyle(theme.foreground)
                .padding(.bottom, 2)

            ForEach(Array(topCategories.enumerated()), id: \.offset) { _, cat in
                HStack(spacing: Spacing.space3) {
                    Text("\(cat.percent)%")
                        .font(AppFont.text(FontSize.sm).monospacedDigit())
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 36, alignment: .trailing)
                    RoundedRectangle(cornerRadius: Radius.progressBar)
                        .fill(CategoryColors.color(for: cat.category))
                        .frame(width: 40, height: 6)
                    Text(cat.category)
                        .font(AppFont.text(FontSize.sm))
                        .foregroundStyle(theme.foreground)
                    Spacer()
                    Text(viewModel.formatDuration(cat.totalSeconds))
                        .font(AppFont.text(FontSize.sm).monospacedDigit())
                        .foregroundStyle(theme.mutedForeground)
                }
            }
        }
        .padding(Spacing.space6)
        .dashboardCard()
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
