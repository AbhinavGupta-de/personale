package com.abhinavgpt.server.dto;

import java.util.List;

public record SessionAppBreakdown(
    String appName,
    String bundleId,
    String category,
    long totalSeconds,
    int percent,
    List<DomainTime> domains
) {
    public record DomainTime(String domain, long seconds) {}
}
