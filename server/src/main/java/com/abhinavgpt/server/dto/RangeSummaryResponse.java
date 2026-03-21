package com.abhinavgpt.server.dto;

import java.util.List;

public record RangeSummaryResponse(
    String from,
    String to,
    long totalTrackedSeconds,
    int daysWithData,
    long avgSecondsPerDay,
    long avgSecondsPerWeek,
    List<CategoryBreakdownEntry> categoryBreakdown
) {}
