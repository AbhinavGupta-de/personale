package com.abhinavgpt.server.dto;

public record CategoryCreateRequest(
    String name,
    Integer idleThresholdSeconds,
    Boolean focus,
    Boolean workHours,
    Boolean idleDetection,
    Boolean distractionBlocker,
    Integer dailyGoalSeconds,
    Boolean goalIsMax
) {}
