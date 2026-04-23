package com.abhinavgpt.server.dto;

import java.util.List;

public record SessionReviewResponse(
    String blockKey,
    String date,
    String startTime,
    String endTime,
    long durationSeconds,
    String category,
    String title,
    String description,
    String task,
    String project,
    String client,
    String status,
    String aiTitle,
    String aiDescription,
    String aiGeneratedAt,
    List<AppTimeEntry> apps,
    List<CategoryBreakdownEntry> categories,
    List<SessionAppBreakdown.DomainTime> topDomains
) {}
