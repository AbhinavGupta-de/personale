package com.abhinavgpt.server.dto;

import java.util.List;

public record DailyStatsResponse(String date, List<AppTimeEntry> apps, long totalTrackedSeconds) {}
