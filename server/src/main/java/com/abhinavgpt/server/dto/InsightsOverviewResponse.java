package com.abhinavgpt.server.dto;

import java.util.List;

/**
 * Combined "self-knowledge" payload for the Insights page. One endpoint, one
 * round-trip, all the cards. Range is inclusive at both ends in the user's zone.
 */
public record InsightsOverviewResponse(
    String from,
    String to,
    int daysWithData,
    long totalTrackedSeconds,
    long totalProductiveSeconds,
    long totalContextSwitches,

    // 7×24 grid: weekday (1=Mon..7=Sun) × hourOfDay (0..23). Seconds aggregated
    // across the whole range per cell, separately for productive vs total.
    List<HeatmapCell> heatmap,

    // Day-of-week ranking: average per-day seconds (productive + total) across
    // every weekday in the range that had data.
    List<DayOfWeekStat> dayOfWeek,

    // Daily series for sparklines / trend lines.
    List<DailyTrendPoint> dailyTrend,

    // Apps + browser-categories that ate time on non-productive categories
    // in the most recent 7 days. Sorted by totalSeconds desc.
    List<DistractionEntry> topDistractions,

    // Top N longest single focus blocks across the range (productive category,
    // merged sessions). Useful "your best deep-work window" callout.
    List<LongestFocusEntry> longestFocusSessions,

    // 7d + 30d category mix (or whatever the range is, plus prior-period delta
    // when a 7d/30d window is requested by the client).
    List<CategoryBreakdownEntry> categoryBreakdown,
    List<CategoryBreakdownEntry> categoryBreakdownPriorPeriod,

    // Productive-day streaks: a day counts if it hit the threshold.
    StreakStats streaks
) {
    public record HeatmapCell(int weekday, int hour, long productiveSeconds, long totalSeconds) {}
    public record DayOfWeekStat(int weekday, long avgProductiveSeconds, long avgTotalSeconds, int days) {}
    public record DailyTrendPoint(
        String date,
        long productiveSeconds,
        long totalSeconds,
        int contextSwitches,
        int sessionCount,
        int avgSessionSeconds
    ) {}
    public record DistractionEntry(
        String appName,
        String bundleId,
        String category,
        long totalSeconds,
        int sessionCount
    ) {}
    public record LongestFocusEntry(
        String date,
        String startTime,
        String endTime,
        long durationSeconds,
        String category,
        String label
    ) {}
    public record StreakStats(int currentStreak, int longestStreak, int thresholdSeconds) {}
}
