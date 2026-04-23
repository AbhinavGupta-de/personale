package com.abhinavgpt.server.dto;

public record PomodoroSessionResponse(
    Long id,
    String goal,
    String startedAt,       // ISO-8601
    String endedAt,         // ISO-8601, nullable
    int targetSeconds,
    int durationSeconds,
    String status
) {}
