package com.abhinavgpt.server.dto;

public record PomodoroStartRequest(
    String goal,
    Integer targetSeconds
) {}
