package com.abhinavgpt.server.service;

import com.abhinavgpt.server.domain.AppUsage;
import com.abhinavgpt.server.domain.DomainUsage;
import com.abhinavgpt.server.domain.MergedBlock;
import com.abhinavgpt.server.dto.*;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import org.springframework.stereotype.Service;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Thin orchestration layer: fetches raw data, hands it to the focused
 * services (merge, domain-time, category resolver) and shapes the result
 * into DTOs for the controller. No algorithm lives here.
 */
@Service
public class StatsService {

    private final AppSessionRepository sessionRepo;
    private final BrowserEventRepository browserEventRepo;
    private final CategoryResolver categoryResolver;
    private final SessionMergeService mergeService;
    private final DomainTimeService domainTimeService;

    public StatsService(AppSessionRepository sessionRepo,
                        BrowserEventRepository browserEventRepo,
                        CategoryResolver categoryResolver,
                        SessionMergeService mergeService,
                        DomainTimeService domainTimeService) {
        this.sessionRepo = sessionRepo;
        this.browserEventRepo = browserEventRepo;
        this.categoryResolver = categoryResolver;
        this.mergeService = mergeService;
        this.domainTimeService = domainTimeService;
    }

    // ── Day context ──

    private record DayContext(LocalDate date, Instant startOfDay, Instant endOfDay,
                              List<AppSession> sessions) {}

    private DayContext loadDay(LocalDate date, ZoneId zone) {
        Instant startOfDay = date.atStartOfDay(zone).toInstant();
        Instant endOfDay = date.plusDays(1).atStartOfDay(zone).toInstant();
        List<AppSession> sessions = sessionRepo.findSessionsOverlapping(startOfDay, endOfDay);
        return new DayContext(date, startOfDay, endOfDay, sessions);
    }

