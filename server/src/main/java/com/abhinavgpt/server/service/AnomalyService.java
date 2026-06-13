package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AnomalyReportResponse;
import com.abhinavgpt.server.dto.CategoryBreakdownEntry;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

@Service
public class AnomalyService {

    private static final int MIN_BASELINE_DAYS = 3;

    private final StatsService statsService;
    private final CategoryThresholdRepository thresholdRepo;

    public AnomalyService(StatsService statsService,
                          CategoryThresholdRepository thresholdRepo) {
        this.statsService = statsService;
        this.thresholdRepo = thresholdRepo;
    }

    public AnomalyReportResponse computeAnomalies(LocalDate date, ZoneId zone, Instant now,
                                                  int dayStartHour, int lookbackDays) {
        int days = Math.max(0, lookbackDays);
        Set<String> focusCategories = focusCategories();

        DayMetrics target = loadMetrics(date, zone, now, dayStartHour, focusCategories);
        if (!target.hasActivity()) {
            // No tracked activity on the target day — there's nothing to assess,
            // so don't score zero against the baseline (which would falsely flag
            // "low focus"). Report insufficient_data instead.
            return new AnomalyReportResponse(date.toString(), days, 0, List.of(
                insufficientMetric("contextSwitches", target.contextSwitches()),
                insufficientMetric("focusSeconds", target.focusSeconds()),
                insufficientMetric("interruptorCount", target.interruptorCount())));
        }
        List<DayMetrics> baseline = new ArrayList<>();
        for (int i = 1; i <= days; i++) {
            DayMetrics metrics = loadMetrics(date.minusDays(i), zone, now, dayStartHour, focusCategories);
            if (metrics.hasActivity()) {
                baseline.add(metrics);
            }
        }

        return new AnomalyReportResponse(
            date.toString(),
            days,
            baseline.size(),
            List.of(
                buildMetric("contextSwitches", target.contextSwitches(), values(baseline, MetricKind.CONTEXT_SWITCHES),
                    true, "Context switches", false),
                buildMetric("focusSeconds", target.focusSeconds(), values(baseline, MetricKind.FOCUS_SECONDS),
                    false, "Focus time", true),
                buildMetric("interruptorCount", target.interruptorCount(), values(baseline, MetricKind.INTERRUPTOR_COUNT),
                    true, "Interruptors", false)));
    }

    private Set<String> focusCategories() {
        return StreamSupport.stream(thresholdRepo.findAll().spliterator(), false)
            .filter(CategoryThreshold::isFocus)
            .map(CategoryThreshold::getCategory)
            .collect(Collectors.toSet());
    }

    private DayMetrics loadMetrics(LocalDate date, ZoneId zone, Instant now, int dayStartHour,
                                   Set<String> focusCategories) {
        double contextSwitches = statsService.getContextSwitchesPerHour(date, zone, now, dayStartHour)
            .stream()
            .mapToInt(row -> row.switches())
            .sum();

        double focusSeconds = statsService.getCategoryBreakdown(date, zone, now, dayStartHour)
            .stream()
            .filter(row -> focusCategories.contains(row.category()))
            .mapToLong(CategoryBreakdownEntry::totalSeconds)
            .sum();

        double interruptorCount = statsService.getInterruptors(date, zone, now, dayStartHour).size();

        return new DayMetrics(contextSwitches, focusSeconds, interruptorCount);
    }

    private AnomalyReportResponse.Metric buildMetric(String name, double value, List<Double> baselineValues,
                                                     boolean higherIsWorse, String label,
                                                     boolean durationMetric) {
        double mean = mean(baselineValues);
        double stdDev = stdDev(baselineValues, mean);
        double zScore = stdDev == 0.0 ? 0.0 : (value - mean) / stdDev;
        String severity = severity(baselineValues.size(), zScore, higherIsWorse);
        String message = message(label, value, mean, zScore, severity, higherIsWorse, durationMetric,
            baselineValues.size());

        return new AnomalyReportResponse.Metric(name, value, mean, stdDev, zScore, severity, message);
    }

    private String severity(int baselineDays, double zScore, boolean higherIsWorse) {
        if (baselineDays < MIN_BASELINE_DAYS) {
            return "insufficient_data";
        }
        if (higherIsWorse) {
            if (zScore >= 2.0) return "high";
            if (zScore >= 1.0) return "elevated";
        } else {
            if (zScore <= -2.0) return "high";
            if (zScore <= -1.0) return "elevated";
        }
        return "normal";
    }

    private String message(String label, double value, double mean, double zScore, String severity,
                           boolean higherIsWorse, boolean durationMetric, int baselineDays) {
        String valueText = durationMetric ? formatDuration(Math.round(value)) : formatCount(value);
        String meanText = durationMetric ? formatDuration(Math.round(mean)) : formatCount(mean);
        if ("insufficient_data".equals(severity)) {
            return "%s today: %s; only %d baseline days with activity, need at least %d."
                .formatted(label, valueText, baselineDays, MIN_BASELINE_DAYS);
        }

        String direction = zScore > 0 ? "above" : zScore < 0 ? "below" : "from";
        String assessment = assessment(severity, higherIsWorse);
        return "%s today: %s vs ~%s avg (%.1f sigma %s) - %s."
            .formatted(label, valueText, meanText, Math.abs(zScore), direction, assessment);
    }

    private String assessment(String severity, boolean higherIsWorse) {
        if ("normal".equals(severity)) {
            return "within normal range";
        }
        if (higherIsWorse) {
            return "unusually fragmented";
        }
        return "unusually low";
    }

    private List<Double> values(List<DayMetrics> metrics, MetricKind kind) {
        return metrics.stream()
            .map(m -> switch (kind) {
                case CONTEXT_SWITCHES -> m.contextSwitches();
                case FOCUS_SECONDS -> m.focusSeconds();
                case INTERRUPTOR_COUNT -> m.interruptorCount();
            })
            .toList();
    }

    private double mean(List<Double> values) {
        if (values.isEmpty()) return 0.0;
        return values.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
    }

    private double stdDev(List<Double> values, double mean) {
        // Sample standard deviation (n-1): the baseline is a small sample of the
        // user's days, not the full population. Dividing by n would understate
        // spread and overstate z-scores on small baselines.
        if (values.size() < 2) return 0.0;
        double sumSquares = values.stream()
            .mapToDouble(value -> Math.pow(value - mean, 2))
            .sum();
        return Math.sqrt(sumSquares / (values.size() - 1));
    }

    private AnomalyReportResponse.Metric insufficientMetric(String name, double value) {
        return new AnomalyReportResponse.Metric(name, value, 0.0, 0.0, 0.0, "insufficient_data",
            "Not enough tracked activity on this day to assess.");
    }

    private String formatCount(double value) {
        return Long.toString(Math.round(value));
    }

    private String formatDuration(long totalSeconds) {
        long hours = totalSeconds / 3600;
        long minutes = (totalSeconds % 3600) / 60;
        return hours + "h" + minutes + "m";
    }

    private enum MetricKind {
        CONTEXT_SWITCHES,
        FOCUS_SECONDS,
        INTERRUPTOR_COUNT
    }

    private record DayMetrics(double contextSwitches, double focusSeconds, double interruptorCount) {
        boolean hasActivity() {
            return contextSwitches > 0 || focusSeconds > 0 || interruptorCount > 0;
        }
    }
}
