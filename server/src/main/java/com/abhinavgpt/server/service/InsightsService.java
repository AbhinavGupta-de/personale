package com.abhinavgpt.server.service;

import com.abhinavgpt.server.domain.MergedBlock;
import com.abhinavgpt.server.dto.CategoryBreakdownEntry;
import com.abhinavgpt.server.dto.InsightsOverviewResponse;
import com.abhinavgpt.server.dto.InsightsOverviewResponse.*;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.springframework.stereotype.Service;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Self-knowledge layer. Aggregates raw sessions over a date range into the
 * cards shown on the Insights page. Single fetch from the repos, all the
 * cuts computed in-memory — keeps a 30d range under one DB roundtrip per
 * call and lets us reuse `SessionMergeService` for the focus-block math.
 *
 * Productive vs distraction is decided by `CategoryThreshold.focus`. Browser
 * sessions are bucketed by their bundle category here (i.e., everything
 * branded "Browsing"). Per-domain re-categorization lives in
 * `SessionMergeService` and is used only for the "longest focus blocks" card.
 */
@Service
public class InsightsService {

    /** Default productive-day threshold for streaks (4 hours). */
    private static final int DEFAULT_STREAK_THRESHOLD_SECONDS = 4 * 3600;

    /// Cap for "longest focus block" — anything beyond 6h is almost certainly an
    /// orphaned session (process died without emitting an end event) rather than
    /// a legit deep-work window. Filter these out so the card shows real signal.
    private static final long LONGEST_FOCUS_MAX_SECONDS = 6 * 3600;

    private final AppSessionRepository sessionRepo;
    private final BrowserEventRepository browserEventRepo;
    private final CategoryResolver categoryResolver;
    private final CategoryThresholdRepository thresholdRepo;
    private final SessionMergeService mergeService;

    public InsightsService(AppSessionRepository sessionRepo,
                           BrowserEventRepository browserEventRepo,
                           CategoryResolver categoryResolver,
                           CategoryThresholdRepository thresholdRepo,
                           SessionMergeService mergeService) {
        this.sessionRepo = sessionRepo;
        this.browserEventRepo = browserEventRepo;
        this.categoryResolver = categoryResolver;
        this.thresholdRepo = thresholdRepo;
        this.mergeService = mergeService;
    }

    public InsightsOverviewResponse getOverview(LocalDate from, LocalDate to,
                                                ZoneId zone, Instant now, int dayStartHour) {
        int shift = Math.max(0, Math.min(23, dayStartHour));
        Instant rangeStart = from.atStartOfDay(zone).plusHours(shift).toInstant();
        Instant rangeEnd = to.plusDays(1).atStartOfDay(zone).plusHours(shift).toInstant();

        List<AppSession> allSessions = sessionRepo.findSessionsOverlapping(rangeStart, rangeEnd);
        List<BrowserEvent> allBrowserEvents = browserEventRepo.findByTimestampBetween(rangeStart, rangeEnd);

        Set<String> productiveCats = productiveCategoryNames();

        // 1. Heatmap (weekday × hour).
        long[][] prodGrid = new long[7][24];
        long[][] totalGrid = new long[7][24];
        for (AppSession s : allSessions) {
            String cat = categoryResolver.categoryForBundle(s.getBundleId());
            boolean productive = productiveCats.contains(cat);
            sliceIntoHourCells(s, rangeStart, rangeEnd, now, zone, productive,
                prodGrid, totalGrid);
        }
        List<HeatmapCell> heatmap = new ArrayList<>(7 * 24);
        for (int d = 0; d < 7; d++) {
            for (int h = 0; h < 24; h++) {
                heatmap.add(new HeatmapCell(d + 1, h, prodGrid[d][h], totalGrid[d][h]));
            }
        }

        // 2. Per-day aggregates → trends + day-of-week ranking + streaks.
        List<DailyTrendPoint> dailyTrend = new ArrayList<>();
        long totalProd = 0, totalTrack = 0, totalSwitches = 0;
        int daysWithData = 0;

        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm").withZone(zone);
        List<LongestFocusEntry> longest = new ArrayList<>();

        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            Instant dayStart = d.atStartOfDay(zone).plusHours(shift).toInstant();
            Instant dayEnd = d.plusDays(1).atStartOfDay(zone).plusHours(shift).toInstant();

            List<AppSession> daySessions = filterOverlapping(allSessions, dayStart, dayEnd);
            List<BrowserEvent> dayBe = allBrowserEvents.stream()
                .filter(e -> !e.getTimestamp().isBefore(dayStart) && e.getTimestamp().isBefore(dayEnd))
                .toList();

            DayAgg agg = aggregateDay(daySessions, dayStart, dayEnd, now, productiveCats);
            dailyTrend.add(new DailyTrendPoint(
                d.toString(), agg.productive, agg.total, agg.switches, agg.sessionCount,
                agg.sessionCount > 0 ? (int) (agg.total / agg.sessionCount) : 0));

            if (agg.total > 0) daysWithData++;
            totalProd += agg.productive;
            totalTrack += agg.total;
            totalSwitches += agg.switches;

            for (MergedBlock b : mergeService.buildMergedBlocks(
                    daySessions, dayStart, dayEnd, now, dayBe)) {
                if (!productiveCats.contains(b.category())) continue;
                if (b.seconds() > LONGEST_FOCUS_MAX_SECONDS) continue;
                longest.add(new LongestFocusEntry(
                    d.toString(),
                    timeFmt.format(b.start()),
                    timeFmt.format(b.end()),
                    b.seconds(),
                    b.category(),
                    b.label()));
            }
        }

