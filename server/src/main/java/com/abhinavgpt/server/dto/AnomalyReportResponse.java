package com.abhinavgpt.server.dto;

import java.util.List;

public record AnomalyReportResponse(
    String date,
    int lookbackDays,
    int baselineDaysWithData,
    List<Metric> metrics
) {
    public record Metric(
        String name,
        double value,
        double baselineMean,
        double baselineStdDev,
        double zScore,
        String severity,
        String message
    ) {}
}
