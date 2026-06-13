#if os(macOS)
import SwiftUI

// MARK: - Dashboard Page

struct DashboardPage: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppMetrics.cardGap) {
                HStack {
                    DateNavigator(
                        dateText: viewModel.displayDate,
                        activeView: .constant("Day"),
                        isToday: viewModel.isToday,
                        isLoading: viewModel.isLoading,
                        onPrevious: { viewModel.goToPreviousDay() },
                        onNext: { viewModel.goToNextDay() },
                        onToday: { viewModel.goToToday() }
                    )
                    if let freshStart = viewModel.freshStartLabel {
                        HStack(spacing: Spacing.space1) {
                            Image(systemName: "sparkles")
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.primary)
                            Text(freshStart)
                                .font(AppFont.text(FontSize.sm, .medium))
                                .foregroundStyle(theme.foreground)
                        }
                        .padding(.horizontal, Spacing.space3).padding(.vertical, Spacing.space1)
                        .background(theme.primary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    if viewModel.streakDays > 0 {
                        HStack(spacing: Spacing.space1) {
                            Image(systemName: "flame.fill")
                                .font(AppFont.text(FontSize.sm))
                                .foregroundStyle(theme.accent)
                            Text("\(viewModel.streakDays)d streak")
                                .font(AppFont.text(FontSize.sm, .medium).monospacedDigit())
                                .foregroundStyle(theme.foreground)
                        }
                        .padding(.horizontal, Spacing.space3).padding(.vertical, Spacing.space1)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                HorizontalTimelineCard(
                    blocks: viewModel.timeline,
                    dayStartHour: AppSettings.shared.dayStartHour
                )

                HStack(alignment: .top, spacing: AppMetrics.cardGap) {
                    PieChartCard(
                        totalSeconds: viewModel.dayStats?.totalTrackedSeconds ?? 0,
                        segments: viewModel.categoryBreakdown ?? [],
                        formatDuration: viewModel.formatDuration
                    )
                    .frame(width: 300)

                    CategoriesListCard(
                        categories: viewModel.categoryBreakdown ?? [],
                        formatDuration: viewModel.formatDuration
                    )
                    .frame(maxWidth: .infinity)

                    AppsWebsitesCard(
                        entries: viewModel.dayStats?.apps ?? [],
                        total: viewModel.dayStats?.totalTrackedSeconds ?? 0,
                        formatDuration: viewModel.formatDuration
                    )
                    .frame(width: 320)
                }

                GoalsCard(
                    categories: viewModel.categories,
                    breakdown: viewModel.categoryBreakdown ?? []
                )

                TodaySessionsStrip(
                    sessions: viewModel.focusSessions,
                    formatDuration: viewModel.formatDuration,
                    reviewsByKey: viewModel.reviewsByKey,
                    dateString: viewModel.dateString
                )

                WebsitesCard(
                    categoryDetails: viewModel.domainStats?.categoryDetails ?? [],
                    total: viewModel.dayStats?.totalTrackedSeconds ?? 0,
                    formatDuration: viewModel.formatDuration
                )
            }
            .padding(AppMetrics.contentPadding)
        }
        .onAppear { viewModel.startRefreshing() }
        .onDisappear { viewModel.stopRefreshing() }
    }
}


#endif