        // 3. Day-of-week ranking — average across days that had data.
        Map<Integer, long[]> dowAgg = new TreeMap<>();
        for (int i = 0; i < dailyTrend.size(); i++) {
            LocalDate d = from.plusDays(i);
            DailyTrendPoint p = dailyTrend.get(i);
            if (p.totalSeconds() == 0) continue;
            int dow = d.getDayOfWeek().getValue();
            long[] a = dowAgg.computeIfAbsent(dow, k -> new long[3]);
            a[0] += p.productiveSeconds();
            a[1] += p.totalSeconds();
            a[2] += 1;
        }
        List<DayOfWeekStat> dowList = new ArrayList<>(7);
        for (int i = 1; i <= 7; i++) {
            long[] a = dowAgg.getOrDefault(i, new long[3]);
            int days = (int) a[2];
            dowList.add(new DayOfWeekStat(i,
                days > 0 ? a[0] / days : 0,
                days > 0 ? a[1] / days : 0,
                days));
        }

        // 4. Top distractions — last 7 days inside the range, non-productive cats.
        LocalDate distFrom = to.minusDays(6);
        if (distFrom.isBefore(from)) distFrom = from;
        Instant distStart = distFrom.atStartOfDay(zone).plusHours(shift).toInstant();
        List<DistractionEntry> distractions = topDistractions(
            allSessions, distStart, rangeEnd, now, productiveCats);

        // 5. Longest focus blocks — top 5 by duration.
        longest.sort((a, b) -> Long.compare(b.durationSeconds(), a.durationSeconds()));
        List<LongestFocusEntry> top5 = longest.stream().limit(5).toList();

        // 6. Category breakdown — current range + same-length prior period.
        List<CategoryBreakdownEntry> catCurrent = categoryBreakdownForRange(
            from, to, zone, now, shift);
        long days = to.toEpochDay() - from.toEpochDay() + 1;
        LocalDate priorTo = from.minusDays(1);
        LocalDate priorFrom = priorTo.minusDays(days - 1);
        List<CategoryBreakdownEntry> catPrior = categoryBreakdownForRange(
            priorFrom, priorTo, zone, now, shift);

        // 7. Streaks — uses daily productive seconds.
        int currentStreak = 0;
        for (int i = dailyTrend.size() - 1; i >= 0; i--) {
            if (dailyTrend.get(i).productiveSeconds() >= DEFAULT_STREAK_THRESHOLD_SECONDS) currentStreak++;
            else break;
        }
        int longestStreak = 0, run = 0;
        for (DailyTrendPoint p : dailyTrend) {
            if (p.productiveSeconds() >= DEFAULT_STREAK_THRESHOLD_SECONDS) {
                run++;
                if (run > longestStreak) longestStreak = run;
            } else { run = 0; }
        }

