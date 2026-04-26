package com.abhinavgpt.server.dto;

public record ContextSwitchHour(
    int hour,        // 0..23 in local time
    int switches
) {}
