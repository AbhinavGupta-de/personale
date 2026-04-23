package com.abhinavgpt.server.dto;

public record InterruptorEntry(
    String appName,
    String bundleId,
    String category,
    int count,
    int totalSeconds
) {}
