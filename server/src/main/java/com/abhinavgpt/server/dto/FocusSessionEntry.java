package com.abhinavgpt.server.dto;

import java.util.List;

public record FocusSessionEntry(
    String name,
    String startTime,
    String endTime,
    long durationSeconds,
    String duration,
    List<SessionAppBreakdown> apps,
    List<CategoryBreakdownEntry> categories
) {}
