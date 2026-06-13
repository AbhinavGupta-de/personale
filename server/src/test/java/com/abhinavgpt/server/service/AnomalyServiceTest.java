package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AnomalyReportResponse;
import com.abhinavgpt.server.dto.CategoryBreakdownEntry;
import com.abhinavgpt.server.dto.ContextSwitchHour;
import com.abhinavgpt.server.dto.InterruptorEntry;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AnomalyServiceTest {

    @Mock
    private StatsService statsService;

    @Mock
    private CategoryThresholdRepository thresholdRepo;

    private static final ZoneId UTC = ZoneOffset.UTC;
    private static final Instant NOW = Instant.parse("2026-05-28T12:00:00Z");
    private static final LocalDate DATE = LocalDate.of(2026, 5, 28);

    private AnomalyService service() {
        when(thresholdRepo.findAll()).thenReturn(List.of(
            new CategoryThreshold("Code", 300, true, true, true, false),
            new CategoryThreshold("Media", 300, false, false, true, false)));
        return new AnomalyService(statsService, thresholdRepo);
    }

    @Test
    void normalDay_allMetricsNormal() {
        stubDay(DATE, 105, 7_200, 4);
        stubDay(DATE.minusDays(1), 100, 7_200, 4);
        stubDay(DATE.minusDays(2), 110, 7_800, 5);
        stubDay(DATE.minusDays(3), 90, 6_600, 3);

        AnomalyReportResponse response = service().computeAnomalies(DATE, UTC, NOW, 0, 3);

        assertThat(response.baselineDaysWithData()).isEqualTo(3);
        assertThat(response.metrics()).extracting(AnomalyReportResponse.Metric::severity)
            .containsExactly("normal", "normal", "normal");
    }

    @Test
    void highContextSwitches_severityHigh() {
        stubDay(DATE, 140, 7_200, 4);
        stubDay(DATE.minusDays(1), 100, 7_200, 4);
        stubDay(DATE.minusDays(2), 120, 7_200, 4);
        stubDay(DATE.minusDays(3), 80, 7_200, 4);

        AnomalyReportResponse.Metric metric = metric(
            service().computeAnomalies(DATE, UTC, NOW, 0, 3), "contextSwitches");

        assertThat(metric.severity()).isEqualTo("high");
        assertThat(metric.zScore()).isGreaterThanOrEqualTo(2.0);
        assertThat(metric.message()).contains("unusually fragmented");
    }

    @Test
    void lowFocus_severityHigh() {
        stubDay(DATE, 100, 6_000, 4);
        stubDay(DATE.minusDays(1), 100, 7_200, 4);
        stubDay(DATE.minusDays(2), 100, 7_800, 4);
        stubDay(DATE.minusDays(3), 100, 6_600, 4);

        AnomalyReportResponse.Metric metric = metric(
            service().computeAnomalies(DATE, UTC, NOW, 0, 3), "focusSeconds");

        assertThat(metric.severity()).isEqualTo("high");
        assertThat(metric.zScore()).isLessThanOrEqualTo(-2.0);
        assertThat(metric.message()).contains("unusually low");
    }

    @Test
    void fewerThanThreeBaselineDays_isInsufficientData() {
        stubDay(DATE, 100, 7_200, 4);
        stubDay(DATE.minusDays(1), 100, 7_200, 4);
        stubDay(DATE.minusDays(2), 110, 7_800, 5);

        AnomalyReportResponse response = service().computeAnomalies(DATE, UTC, NOW, 0, 2);

        assertThat(response.baselineDaysWithData()).isEqualTo(2);
        assertThat(response.metrics()).extracting(AnomalyReportResponse.Metric::severity)
            .containsExactly("insufficient_data", "insufficient_data", "insufficient_data");
    }

    @Test
    void stdDevZero_guardProducesZeroZScore() {
        stubDay(DATE, 150, 3_600, 8);
        stubDay(DATE.minusDays(1), 100, 7_200, 4);
        stubDay(DATE.minusDays(2), 100, 7_200, 4);
        stubDay(DATE.minusDays(3), 100, 7_200, 4);

        AnomalyReportResponse.Metric metric = metric(
            service().computeAnomalies(DATE, UTC, NOW, 0, 3), "contextSwitches");

        assertThat(metric.baselineStdDev()).isEqualTo(0.0);
        assertThat(metric.zScore()).isEqualTo(0.0);
        assertThat(metric.severity()).isEqualTo("normal");
    }

    @Test
    void targetDayNoActivity_isInsufficientData() {
        // Target day has no tracked activity at all — must NOT be scored as a
        // "low focus" anomaly against the baseline. (Only the target day is
        // stubbed: the early return skips the baseline loop entirely.)
        when(statsService.getContextSwitchesPerHour(DATE, UTC, NOW, 0)).thenReturn(List.of());
        when(statsService.getCategoryBreakdown(DATE, UTC, NOW, 0)).thenReturn(List.of());
        when(statsService.getInterruptors(DATE, UTC, NOW, 0)).thenReturn(List.of());

        AnomalyReportResponse response = service().computeAnomalies(DATE, UTC, NOW, 0, 3);

        assertThat(response.baselineDaysWithData()).isEqualTo(0);
        assertThat(response.metrics()).extracting(AnomalyReportResponse.Metric::severity)
            .containsExactly("insufficient_data", "insufficient_data", "insufficient_data");
    }

    private void stubDay(LocalDate date, int switches, long focusSeconds, int interruptors) {
        when(statsService.getContextSwitchesPerHour(date, UTC, NOW, 0))
            .thenReturn(List.of(new ContextSwitchHour(9, switches)));
        when(statsService.getCategoryBreakdown(date, UTC, NOW, 0))
            .thenReturn(focusSeconds > 0
                ? List.of(new CategoryBreakdownEntry("Code", focusSeconds, 100))
                : List.of());
        when(statsService.getInterruptors(date, UTC, NOW, 0))
            .thenReturn(interruptors(interruptors));
    }

    private List<InterruptorEntry> interruptors(int count) {
        return java.util.stream.IntStream.range(0, count)
            .mapToObj(i -> new InterruptorEntry("App " + i, "bundle." + i, "Chat", 1, 30))
            .toList();
    }

    private AnomalyReportResponse.Metric metric(AnomalyReportResponse response, String name) {
        return response.metrics().stream()
            .filter(m -> m.name().equals(name))
            .findFirst()
            .orElseThrow();
    }
}