        return new InsightsOverviewResponse(
            from.toString(), to.toString(),
            daysWithData, totalTrack, totalProd, totalSwitches,
            heatmap, dowList, dailyTrend,
            distractions, top5,
            catCurrent, catPrior,
            new StreakStats(currentStreak, longestStreak, DEFAULT_STREAK_THRESHOLD_SECONDS));
    }

    // ── helpers ──

    private record DayAgg(long productive, long total, int switches, int sessionCount) {}

    private DayAgg aggregateDay(List<AppSession> daySessions, Instant dayStart, Instant dayEnd,
                                Instant now, Set<String> productiveCats) {
        long prod = 0, total = 0;
        int switches = 0, sessionCount = 0;
        String prevKey = null;
        List<AppSession> sorted = daySessions.stream()
            .sorted(Comparator.comparing(AppSession::getStartedAt))
            .toList();
        for (AppSession s : sorted) {
            Instant effStart = SessionMergeService.effectiveStart(s, dayStart);
            Instant effEnd = SessionMergeService.effectiveEnd(s, dayEnd, now);
            long secs = Duration.between(effStart, effEnd).getSeconds();
            if (secs <= 0) continue;
            total += secs;
            if (productiveCats.contains(categoryResolver.categoryForBundle(s.getBundleId()))) {
                prod += secs;
            }
            sessionCount++;
            String key = s.getBundleId();
            if (key != null) {
                if (prevKey != null && !prevKey.equals(key)) switches++;
                prevKey = key;
            }
        }
        return new DayAgg(prod, total, switches, sessionCount);
    }

    /// Slice a session into hour cells aligned to the user's zone, attributing
    /// the time to the (weekday, hour) bucket the slice falls in. Walks hour
    /// boundaries so a 90-min Slack session at 10:30 contributes 30 min to 10:00
    /// and 60 min to 11:00 — not all to 10:00.
    private void sliceIntoHourCells(AppSession s, Instant rangeStart, Instant rangeEnd,
                                    Instant now, ZoneId zone, boolean productive,
                                    long[][] prodGrid, long[][] totalGrid) {
        Instant effStart = SessionMergeService.effectiveStart(s, rangeStart);
        Instant effEnd = SessionMergeService.effectiveEnd(s, rangeEnd, now);
        if (!effEnd.isAfter(effStart)) return;
        Instant cur = effStart;
        // Cap at 100 slices to bound any pathological runaway session.
        int safety = 100;
        while (cur.isBefore(effEnd) && safety-- > 0) {
            ZonedDateTime z = cur.atZone(zone);
            ZonedDateTime nextHour = z.plusHours(1).withMinute(0).withSecond(0).withNano(0);
            Instant sliceEnd = nextHour.toInstant();
            if (sliceEnd.isAfter(effEnd)) sliceEnd = effEnd;
            long secs = Duration.between(cur, sliceEnd).getSeconds();
            if (secs > 0) {
                int hour = z.getHour();
                int dow = z.getDayOfWeek().getValue() - 1;
                totalGrid[dow][hour] += secs;
                if (productive) prodGrid[dow][hour] += secs;
            }
            cur = sliceEnd;
        }
    }

    private List<AppSession> filterOverlapping(List<AppSession> sessions, Instant start, Instant end) {
        return sessions.stream()
            .filter(s -> s.getStartedAt().isBefore(end)
                && (s.getEndedAt() == null || s.getEndedAt().isAfter(start)))
            .toList();
    }

    private List<DistractionEntry> topDistractions(List<AppSession> allSessions,
                                                   Instant from, Instant to,
                                                   Instant now, Set<String> productiveCats) {
        Map<String, long[]> agg = new LinkedHashMap<>();
        Map<String, String> nameByKey = new LinkedHashMap<>();
        Map<String, String> bundleByKey = new LinkedHashMap<>();
        Map<String, String> catByKey = new LinkedHashMap<>();
        for (AppSession s : allSessions) {
            if (s.getStartedAt().compareTo(to) >= 0) continue;
            if (s.getEndedAt() != null && s.getEndedAt().compareTo(from) <= 0) continue;
            Instant effStart = SessionMergeService.effectiveStart(s, from);
            Instant effEnd = SessionMergeService.effectiveEnd(s, to, now);
            long secs = Duration.between(effStart, effEnd).getSeconds();
            if (secs <= 0) continue;
            String cat = categoryResolver.categoryForBundle(s.getBundleId());
            if (productiveCats.contains(cat)) continue;
            String key = s.getBundleId() != null ? s.getBundleId() : s.getAppName();
            long[] a = agg.computeIfAbsent(key, k -> new long[2]);
            a[0] += secs;
            a[1] += 1;
            nameByKey.putIfAbsent(key, s.getAppName());
            bundleByKey.putIfAbsent(key, s.getBundleId());
            catByKey.putIfAbsent(key, cat);
        }
        return agg.entrySet().stream()
            .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
            .limit(10)
            .map(e -> new DistractionEntry(
                nameByKey.get(e.getKey()),
                bundleByKey.get(e.getKey()),
                catByKey.get(e.getKey()),
                e.getValue()[0],
                (int) e.getValue()[1]))
            .toList();
    }

    private List<CategoryBreakdownEntry> categoryBreakdownForRange(LocalDate from, LocalDate to,
                                                                   ZoneId zone, Instant now, int shift) {
        Instant start = from.atStartOfDay(zone).plusHours(shift).toInstant();
        Instant end = to.plusDays(1).atStartOfDay(zone).plusHours(shift).toInstant();
        List<AppSession> sess = sessionRepo.findSessionsOverlapping(start, end);

        Map<String, Long> byCat = new LinkedHashMap<>();
        for (AppSession s : sess) {
            Instant effStart = SessionMergeService.effectiveStart(s, start);
            Instant effEnd = SessionMergeService.effectiveEnd(s, end, now);
            long secs = Duration.between(effStart, effEnd).getSeconds();
            if (secs <= 0) continue;
            byCat.merge(categoryResolver.categoryForBundle(s.getBundleId()), secs, Long::sum);
        }
        long total = byCat.values().stream().mapToLong(Long::longValue).sum();
        return byCat.entrySet().stream()
            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
            .map(e -> new CategoryBreakdownEntry(
                e.getKey(), e.getValue(),
                total > 0 ? (int) Math.round(e.getValue() * 100.0 / total) : 0))
            .toList();
    }

    /**
     * Categories with focus=true are "productive". If thresholds aren't seeded
     * yet (fresh install) we fall back to a sensible default so the page isn't
     * blank before the user opens settings.
     */
    private Set<String> productiveCategoryNames() {
        Set<String> out = new HashSet<>();
        for (CategoryThreshold t : thresholdRepo.findAll()) {
            if (t.isFocus()) out.add(t.getCategory());
        }
        if (out.isEmpty()) {
            out.add("Code");
            out.add("Coding");
            out.add("Design");
            out.add("Writing");
            out.add("Reading");
        }
        return out;
    }
}