    private List<MergedBlock> mergedBlocks(DayContext ctx, Instant now) {
        List<BrowserEvent> events = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());
        return mergeService.buildMergedBlocks(
            ctx.sessions(), ctx.startOfDay(), ctx.endOfDay(), now, events);
    }

    // ── Daily per-app totals ──

    public DailyStatsResponse getTimePerApp(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);

        Map<String, long[]> timeByBundle = new LinkedHashMap<>();
        Map<String, String> nameByBundle = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            String key = session.getBundleId() != null ? session.getBundleId() : session.getAppName();
            Instant effStart = SessionMergeService.effectiveStart(session, ctx.startOfDay());
            Instant effEnd = SessionMergeService.effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());

            timeByBundle.computeIfAbsent(key, k -> new long[1])[0] += seconds;
            nameByBundle.putIfAbsent(key, session.getAppName());
        }

        List<AppTimeEntry> apps = timeByBundle.entrySet().stream()
            .map(e -> {
                String bundleId = e.getKey().equals(nameByBundle.get(e.getKey())) ? null : e.getKey();
                return new AppTimeEntry(nameByBundle.get(e.getKey()), bundleId, e.getValue()[0]);
            })
            .sorted(Comparator.comparingLong(AppTimeEntry::totalSeconds).reversed())
            .toList();

        long total = apps.stream().mapToLong(AppTimeEntry::totalSeconds).sum();
        long idleCount = ctx.sessions().stream()
            .filter(s -> s.getEndedAt() != null && !s.getEndedAt().isAfter(s.getStartedAt()))
            .count();

        return new DailyStatsResponse(ctx.date().toString(), apps, total, idleCount);
    }

    public DailyStatsResponse getTimePerAppToday(ZoneId zone, Instant now) {
        return getTimePerApp(LocalDate.ofInstant(now, zone), zone, now);
    }

    // ── Timeline ──

    public List<TimelineEntry> getTimeline(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm").withZone(zone);

        return mergedBlocks(ctx, now).stream()
            .map(block -> new TimelineEntry(
                timeFmt.format(block.start()),
                timeFmt.format(block.end()),
                block.label(),
                null,
                block.category()))
            .toList();
    }

    // ── Activity log ──

    public List<ActivityLogEntry> getActivityLog(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm:ss").withZone(zone);
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        return ctx.sessions().stream()
            .filter(s -> {
                Instant effEnd = SessionMergeService.effectiveEnd(s, ctx.endOfDay(), now);
                return Duration.between(
                    SessionMergeService.effectiveStart(s, ctx.startOfDay()), effEnd).getSeconds() > 0;
            })
            .sorted(Comparator.comparing(AppSession::getStartedAt))
            .map(s -> toActivityEntry(s, ctx, now, timeFmt, browserEvents))
            .toList();
    }

    private ActivityLogEntry toActivityEntry(AppSession s, DayContext ctx, Instant now,
                                             DateTimeFormatter timeFmt,
                                             List<BrowserEvent> browserEvents) {
        Instant effStart = SessionMergeService.effectiveStart(s, ctx.startOfDay());
        Instant effEnd = SessionMergeService.effectiveEnd(s, ctx.endOfDay(), now);
        long secs = Duration.between(effStart, effEnd).getSeconds();
        String detail = s.getWindowTitle() != null
            ? s.getWindowTitle()
            : categoryResolver.categoryForBundle(s.getBundleId());

        if (categoryResolver.isBrowserBundle(s.getBundleId()) && !browserEvents.isEmpty()) {
            BrowserEvent latest = browserEvents.stream()
                .filter(e -> !e.getTimestamp().isBefore(effStart) && e.getTimestamp().isBefore(effEnd))
                .max(Comparator.comparing(BrowserEvent::getTimestamp))
                .orElse(null);
            if (latest != null) {
                detail = latest.getDomain()
                    + (latest.getTitle() != null ? " — " + latest.getTitle() : "");
            }
        }

        return new ActivityLogEntry(
            timeFmt.format(effStart), s.getAppName(), s.getBundleId(), detail, secs);
    }

    // ── Workblocks ──

    public List<WorkblockEntry> getWorkblocks(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("H:mm").withZone(zone);

        return mergedBlocks(ctx, now).stream()
            .map(block -> new WorkblockEntry(
                timeFmt.format(block.start()),
                block.category(),
                formatDuration(block.seconds()),
                block.seconds()))
            .toList();
    }

    // ── Focus sessions (merged blocks with per-app + top-domain detail) ──

    public List<FocusSessionEntry> getFocusSessions(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm").withZone(zone);
        List<BrowserEvent> dayBrowserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        return mergeService
            .buildMergedBlocks(ctx.sessions(), ctx.startOfDay(), ctx.endOfDay(), now, dayBrowserEvents)
            .stream()
            .map(block -> toFocusSession(block, timeFmt, dayBrowserEvents))
            .toList();
    }

    private FocusSessionEntry toFocusSession(MergedBlock block,
                                             DateTimeFormatter timeFmt,
                                             List<BrowserEvent> dayBrowserEvents) {
        // Aggregate constituents by bundle id (or app name if no bundle)
        Map<String, long[]> appTime = new LinkedHashMap<>();
        Map<String, String> appBundle = new LinkedHashMap<>();
        Map<String, String> appCategory = new LinkedHashMap<>();
        Map<String, String> appDisplayName = new LinkedHashMap<>();

        for (AppUsage u : block.constituents()) {
            String key = u.bundleId() != null ? u.bundleId() : u.appName();
            appTime.computeIfAbsent(key, k -> new long[1])[0] += u.seconds();
            appBundle.putIfAbsent(key, u.bundleId());
            appCategory.putIfAbsent(key, u.category());
            appDisplayName.putIfAbsent(key, u.appName());
        }

        List<SessionAppBreakdown> apps = appTime.entrySet().stream()
            .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
            .map(e -> {
                long secs = e.getValue()[0];
                int pct = block.seconds() > 0 ? (int) Math.round(secs * 100.0 / block.seconds()) : 0;
                return new SessionAppBreakdown(
                    appDisplayName.get(e.getKey()),
                    appBundle.get(e.getKey()),
                    appCategory.get(e.getKey()),
                    secs, pct, List.of());
            })
            .toList();

        // Per-category within block
        Map<String, Long> catTime = new LinkedHashMap<>();
        for (AppUsage u : block.constituents()) {
            catTime.merge(u.category(), u.seconds(), Long::sum);
        }
        List<CategoryBreakdownEntry> categories = catTime.entrySet().stream()
            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
            .map(e -> new CategoryBreakdownEntry(
                e.getKey(), e.getValue(),
                block.seconds() > 0 ? (int) Math.round(e.getValue() * 100.0 / block.seconds()) : 0))
            .toList();

        // Top domains once per session (only if a browser was involved)
        List<SessionAppBreakdown.DomainTime> topDomains = List.of();
        boolean hasBrowser = apps.stream().anyMatch(a -> categoryResolver.isBrowserBundle(a.bundleId()));
        if (hasBrowser && !dayBrowserEvents.isEmpty()) {
            topDomains = domainTimeService
                .topDomainsInWindow(block.start(), block.end(), dayBrowserEvents, 8)
                .stream()
                .map(d -> new SessionAppBreakdown.DomainTime(d.domain(), d.seconds()))
                .toList();
        }

        return new FocusSessionEntry(
            block.category(),
            timeFmt.format(block.start()),
            timeFmt.format(block.end()),
            block.seconds(),
            formatDuration(block.seconds()),
            apps,
            categories,
            topDomains);
    }

    // ── Category breakdown ──

    public List<CategoryBreakdownEntry> getCategoryBreakdown(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        Map<String, Long> timeByCategory = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            Instant effStart = SessionMergeService.effectiveStart(session, ctx.startOfDay());
            Instant effEnd = SessionMergeService.effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
            if (seconds == 0) continue;

            if (categoryResolver.isBrowserBundle(session.getBundleId()) && !browserEvents.isEmpty()) {
                Map<String, Long> byCategory = domainTimeService.secondsPerDomainCategory(
                    effStart, effEnd, browserEvents);
                if (!byCategory.isEmpty()) {
                    long accounted = 0;
                    for (var entry : byCategory.entrySet()) {
                        timeByCategory.merge(entry.getKey(), entry.getValue(), Long::sum);
                        accounted += entry.getValue();
                    }
                    long remainder = seconds - accounted;
                    if (remainder > 0) {
                        timeByCategory.merge("Browsing", remainder, Long::sum);
                    }
                } else {
                    timeByCategory.merge("Browsing", seconds, Long::sum);
                }
            } else {
                String category = categoryResolver.categoryForBundle(session.getBundleId());
                timeByCategory.merge(category, seconds, Long::sum);
            }
        }

        long total = timeByCategory.values().stream().mapToLong(Long::longValue).sum();
        return timeByCategory.entrySet().stream()
            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
            .map(e -> new CategoryBreakdownEntry(
                e.getKey(), e.getValue(),
                total > 0 ? (int) Math.round(e.getValue() * 100.0 / total) : 0))
            .toList();
    }

    // ── Domain stats: per-category with app + domain sources ──

    public DomainStatsResponse getDomainStats(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = loadDay(date, zone);
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        Map<String, Map<String, long[]>> catSources = new LinkedHashMap<>();
        Map<String, Map<String, String>> catSourceTypes = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            Instant effStart = SessionMergeService.effectiveStart(session, ctx.startOfDay());
            Instant effEnd = SessionMergeService.effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
            if (seconds == 0) continue;

            if (categoryResolver.isBrowserBundle(session.getBundleId()) && !browserEvents.isEmpty()) {
                Map<String, Long> perDomain = domainTimeService.secondsPerDomain(
                    effStart, effEnd, browserEvents);
                long accounted = 0;
                for (var entry : perDomain.entrySet()) {
                    String cat = categoryResolver.categoryForDomain(entry.getKey());
                    catSources.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                        .computeIfAbsent(entry.getKey(), k -> new long[1])[0] += entry.getValue();
                    catSourceTypes.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                        .putIfAbsent(entry.getKey(), "domain");
                    accounted += entry.getValue();
                }
                long remainder = seconds - accounted;
                if (remainder > 0) {
                    catSources.computeIfAbsent("Browsing", k -> new LinkedHashMap<>())
                        .computeIfAbsent("(other browsing)", k -> new long[1])[0] += remainder;
                    catSourceTypes.computeIfAbsent("Browsing", k -> new LinkedHashMap<>())
                        .putIfAbsent("(other browsing)", "domain");
                }
            } else {
                String cat = categoryResolver.categoryForBundle(session.getBundleId());
                String appName = session.getAppName();
                catSources.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                    .computeIfAbsent(appName, k -> new long[1])[0] += seconds;
                catSourceTypes.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                    .putIfAbsent(appName, "app");
            }
        }

        List<DomainStatsResponse.CategoryDetail> details = catSources.entrySet().stream()
            .sorted((a, b) -> {
                long aTotal = a.getValue().values().stream().mapToLong(v -> v[0]).sum();
                long bTotal = b.getValue().values().stream().mapToLong(v -> v[0]).sum();
                return Long.compare(bTotal, aTotal);
            })
            .map(catEntry -> {
                String cat = catEntry.getKey();
                long catTotal = catEntry.getValue().values().stream().mapToLong(v -> v[0]).sum();
                List<DomainStatsResponse.Source> sources = catEntry.getValue().entrySet().stream()
                    .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
                    .map(e -> new DomainStatsResponse.Source(
                        e.getKey(),
                        catSourceTypes.getOrDefault(cat, Map.of()).getOrDefault(e.getKey(), "app"),
                        e.getValue()[0]))
                    .toList();
                return new DomainStatsResponse.CategoryDetail(cat, catTotal, sources);
            })
            .toList();

        return new DomainStatsResponse(details);
    }

    // ── Range queries ──

    public RangeResponse getRange(LocalDate from, LocalDate to, ZoneId zone, Instant now) {
        List<RangeDayBreakdown> days = new ArrayList<>();

        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            DayContext ctx = loadDay(date, zone);

            Map<String, Long> timeByCategory = new LinkedHashMap<>();
            for (AppSession session : ctx.sessions()) {
                Instant effStart = SessionMergeService.effectiveStart(session, ctx.startOfDay());
                Instant effEnd = SessionMergeService.effectiveEnd(session, ctx.endOfDay(), now);
                long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
                if (seconds == 0) continue;
                timeByCategory.merge(
                    categoryResolver.categoryForBundle(session.getBundleId()),
                    seconds, Long::sum);
            }

            long dayTotal = timeByCategory.values().stream().mapToLong(Long::longValue).sum();
            List<RangeDayBreakdown.CategorySeconds> cats = timeByCategory.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .map(e -> new RangeDayBreakdown.CategorySeconds(e.getKey(), e.getValue()))
                .toList();

            days.add(new RangeDayBreakdown(date.toString(), dayTotal, cats));
        }

        return new RangeResponse(from.toString(), to.toString(), days);
    }

    public RangeSummaryResponse getRangeSummary(LocalDate from, LocalDate to, ZoneId zone, Instant now) {
        RangeResponse range = getRange(from, to, zone, now);

        long totalTracked = 0;
        int daysWithData = 0;
        Map<String, Long> totalByCategory = new LinkedHashMap<>();

        for (RangeDayBreakdown day : range.days()) {
            if (day.totalTrackedSeconds() > 0) {
                daysWithData++;
                totalTracked += day.totalTrackedSeconds();
                for (RangeDayBreakdown.CategorySeconds cs : day.categories()) {
                    totalByCategory.merge(cs.category(), cs.seconds(), Long::sum);
                }
            }
        }

        final long total = totalTracked;
        long avgPerDay = daysWithData > 0 ? total / daysWithData : 0;
        int daysInRange = (int) (to.toEpochDay() - from.toEpochDay()) + 1;
        double weeksInRange = Math.max(1.0, daysInRange / 7.0);
        long avgPerWeek = Math.round(total / weeksInRange);

        List<CategoryBreakdownEntry> breakdown = totalByCategory.entrySet().stream()
            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
            .map(e -> new CategoryBreakdownEntry(
                e.getKey(), e.getValue(),
                total > 0 ? (int) Math.round(e.getValue() * 100.0 / total) : 0))
            .toList();

        return new RangeSummaryResponse(
            from.toString(), to.toString(),
            total, daysWithData, avgPerDay, avgPerWeek, breakdown);
    }

    // ── Formatting ──

    private String formatDuration(long totalSeconds) {
        long hours = totalSeconds / 3600;
        long minutes = (totalSeconds % 3600) / 60;
        return hours > 0 ? hours + " hr " + minutes + " min" : minutes + " min";
    }
}
