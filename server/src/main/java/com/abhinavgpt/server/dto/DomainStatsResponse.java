package com.abhinavgpt.server.dto;

import java.util.List;

public record DomainStatsResponse(
    List<CategoryDetail> categoryDetails
) {
    public record CategoryDetail(
        String category,
        long totalSeconds,
        List<Source> sources
    ) {}

    public record Source(
        String name,
        String type,   // "app" or "domain"
        long seconds
    ) {}
}
