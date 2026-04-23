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
                    if viewModel.streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.accent)
                            Text("\(viewModel.streakDays)d streak")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(theme.foreground)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
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
                    formatDuration: viewModel.formatDuration
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
