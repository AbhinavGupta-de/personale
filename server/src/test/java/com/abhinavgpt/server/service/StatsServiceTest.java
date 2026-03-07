package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AppTimeEntry;
import com.abhinavgpt.server.dto.DailyStatsResponse;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.repository.AppSessionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StatsServiceTest {

    @Mock
    private AppSessionRepository repository;

    @InjectMocks
    private StatsService statsService;

    private static final ZoneId UTC = ZoneOffset.UTC;

    @Test
    void getTimePerAppToday_closedSession_returnsCorrectDuration() {
        Instant start = Instant.parse("2026-03-07T10:00:00Z");
        Instant end = Instant.parse("2026-03-07T10:30:00Z");
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession session = new AppSession("Safari", "com.apple.Safari", null, start);
        session.setEndedAt(end);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(session));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().appName()).isEqualTo("Safari");
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(1800); // 30 minutes
        assertThat(response.totalTrackedSeconds()).isEqualTo(1800);
    }

    @Test
    void getTimePerAppToday_activeSession_usesNowForEndTime() {
        Instant start = Instant.parse("2026-03-07T11:00:00Z");
        Instant now = Instant.parse("2026-03-07T11:15:00Z");

        AppSession session = new AppSession("Terminal", "com.apple.Terminal", null, start);
        // endedAt is null — session still active

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(session));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(900); // 15 minutes
    }

    @Test
    void getTimePerAppToday_multipleSessionsSameApp_aggregates() {
        Instant s1Start = Instant.parse("2026-03-07T09:00:00Z");
        Instant s1End = Instant.parse("2026-03-07T09:20:00Z");
        Instant s2Start = Instant.parse("2026-03-07T10:00:00Z");
        Instant s2End = Instant.parse("2026-03-07T10:40:00Z");
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession s1 = new AppSession("Safari", "com.apple.Safari", null, s1Start);
        s1.setEndedAt(s1End);
        AppSession s2 = new AppSession("Safari", "com.apple.Safari", null, s2Start);
        s2.setEndedAt(s2End);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(s1, s2));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(3600); // 20 + 40 = 60 minutes
    }

    @Test
    void getTimePerAppToday_multipleApps_sortedByDurationDescending() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession short1 = new AppSession("Finder", "com.apple.finder", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        short1.setEndedAt(Instant.parse("2026-03-07T09:05:00Z")); // 5 min

        AppSession long1 = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        long1.setEndedAt(Instant.parse("2026-03-07T11:00:00Z")); // 60 min

        AppSession med1 = new AppSession("Terminal", "com.apple.Terminal", null,
            Instant.parse("2026-03-07T11:00:00Z"));
        med1.setEndedAt(Instant.parse("2026-03-07T11:30:00Z")); // 30 min

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(short1, long1, med1));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.apps()).hasSize(3);
        assertThat(response.apps().get(0).appName()).isEqualTo("Safari");
        assertThat(response.apps().get(1).appName()).isEqualTo("Terminal");
        assertThat(response.apps().get(2).appName()).isEqualTo("Finder");
    }

    @Test
    void getTimePerAppToday_noSessions_returnsEmpty() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.apps()).isEmpty();
        assertThat(response.totalTrackedSeconds()).isZero();
        assertThat(response.date()).isEqualTo("2026-03-07");
    }

    @Test
    void getTimePerAppToday_sessionSpanningMidnight_clampedToDay() {
        // Session started yesterday at 23:00, ended today at 02:00
        Instant start = Instant.parse("2026-03-06T23:00:00Z");
        Instant end = Instant.parse("2026-03-07T02:00:00Z");
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession session = new AppSession("Safari", "com.apple.Safari", null, start);
        session.setEndedAt(end);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(session));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.apps()).hasSize(1);
        // Only 2 hours should count (00:00 to 02:00), not 3 hours (23:00 to 02:00)
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(7200);
    }

    @Test
    void getTimePerAppToday_dateFromNowParameter_notWallClock() {
        // Pass a `now` that's on a different date than wall-clock time
        Instant now = Instant.parse("2026-01-15T10:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now);

        assertThat(response.date()).isEqualTo("2026-01-15");
    }
}
