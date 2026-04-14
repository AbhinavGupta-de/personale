package com.abhinavgpt.server.domain;

import java.time.Instant;

/**
 * A single app in use for a bounded time window, already clamped to the day.
 * The category is resolved at construction time so merging logic stays pure.
 */
public record AppUsage(
    String appName,
    String bundleId,
    String category,
    Instant start,
    Instant end,
    long seconds
) {
    public static AppUsage of(String appName, String bundleId, String category,
                              Instant start, Instant end) {
        long secs = Math.max(0, java.time.Duration.between(start, end).getSeconds());
        return new AppUsage(appName, bundleId, category, start, end, secs);
    }
}
