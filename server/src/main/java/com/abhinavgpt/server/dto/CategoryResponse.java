package com.abhinavgpt.server.dto;

public record CategoryResponse(
    String name,
    int idleThresholdSeconds,
    boolean focus,
    boolean workHours,
    boolean idleDetection,
    boolean distractionBlocker,
    int dailyGoalSeconds,
    boolean goalIsMax
) {}
