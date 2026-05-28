package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.CategoryBreakdownEntry;
import com.abhinavgpt.server.dto.CurrentActivityResponse;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ActivityServiceTest {

    @Mock
    private AppSessionRepository sessionRepo;

    @Mock
    private CategoryResolver categoryResolver;

    @Mock
    private CategoryThresholdRepository thresholdRepo;

    @Mock
    private StatsService statsService;

    private static final ZoneId UTC = ZoneOffset.UTC;
    private static final Instant NOW = Instant.parse("2026-05-28T09:50:00Z");

    private ActivityService service() {
        return new ActivityService(sessionRepo, categoryResolver, thresholdRepo, statsService);
    }

    private AppSession active(String app, String bundleId, Instant startedAt) {
        return new AppSession(app, bundleId, null, startedAt);
    }

    // ── No active session: away vs idle ──

    @Test
    void noActiveSession_lastEndedOver5MinAgo_isAway() {
        when(sessionRepo.findActiveSession()).thenReturn(Optional.empty());
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(0L);
        // last session ended 10 min before now (> 5 min) → away
        when(sessionRepo.findMostRecentEndedAt())
            .thenReturn(Optional.of(NOW.minusSeconds(600)));

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("away");
        assertThat(r.category()).isEmpty();
        assertThat(r.app()).isEmpty();
        assertThat(r.focusMinutes()).isZero();
    }

    @Test
    void noActiveSession_lastEndedRecently_isIdle() {
        when(sessionRepo.findActiveSession()).thenReturn(Optional.empty());
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(0L);
        // ended 2 min ago (<= 5 min) → idle
        when(sessionRepo.findMostRecentEndedAt())
            .thenReturn(Optional.of(NOW.minusSeconds(120)));

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("idle");
    }

    @Test
    void noActiveSession_noSessionsAtAll_isIdle() {
        when(sessionRepo.findActiveSession()).thenReturn(Optional.empty());
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(0L);
        when(sessionRepo.findMostRecentEndedAt()).thenReturn(Optional.empty());

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("idle");
    }

    // ── Active session state transitions ──

    @Test
    void activeSession_under15Min_isIdle() {
        AppSession s = active("Ghostty", "com.mitchellh.ghostty", NOW.minusSeconds(10 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(3L);
        when(categoryResolver.categoryForBundle("com.mitchellh.ghostty")).thenReturn("Code");

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("idle");
        assertThat(r.category()).isEqualTo("Code");
        assertThat(r.app()).isEqualTo("Ghostty");
        assertThat(r.focusMinutes()).isEqualTo(10);
        assertThat(r.contextSwitchesLastHour()).isEqualTo(3);
    }

    @Test
    void activeSession_atLeast15Min_isFocused() {
        AppSession s = active("Ghostty", "com.mitchellh.ghostty", NOW.minusSeconds(47 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(4L);
        when(categoryResolver.categoryForBundle("com.mitchellh.ghostty")).thenReturn("Code");

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("focused");
        assertThat(r.focusMinutes()).isEqualTo(47);
    }

    @Test
    void activeSession_exactly15Min_isFocused() {
        AppSession s = active("Ghostty", "com.mitchellh.ghostty", NOW.minusSeconds(15 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(2L);
        when(categoryResolver.categoryForBundle(any())).thenReturn("Code");

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("focused");
    }

    @Test
    void activeSession_highContextSwitches_isScattered() {
        // 60 min in, but 12 switches in last hour → scattered beats focused
        AppSession s = active("Slack", "com.tinyspeck.slackmacgap", NOW.minusSeconds(60 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(12L);
        when(categoryResolver.categoryForBundle(any())).thenReturn("Communication");

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("scattered");
        assertThat(r.contextSwitchesLastHour()).isEqualTo(12);
    }

    @Test
    void activeSession_breakCategory_isBreak() {
        // Break wins even with many switches and long duration
        AppSession s = active("Music", "com.apple.Music", NOW.minusSeconds(30 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(15L);
        when(categoryResolver.categoryForBundle(any())).thenReturn("Break");
        // Break category configured as not-work-hours
        when(thresholdRepo.findById("Break"))
            .thenReturn(Optional.of(new CategoryThreshold(
                "Break", 300, /*focus*/ false, /*workHours*/ false,
                /*idleDetection*/ true, /*distractionBlocker*/ false)));

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.state()).isEqualTo("break");
        assertThat(r.category()).isEqualTo("Break");
    }

    @Test
    void breakCategoryButWorkHoursTrue_notTreatedAsBreak() {
        // A category literally named "Break" but flagged workHours=true is NOT break-like.
        AppSession s = active("Whatever", "com.x.break", NOW.minusSeconds(40 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(1L);
        when(categoryResolver.categoryForBundle(any())).thenReturn("Break");
        when(thresholdRepo.findById("Break"))
            .thenReturn(Optional.of(new CategoryThreshold(
                "Break", 300, true, /*workHours*/ true, true, false)));

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        // workHours=true → not break → falls through to focused (40 min, low switches)
        assertThat(r.state()).isEqualTo("focused");
    }

    // ── dailyTargetPct ──

    @Test
    void dailyTargetPct_sumsWorkHoursCategoriesOverTarget() {
        AppSession s = active("Ghostty", "com.mitchellh.ghostty", NOW.minusSeconds(20 * 60));
        when(sessionRepo.findActiveSession()).thenReturn(Optional.of(s));
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(2L);
        when(categoryResolver.categoryForBundle(any())).thenReturn("Code");

        // Today: 4h Code (work), 1h Media (not work). Target 8h.
        when(statsService.getCategoryBreakdown(any(), any(), any(), anyInt()))
            .thenReturn(List.of(
                new CategoryBreakdownEntry("Code", 4L * 3600, 80),
                new CategoryBreakdownEntry("Media", 3600, 20)));
        when(thresholdRepo.findAll()).thenReturn(List.of(
            new CategoryThreshold("Code", 300, true, true, true, false),
            new CategoryThreshold("Media", 300, false, false, true, false)));

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        // 4h work / 8h target = 0.5 (Media excluded)
        assertThat(r.dailyTargetPct()).isEqualTo(0.5);
    }

    @Test
    void dailyTargetPct_targetZero_returnsZero() {
        when(sessionRepo.findActiveSession()).thenReturn(Optional.empty());
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(0L);
        when(sessionRepo.findMostRecentEndedAt()).thenReturn(Optional.empty());

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 0);

        assertThat(r.dailyTargetPct()).isZero();
    }

    @Test
    void dailyTargetPct_canExceedOne() {
        when(sessionRepo.findActiveSession()).thenReturn(Optional.empty());
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(0L);
        when(sessionRepo.findMostRecentEndedAt()).thenReturn(Optional.empty());
        // 12h work against 8h target = 1.5
        when(statsService.getCategoryBreakdown(any(), any(), any(), anyInt()))
            .thenReturn(List.of(new CategoryBreakdownEntry("Code", 12L * 3600, 100)));
        when(thresholdRepo.findAll()).thenReturn(List.of(
            new CategoryThreshold("Code", 300, true, true, true, false)));

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        assertThat(r.dailyTargetPct()).isEqualTo(1.5);
    }

    @Test
    void updatedAt_isParseableInstant() {
        when(sessionRepo.findActiveSession()).thenReturn(Optional.empty());
        when(sessionRepo.countSessionsStartedSince(any())).thenReturn(0L);
        when(sessionRepo.findMostRecentEndedAt()).thenReturn(Optional.empty());

        CurrentActivityResponse r = service().getCurrentActivity(UTC, NOW, 0, 8);

        // Must round-trip as an ISO-8601 instant.
        assertThat(Instant.parse(r.updatedAt())).isNotNull();
    }
}
