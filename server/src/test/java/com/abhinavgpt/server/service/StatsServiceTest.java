package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.*;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.entity.DomainCategoryMapping;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import com.abhinavgpt.server.repository.DomainCategoryMappingRepository;
import org.junit.jupiter.api.BeforeEach;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StatsServiceTest {

    @Mock
    private AppSessionRepository repository;

    @Mock
    private CategoryMappingRepository categoryRepo;

    @Mock
    private BrowserEventRepository browserEventRepo;

    @Mock
    private DomainCategoryMappingRepository domainCategoryRepo;

    @Mock
    private CategoryThresholdRepository thresholdRepo;

    private StatsService statsService;

    private static final ZoneId UTC = ZoneOffset.UTC;

    @BeforeEach
    void setUp() {
        CategoryResolver categoryResolver = new CategoryResolver(
            categoryRepo, domainCategoryRepo, thresholdRepo);
        DomainTimeService domainTimeService = new DomainTimeService(categoryResolver);
        SessionMergeService mergeService = new SessionMergeService(categoryResolver, domainTimeService);
        statsService = new StatsService(
            repository, browserEventRepo, categoryResolver, mergeService, domainTimeService);
    }

    // ── Existing daily stats tests ──

    @Test
    void getTimePerAppToday_closedSession_returnsCorrectDuration() {
        Instant start = Instant.parse("2026-03-07T10:00:00Z");
        Instant end = Instant.parse("2026-03-07T10:30:00Z");
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession session = new AppSession("Safari", "com.apple.Safari", null, start);
        session.setEndedAt(end);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(session));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().appName()).isEqualTo("Safari");
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(1800);
        assertThat(response.totalTrackedSeconds()).isEqualTo(1800);
    }

    @Test
    void getTimePerAppToday_activeSession_usesNowForEndTime() {
        Instant start = Instant.parse("2026-03-07T11:00:00Z");
        Instant now = Instant.parse("2026-03-07T11:15:00Z");

        AppSession session = new AppSession("Terminal", "com.apple.Terminal", null, start);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(session));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(900);
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

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(3600);
    }

    @Test
    void getTimePerAppToday_multipleApps_sortedByDurationDescending() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession short1 = new AppSession("Finder", "com.apple.finder", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        short1.setEndedAt(Instant.parse("2026-03-07T09:05:00Z"));

        AppSession long1 = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        long1.setEndedAt(Instant.parse("2026-03-07T11:00:00Z"));

        AppSession med1 = new AppSession("Terminal", "com.apple.Terminal", null,
            Instant.parse("2026-03-07T11:00:00Z"));
        med1.setEndedAt(Instant.parse("2026-03-07T11:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(short1, long1, med1));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.apps()).hasSize(3);
        assertThat(response.apps().get(0).appName()).isEqualTo("Safari");
        assertThat(response.apps().get(1).appName()).isEqualTo("Terminal");
        assertThat(response.apps().get(2).appName()).isEqualTo("Finder");
    }

    @Test
    void getTimePerAppToday_noSessions_returnsEmpty() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.apps()).isEmpty();
        assertThat(response.totalTrackedSeconds()).isZero();
        assertThat(response.date()).isEqualTo("2026-03-07");
    }

    @Test
    void getTimePerAppToday_sessionSpanningMidnight_clampedToDay() {
        Instant start = Instant.parse("2026-03-06T23:00:00Z");
        Instant end = Instant.parse("2026-03-07T02:00:00Z");
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        AppSession session = new AppSession("Safari", "com.apple.Safari", null, start);
        session.setEndedAt(end);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(session));

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.apps()).hasSize(1);
        assertThat(response.apps().getFirst().totalSeconds()).isEqualTo(7200);
    }

    @Test
    void getTimePerAppToday_dateFromNowParameter_notWallClock() {
        Instant now = Instant.parse("2026-01-15T10:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 0);

        assertThat(response.date()).isEqualTo("2026-01-15");
    }

    // ── dayStartHour windowing ──

    @Test
    void getTimePerApp_dayStartHour_queriesShiftedWindow() {
        LocalDate date = LocalDate.of(2026, 3, 10);
        Instant now = Instant.parse("2026-03-11T08:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());
        statsService.getTimePerApp(date, UTC, now, 6);

        org.mockito.ArgumentCaptor<Instant> startCap = org.mockito.ArgumentCaptor.forClass(Instant.class);
        org.mockito.ArgumentCaptor<Instant> endCap = org.mockito.ArgumentCaptor.forClass(Instant.class);
        org.mockito.Mockito.verify(repository)
            .findSessionsOverlapping(startCap.capture(), endCap.capture());
        assertThat(startCap.getValue()).isEqualTo(Instant.parse("2026-03-10T06:00:00Z"));
        assertThat(endCap.getValue()).isEqualTo(Instant.parse("2026-03-11T06:00:00Z"));
    }

    @Test
    void getTimePerAppToday_beforeDayStart_usesPreviousDate() {
        // 4am with dayStartHour=6 → logical date is yesterday
        Instant now = Instant.parse("2026-03-11T04:30:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());
        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 6);

        assertThat(response.date()).isEqualTo("2026-03-10");
    }

    @Test
    void getTimePerAppToday_afterDayStart_usesCurrentDate() {
        Instant now = Instant.parse("2026-03-11T09:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());
        DailyStatsResponse response = statsService.getTimePerAppToday(UTC, now, 6);

        assertThat(response.date()).isEqualTo("2026-03-11");
    }

    // ── Interruptors ──

    @Test
    void interruptors_countsShortSessionsOnly() {
        Instant now = Instant.parse("2026-04-20T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 4, 20);

        // Long session (5 min) — should be excluded
        AppSession longSess = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-04-20T09:00:00Z"));
        longSess.setEndedAt(Instant.parse("2026-04-20T09:05:00Z"));

        // 3 short Slack sessions (30s each)
        AppSession short1 = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-04-20T09:10:00Z"));
        short1.setEndedAt(Instant.parse("2026-04-20T09:10:30Z"));
        AppSession short2 = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-04-20T09:20:00Z"));
        short2.setEndedAt(Instant.parse("2026-04-20T09:20:30Z"));
        AppSession short3 = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-04-20T09:30:00Z"));
        short3.setEndedAt(Instant.parse("2026-04-20T09:30:30Z"));

        when(repository.findSessionsOverlapping(any(), any()))
            .thenReturn(List.of(longSess, short1, short2, short3));

        List<InterruptorEntry> result = statsService.getInterruptors(date, UTC, now, 0);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).appName()).isEqualTo("Slack");
        assertThat(result.get(0).count()).isEqualTo(3);
        assertThat(result.get(0).totalSeconds()).isEqualTo(90);
    }

    @Test
    void interruptors_respects120sThreshold() {
        Instant now = Instant.parse("2026-04-20T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 4, 20);

        // Exactly 120s — boundary excluded
        AppSession boundary = new AppSession("Mail", "com.apple.mail", null,
            Instant.parse("2026-04-20T09:00:00Z"));
        boundary.setEndedAt(Instant.parse("2026-04-20T09:02:00Z"));
        // 119s — included
        AppSession justUnder = new AppSession("Mail", "com.apple.mail", null,
            Instant.parse("2026-04-20T10:00:00Z"));
        justUnder.setEndedAt(Instant.parse("2026-04-20T10:01:59Z"));

        when(repository.findSessionsOverlapping(any(), any()))
            .thenReturn(List.of(boundary, justUnder));

        List<InterruptorEntry> result = statsService.getInterruptors(date, UTC, now, 0);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).count()).isEqualTo(1);
        assertThat(result.get(0).totalSeconds()).isEqualTo(119);
    }

    @Test
    void interruptors_cappedAt10ApsSortedByCount() {
        Instant now = Instant.parse("2026-04-20T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 4, 20);

        List<AppSession> all = new java.util.ArrayList<>();
        // App A: 5 short sessions
        for (int i = 0; i < 5; i++) {
            AppSession s = new AppSession("AppA", "app.a", null,
                Instant.parse("2026-04-20T09:00:00Z").plusSeconds(i * 60));
            s.setEndedAt(s.getStartedAt().plusSeconds(30));
            all.add(s);
        }
        // App B: 2 short sessions
        for (int i = 0; i < 2; i++) {
            AppSession s = new AppSession("AppB", "app.b", null,
                Instant.parse("2026-04-20T10:00:00Z").plusSeconds(i * 60));
            s.setEndedAt(s.getStartedAt().plusSeconds(30));
            all.add(s);
        }

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(all);

        List<InterruptorEntry> result = statsService.getInterruptors(date, UTC, now, 0);

        assertThat(result).hasSize(2);
        assertThat(result.get(0).appName()).isEqualTo("AppA");
        assertThat(result.get(0).count()).isEqualTo(5);
        assertThat(result.get(1).appName()).isEqualTo("AppB");
    }

    // ── getTimePerApp (date parameter) ──

    @Test
    void getTimePerApp_specificDate_returnsCorrectDate() {
        LocalDate date = LocalDate.of(2026, 3, 10);
        Instant now = Instant.parse("2026-03-15T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        DailyStatsResponse response = statsService.getTimePerApp(date, UTC, now, 0);

        assertThat(response.date()).isEqualTo("2026-03-10");
    }

    // ── Timeline tests ──

    @Test
    void getTimeline_returnsOrderedBlocksWithCategories() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession s1 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        s1.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        AppSession s2 = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        s2.setEndedAt(Instant.parse("2026-03-07T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(s1, s2));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        List<TimelineEntry> timeline = statsService.getTimeline(date, UTC, now, 0);

        assertThat(timeline).hasSize(2);
        assertThat(timeline.get(0).appName()).isEqualTo("Xcode");
        assertThat(timeline.get(0).startTime()).isEqualTo("09:00");
        assertThat(timeline.get(0).endTime()).isEqualTo("10:00");
        assertThat(timeline.get(0).category()).isEqualTo("Code");
        assertThat(timeline.get(1).appName()).isEqualTo("Safari");
        assertThat(timeline.get(1).category()).isEqualTo("Browsing");
    }

    @Test
    void getTimeline_skipsIdleSessions() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession real = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        real.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        // Idle session (ended_at == started_at)
        AppSession idle = new AppSession("idle", null, null,
            Instant.parse("2026-03-07T10:00:00Z"));
        idle.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(real, idle));
        when(categoryRepo.findAll()).thenReturn(List.of());

        List<TimelineEntry> timeline = statsService.getTimeline(date, UTC, now, 0);

        assertThat(timeline).hasSize(1);
        assertThat(timeline.getFirst().appName()).isEqualTo("Xcode");
    }

    @Test
    void getTimeline_emptyDay_returnsEmptyList() {
        LocalDate date = LocalDate.of(2026, 3, 7);
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        List<TimelineEntry> timeline = statsService.getTimeline(date, UTC, now, 0);

        assertThat(timeline).isEmpty();
    }

    // ── Activity log tests ──

    @Test
    void getActivityLog_returnsChronologicalEntries() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession s1 = new AppSession("Terminal", "com.apple.Terminal", "zsh",
            Instant.parse("2026-03-07T09:00:00Z"));
        s1.setEndedAt(Instant.parse("2026-03-07T09:30:00Z"));

        AppSession s2 = new AppSession("Safari", "com.apple.Safari", "GitHub",
            Instant.parse("2026-03-07T09:30:00Z"));
        s2.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(s1, s2));

        List<ActivityLogEntry> log = statsService.getActivityLog(date, UTC, now, 0);

        assertThat(log).hasSize(2);
        assertThat(log.get(0).appName()).isEqualTo("Terminal");
        assertThat(log.get(0).detail()).isEqualTo("zsh"); // uses window title
        assertThat(log.get(0).durationSeconds()).isEqualTo(1800);
        assertThat(log.get(1).appName()).isEqualTo("Safari");
        assertThat(log.get(1).detail()).isEqualTo("GitHub");
    }

    @Test
    void getActivityLog_noWindowTitle_fallsBackToCategory() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession s1 = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        s1.setEndedAt(Instant.parse("2026-03-07T09:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(s1));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        List<ActivityLogEntry> log = statsService.getActivityLog(date, UTC, now, 0);

        assertThat(log).hasSize(1);
        assertThat(log.getFirst().detail()).isEqualTo("Browsing");
    }

    // ── Category breakdown tests ──

    @Test
    void getCategoryBreakdown_groupsByCategory() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession xcode = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        xcode.setEndedAt(Instant.parse("2026-03-07T10:00:00Z")); // 1h

        AppSession terminal = new AppSession("Terminal", "com.apple.Terminal", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        terminal.setEndedAt(Instant.parse("2026-03-07T10:30:00Z")); // 30m

        AppSession safari = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:30:00Z"));
        safari.setEndedAt(Instant.parse("2026-03-07T11:00:00Z")); // 30m

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(xcode, terminal, safari));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Terminal", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        assertThat(breakdown).hasSize(2);
        // Code = 1h + 30m = 5400s (75%), Browsing = 30m = 1800s (25%)
        assertThat(breakdown.get(0).category()).isEqualTo("Code");
        assertThat(breakdown.get(0).totalSeconds()).isEqualTo(5400);
        assertThat(breakdown.get(0).percent()).isEqualTo(75);
        assertThat(breakdown.get(1).category()).isEqualTo("Browsing");
        assertThat(breakdown.get(1).totalSeconds()).isEqualTo(1800);
        assertThat(breakdown.get(1).percent()).isEqualTo(25);
    }

    @Test
    void getCategoryBreakdown_unmappedApp_goesToOther() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession unknown = new AppSession("MyApp", "com.unknown.app", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        unknown.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(unknown));
        when(categoryRepo.findAll()).thenReturn(List.of());

        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        assertThat(breakdown).hasSize(1);
        assertThat(breakdown.getFirst().category()).isEqualTo("Other");
        assertThat(breakdown.getFirst().percent()).isEqualTo(100);
    }

    @Test
    void getCategoryBreakdown_emptyDay_returnsEmptyList() {
        LocalDate date = LocalDate.of(2026, 3, 7);
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        assertThat(breakdown).isEmpty();
    }

    // ── Workblocks tests ──

    @Test
    void getWorkblocks_mergesConsecutiveSameCategory() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // Xcode then Terminal — both "Code" — should merge into one block
        AppSession xcode = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        xcode.setEndedAt(Instant.parse("2026-03-07T10:00:00Z")); // 1h

        AppSession terminal = new AppSession("Terminal", "com.apple.Terminal", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        terminal.setEndedAt(Instant.parse("2026-03-07T10:30:00Z")); // 30m

        // Safari — "Browsing" — separate block
        AppSession safari = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:30:00Z"));
        safari.setEndedAt(Instant.parse("2026-03-07T11:00:00Z")); // 30m

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(xcode, terminal, safari));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Terminal", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        assertThat(blocks).hasSize(2);
        assertThat(blocks.get(0).task()).isEqualTo("Code");
        assertThat(blocks.get(0).time()).isEqualTo("9:00");
        assertThat(blocks.get(0).durationSeconds()).isEqualTo(5400); // 1h30m
        assertThat(blocks.get(0).duration()).isEqualTo("1 hr 30 min");
        assertThat(blocks.get(1).task()).isEqualTo("Browsing");
        assertThat(blocks.get(1).durationSeconds()).isEqualTo(1800);
    }

    @Test
    void getWorkblocks_longInterruption_staysSeparate() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        AppSession code1 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        code1.setEndedAt(Instant.parse("2026-03-07T09:30:00Z"));

        // 15-minute Slack — above 5-min threshold, stays separate
        AppSession slack = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-03-07T09:30:00Z"));
        slack.setEndedAt(Instant.parse("2026-03-07T09:45:00Z"));

        AppSession code2 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:45:00Z"));
        code2.setEndedAt(Instant.parse("2026-03-07T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(code1, slack, code2));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.tinyspeck.slackmacgap", "Communication")
        ));

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        assertThat(blocks).hasSize(3);
        assertThat(blocks.get(0).task()).isEqualTo("Code");
        assertThat(blocks.get(1).task()).isEqualTo("Communication");
        assertThat(blocks.get(2).task()).isEqualTo("Code");
    }

    @Test
    void getWorkblocks_briefInterruption_absorbedIntoNeighbor() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // 30-min coding
        AppSession code1 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        code1.setEndedAt(Instant.parse("2026-03-07T09:30:00Z"));

        // 2-min Slack check — below 5-min threshold, should be absorbed into Code
        AppSession slack = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-03-07T09:30:00Z"));
        slack.setEndedAt(Instant.parse("2026-03-07T09:32:00Z"));

        // 45-min more coding
        AppSession code2 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:32:00Z"));
        code2.setEndedAt(Instant.parse("2026-03-07T10:17:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(code1, slack, code2));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.tinyspeck.slackmacgap", "Communication")
        ));

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        // Brief Slack check absorbed → single Code block spanning 09:00-10:17
        assertThat(blocks).hasSize(1);
        assertThat(blocks.get(0).task()).isEqualTo("Code");
        assertThat(blocks.get(0).time()).isEqualTo("9:00");
        assertThat(blocks.get(0).durationSeconds()).isEqualTo(4620); // 30+2+45 min = 77 min
    }

    @Test
    void getWorkblocks_briefInterruptionBetweenDifferentCategories_absorbedIntoPredecessor() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // 1-hour coding
        AppSession code = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        code.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        // 3-min Finder (below threshold)
        AppSession finder = new AppSession("Finder", "com.apple.finder", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        finder.setEndedAt(Instant.parse("2026-03-07T10:03:00Z"));

        // 30-min browsing
        AppSession safari = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:03:00Z"));
        safari.setEndedAt(Instant.parse("2026-03-07T10:33:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(code, finder, safari));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.finder", "Utilities"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        // Brief Finder absorbed into predecessor (Code), then Browsing stays separate
        assertThat(blocks).hasSize(2);
        assertThat(blocks.get(0).task()).isEqualTo("Code");
        assertThat(blocks.get(0).durationSeconds()).isEqualTo(3780); // 60+3 min
        assertThat(blocks.get(1).task()).isEqualTo("Browsing");
        assertThat(blocks.get(1).durationSeconds()).isEqualTo(1800);
    }

    @Test
    void getWorkblocks_emptyDay_returnsEmptyList() {
        LocalDate date = LocalDate.of(2026, 3, 7);
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        assertThat(blocks).isEmpty();
    }

    @Test
    void getWorkblocks_idleGapSplitsSameCategory() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // Slack session at 1:13 AM, user goes idle
        AppSession slack1 = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-03-07T01:13:00Z"));
        slack1.setEndedAt(Instant.parse("2026-03-07T01:20:00Z")); // 7 min

        // User returns hours later, still on Slack — 5-hour idle gap
        AppSession slack2 = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-03-07T06:30:00Z"));
        slack2.setEndedAt(Instant.parse("2026-03-07T06:45:00Z")); // 15 min

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(slack1, slack2));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.tinyspeck.slackmacgap", "Communication")
        ));

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        // Gap > 3 min threshold — should be TWO separate Communication blocks
        assertThat(blocks).hasSize(2);
        assertThat(blocks.get(0).task()).isEqualTo("Communication");
        assertThat(blocks.get(0).time()).isEqualTo("1:13");
        assertThat(blocks.get(0).durationSeconds()).isEqualTo(420); // 7 min
        assertThat(blocks.get(1).task()).isEqualTo("Communication");
        assertThat(blocks.get(1).time()).isEqualTo("6:30");
        assertThat(blocks.get(1).durationSeconds()).isEqualTo(900); // 15 min
    }

    @Test
    void getWorkblocks_smallGapSameCategory_merges() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // Two Xcode sessions with a 1-minute gap (< 3 min threshold)
        AppSession code1 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        code1.setEndedAt(Instant.parse("2026-03-07T09:30:00Z"));

        AppSession code2 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:31:00Z")); // 1-min gap
        code2.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(code1, code2));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code")
        ));

        List<WorkblockEntry> blocks = statsService.getWorkblocks(date, UTC, now, 0);

        // Small gap — should merge into one block
        assertThat(blocks).hasSize(1);
        assertThat(blocks.get(0).task()).isEqualTo("Code");
        assertThat(blocks.get(0).durationSeconds()).isEqualTo(3540); // 30+29 min active time
    }

    // ── Focus sessions tests ──

    @Test
    void getFocusSessions_returnsPerAppBreakdown() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // Xcode 1h, Terminal 30m (both Code), Safari 30m (Browsing)
        AppSession xcode = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        xcode.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        AppSession terminal = new AppSession("Terminal", "com.apple.Terminal", null,
            Instant.parse("2026-03-07T10:00:00Z"));
        terminal.setEndedAt(Instant.parse("2026-03-07T10:30:00Z"));

        AppSession safari = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-07T10:30:00Z"));
        safari.setEndedAt(Instant.parse("2026-03-07T11:00:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(xcode, terminal, safari));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Terminal", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        List<FocusSessionEntry> sessions = statsService.getFocusSessions(date, UTC, now, 0);

        // Code block (Xcode+Terminal merged), Browsing block (Safari)
        assertThat(sessions).hasSize(2);

        // First session: Code with 2 apps
        FocusSessionEntry codeSession = sessions.get(0);
        assertThat(codeSession.name()).isEqualTo("Code");
        assertThat(codeSession.startTime()).isEqualTo("09:00");
        assertThat(codeSession.endTime()).isEqualTo("10:30");
        assertThat(codeSession.durationSeconds()).isEqualTo(5400);
        assertThat(codeSession.apps()).hasSize(2);
        assertThat(codeSession.apps().get(0).appName()).isEqualTo("Xcode"); // 3600s, sorted first
        assertThat(codeSession.apps().get(0).totalSeconds()).isEqualTo(3600);
        assertThat(codeSession.apps().get(1).appName()).isEqualTo("Terminal");
        assertThat(codeSession.apps().get(1).totalSeconds()).isEqualTo(1800);
        assertThat(codeSession.categories()).hasSize(1);
        assertThat(codeSession.categories().get(0).category()).isEqualTo("Code");

        // Second session: Browsing
        FocusSessionEntry browseSession = sessions.get(1);
        assertThat(browseSession.name()).isEqualTo("Browsing");
        assertThat(browseSession.apps()).hasSize(1);
        assertThat(browseSession.apps().get(0).appName()).isEqualTo("Safari");
    }

    @Test
    void getFocusSessions_absorbedInterruptionShowsInApps() {
        Instant now = Instant.parse("2026-03-07T12:00:00Z");
        LocalDate date = LocalDate.of(2026, 3, 7);

        // Coding with a brief Slack check absorbed
        AppSession code1 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        code1.setEndedAt(Instant.parse("2026-03-07T09:30:00Z"));

        AppSession slack = new AppSession("Slack", "com.tinyspeck.slackmacgap", null,
            Instant.parse("2026-03-07T09:30:00Z"));
        slack.setEndedAt(Instant.parse("2026-03-07T09:32:00Z")); // 2 min < threshold

        AppSession code2 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:32:00Z"));
        code2.setEndedAt(Instant.parse("2026-03-07T10:17:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(code1, slack, code2));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.tinyspeck.slackmacgap", "Communication")
        ));

        List<FocusSessionEntry> sessions = statsService.getFocusSessions(date, UTC, now, 0);

        // Single merged Code session containing both Xcode and Slack
        assertThat(sessions).hasSize(1);
        FocusSessionEntry session = sessions.get(0);
        assertThat(session.name()).isEqualTo("Code");
        assertThat(session.apps()).hasSize(2); // Xcode and Slack
        assertThat(session.apps().get(0).appName()).isEqualTo("Xcode");
        assertThat(session.apps().get(1).appName()).isEqualTo("Slack");
        // Categories: Code + Communication
        assertThat(session.categories()).hasSize(2);
        assertThat(session.categories().get(0).category()).isEqualTo("Code");
        assertThat(session.categories().get(1).category()).isEqualTo("Communication");
    }

    @Test
    void getFocusSessions_emptyDay_returnsEmptyList() {
        LocalDate date = LocalDate.of(2026, 3, 7);
        Instant now = Instant.parse("2026-03-07T12:00:00Z");

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        List<FocusSessionEntry> sessions = statsService.getFocusSessions(date, UTC, now, 0);

        assertThat(sessions).isEmpty();
    }

    // ── Range aggregation tests ──

    @Test
    void getRange_multiDayRange_returnsPerDayBreakdown() {
        Instant now = Instant.parse("2026-03-09T12:00:00Z");
        LocalDate from = LocalDate.of(2026, 3, 7);
        LocalDate to = LocalDate.of(2026, 3, 8);

        // Day 1: Xcode 1h
        AppSession xcode = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        xcode.setEndedAt(Instant.parse("2026-03-07T10:00:00Z"));

        // Day 2: Safari 30m
        AppSession safari = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-08T14:00:00Z"));
        safari.setEndedAt(Instant.parse("2026-03-08T14:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any()))
            .thenReturn(List.of(xcode))   // day 1
            .thenReturn(List.of(safari));  // day 2
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        RangeResponse response = statsService.getRange(from, to, UTC, now, 0);

        assertThat(response.days()).hasSize(2);
        assertThat(response.days().get(0).date()).isEqualTo("2026-03-07");
        assertThat(response.days().get(0).totalTrackedSeconds()).isEqualTo(3600);
        assertThat(response.days().get(0).categories()).hasSize(1);
        assertThat(response.days().get(0).categories().get(0).category()).isEqualTo("Code");

        assertThat(response.days().get(1).date()).isEqualTo("2026-03-08");
        assertThat(response.days().get(1).totalTrackedSeconds()).isEqualTo(1800);
        assertThat(response.days().get(1).categories().get(0).category()).isEqualTo("Browsing");
    }

    @Test
    void getRange_dayWithNoData_returnsZero() {
        Instant now = Instant.parse("2026-03-10T12:00:00Z");
        LocalDate from = LocalDate.of(2026, 3, 9);
        LocalDate to = LocalDate.of(2026, 3, 9);

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of());

        RangeResponse response = statsService.getRange(from, to, UTC, now, 0);

        assertThat(response.days()).hasSize(1);
        assertThat(response.days().get(0).totalTrackedSeconds()).isEqualTo(0);
        assertThat(response.days().get(0).categories()).isEmpty();
    }

    @Test
    void getRangeSummary_computesAveragesFromDaysWithData() {
        Instant now = Instant.parse("2026-03-10T12:00:00Z");
        LocalDate from = LocalDate.of(2026, 3, 7);
        LocalDate to = LocalDate.of(2026, 3, 9);  // 3 days, but only 2 have data

        // Day 1: 2h Code
        AppSession d1 = new AppSession("Xcode", "com.apple.dt.Xcode", null,
            Instant.parse("2026-03-07T09:00:00Z"));
        d1.setEndedAt(Instant.parse("2026-03-07T11:00:00Z"));

        // Day 2: empty
        // Day 3: 1h Browsing
        AppSession d3 = new AppSession("Safari", "com.apple.Safari", null,
            Instant.parse("2026-03-09T10:00:00Z"));
        d3.setEndedAt(Instant.parse("2026-03-09T11:00:00Z"));

        when(repository.findSessionsOverlapping(any(), any()))
            .thenReturn(List.of(d1))     // day 1
            .thenReturn(List.of())        // day 2
            .thenReturn(List.of(d3));     // day 3
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        RangeSummaryResponse summary = statsService.getRangeSummary(from, to, UTC, now, 0);

        assertThat(summary.totalTrackedSeconds()).isEqualTo(10800); // 3h
        assertThat(summary.daysWithData()).isEqualTo(2);
        assertThat(summary.avgSecondsPerDay()).isEqualTo(5400);  // 3h / 2 days
        assertThat(summary.avgSecondsPerWeek()).isEqualTo(10800); // 10800 total / 1 week (3 days < 7)
        assertThat(summary.categoryBreakdown()).hasSize(2);
        assertThat(summary.categoryBreakdown().get(0).category()).isEqualTo("Code");
        assertThat(summary.categoryBreakdown().get(0).totalSeconds()).isEqualTo(7200);
    }

    // ── Browser enrichment tests ──

    @Test
    void getCategoryBreakdown_browserSession_splitsByDomainCategory() {
        // A browser session from 10:00 to 10:30
        AppSession browser = new AppSession("Brave Browser", "com.brave.Browser", null,
            Instant.parse("2026-04-09T10:00:00Z"));
        browser.setEndedAt(Instant.parse("2026-04-09T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(browser));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.brave.Browser", "Browsing")
        ));

        // Browser events: github.com for 20 min, youtube.com for 10 min
        BrowserEvent gh = new BrowserEvent("github.com", "PR Review", "https://github.com", "brave",
            Instant.parse("2026-04-09T10:00:00Z"));
        BrowserEvent yt = new BrowserEvent("youtube.com", "Talk", "https://youtube.com", "brave",
            Instant.parse("2026-04-09T10:20:00Z"));
        when(browserEventRepo.findByTimestampBetween(any(), any())).thenReturn(List.of(gh, yt));

        when(domainCategoryRepo.findAll()).thenReturn(List.of(
            new DomainCategoryMapping("github.com", "Code"),
            new DomainCategoryMapping("youtube.com", "Media")
        ));

        LocalDate date = LocalDate.of(2026, 4, 9);
        Instant now = Instant.parse("2026-04-09T12:00:00Z");
        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        // Should have Code (20 min = 1200s) and Media (10 min = 600s)
        assertThat(breakdown).hasSize(2);
        java.util.Map<String, Long> byCat = new java.util.HashMap<>();
        for (var e : breakdown) byCat.put(e.category(), e.totalSeconds());
        assertThat(byCat.get("Code")).isEqualTo(1200);
        assertThat(byCat.get("Media")).isEqualTo(600);
    }

    @Test
    void getCategoryBreakdown_browserSessionWithNoBrowserEvents_staysAsBrowsing() {
        AppSession browser = new AppSession("Chrome", "com.google.Chrome", null,
            Instant.parse("2026-04-09T10:00:00Z"));
        browser.setEndedAt(Instant.parse("2026-04-09T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(browser));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.google.Chrome", "Browsing")
        ));
        when(browserEventRepo.findByTimestampBetween(any(), any())).thenReturn(List.of());

        LocalDate date = LocalDate.of(2026, 4, 9);
        Instant now = Instant.parse("2026-04-09T12:00:00Z");
        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        assertThat(breakdown).hasSize(1);
        assertThat(breakdown.getFirst().category()).isEqualTo("Browsing");
        assertThat(breakdown.getFirst().totalSeconds()).isEqualTo(1800);
    }

    @Test
    void getActivityLog_browserSession_enrichedWithDomainTitle() {
        AppSession browser = new AppSession("Brave Browser", "com.brave.Browser", null,
            Instant.parse("2026-04-09T10:00:00Z"));
        browser.setEndedAt(Instant.parse("2026-04-09T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(browser));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.brave.Browser", "Browsing")
        ));

        BrowserEvent event = new BrowserEvent("github.com", "PR #42", "https://github.com/pull/42", "brave",
            Instant.parse("2026-04-09T10:15:00Z"));
        when(browserEventRepo.findByTimestampBetween(any(), any())).thenReturn(List.of(event));

        LocalDate date = LocalDate.of(2026, 4, 9);
        Instant now = Instant.parse("2026-04-09T12:00:00Z");
        List<ActivityLogEntry> log = statsService.getActivityLog(date, UTC, now, 0);

        assertThat(log).hasSize(1);
        assertThat(log.getFirst().detail()).isEqualTo("github.com — PR #42");
    }

    @Test
    void getCategoryBreakdown_subdomainResolvesToParentDomain() {
        // www.github.com should resolve via github.com mapping
        AppSession browser = new AppSession("Chrome", "com.google.Chrome", null,
            Instant.parse("2026-04-09T10:00:00Z"));
        browser.setEndedAt(Instant.parse("2026-04-09T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(browser));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.google.Chrome", "Browsing")
        ));

        BrowserEvent event = new BrowserEvent("www.github.com", "Repo", "https://www.github.com", "chrome",
            Instant.parse("2026-04-09T10:00:00Z"));
        when(browserEventRepo.findByTimestampBetween(any(), any())).thenReturn(List.of(event));
        when(domainCategoryRepo.findAll()).thenReturn(List.of(
            new DomainCategoryMapping("github.com", "Code")
        ));

        LocalDate date = LocalDate.of(2026, 4, 9);
        Instant now = Instant.parse("2026-04-09T12:00:00Z");
        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        assertThat(breakdown).hasSize(1);
        assertThat(breakdown.getFirst().category()).isEqualTo("Code");
        assertThat(breakdown.getFirst().totalSeconds()).isEqualTo(1800);
    }

    @Test
    void getCategoryBreakdown_unmappedDomainFallsToBrowsing() {
        AppSession browser = new AppSession("Chrome", "com.google.Chrome", null,
            Instant.parse("2026-04-09T10:00:00Z"));
        browser.setEndedAt(Instant.parse("2026-04-09T10:30:00Z"));

        when(repository.findSessionsOverlapping(any(), any())).thenReturn(List.of(browser));
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.google.Chrome", "Browsing")
        ));

        // random-site.xyz is not in domain_category_mappings
        BrowserEvent event = new BrowserEvent("random-site.xyz", "Some page", "https://random-site.xyz", "chrome",
            Instant.parse("2026-04-09T10:00:00Z"));
        when(browserEventRepo.findByTimestampBetween(any(), any())).thenReturn(List.of(event));
        when(domainCategoryRepo.findAll()).thenReturn(List.of(
            new DomainCategoryMapping("github.com", "Code")
        ));

        LocalDate date = LocalDate.of(2026, 4, 9);
        Instant now = Instant.parse("2026-04-09T12:00:00Z");
        List<CategoryBreakdownEntry> breakdown = statsService.getCategoryBreakdown(date, UTC, now, 0);

        assertThat(breakdown).hasSize(1);
        assertThat(breakdown.getFirst().category()).isEqualTo("Browsing");
        assertThat(breakdown.getFirst().totalSeconds()).isEqualTo(1800);
    }
}
