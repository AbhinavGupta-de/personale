package com.abhinavgpt.server.domain;

import java.time.Instant;
import java.util.List;

/**
 * A merged focus block: one or more AppUsages glued together because they
 * share a category and fall within the category's idle threshold.
 *
 * The label is the first constituent's app name — used when we want a
 * human-readable title before doing fuller per-app breakdowns.
 */
public record MergedBlock(
    String category,
    Instant start,
    Instant end,
    long seconds,
    String label,
    List<AppUsage> constituents
) {}
