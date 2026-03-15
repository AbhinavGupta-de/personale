package com.abhinavgpt.server.dto;

public record SessionAppBreakdown(
    String appName,
    String bundleId,
    String category,
    long totalSeconds,
    int percent
) {}
