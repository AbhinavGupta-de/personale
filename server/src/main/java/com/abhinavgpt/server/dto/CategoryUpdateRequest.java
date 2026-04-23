package com.abhinavgpt.server.dto;

/** All fields optional — sent nulls mean "don't change". */
public record CategoryUpdateRequest(
    Integer idleThresholdSeconds,
    Boolean focus,
    Boolean workHours,
    Boolean idleDetection,
    Boolean distractionBlocker,
    Integer dailyGoalSeconds,
    Boolean goalIsMax
) {}
