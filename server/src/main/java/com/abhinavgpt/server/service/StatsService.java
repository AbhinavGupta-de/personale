package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.*;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import com.abhinavgpt.server.repository.DomainCategoryMappingRepository;
import org.springframework.stereotype.Service;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
public class StatsService {

    private final AppSessionRepository repository;
    private final CategoryMappingRepository categoryRepo;
    private final BrowserEventRepository browserEventRepo;
    private final DomainCategoryMappingRepository domainCategoryRepo;

    // In-memory cache of bundle_id → category with TTL-based refresh
    private Map<String, String> categoryCache;
    private Map<String, String> domainCategoryCache;
    private Instant lastCacheLoad;
    private Instant lastDomainCacheLoad;
    private static final Duration CACHE_TTL = Duration.ofMinutes(5);

    public StatsService(AppSessionRepository repository, CategoryMappingRepository categoryRepo,
                        BrowserEventRepository browserEventRepo,
                        DomainCategoryMappingRepository domainCategoryRepo) {
        this.repository = repository;
        this.categoryRepo = categoryRepo;
        this.browserEventRepo = browserEventRepo;
        this.domainCategoryRepo = domainCategoryRepo;
    }

    private Map<String, String> getCategoryCache() {
        if (categoryCache == null || lastCacheLoad == null
                || Instant.now().isAfter(lastCacheLoad.plus(CACHE_TTL))) {
            categoryCache = new HashMap<>();
            categoryRepo.findAll().forEach(m -> categoryCache.put(m.getBundleId(), m.getCategory()));
            lastCacheLoad = Instant.now();
        }
        return categoryCache;
    }

    private Map<String, String> getDomainCategoryCache() {
        if (domainCategoryCache == null || lastDomainCacheLoad == null
                || Instant.now().isAfter(lastDomainCacheLoad.plus(CACHE_TTL))) {
            domainCategoryCache = new HashMap<>();
            domainCategoryRepo.findAll().forEach(m -> domainCategoryCache.put(m.getDomain(), m.getCategory()));
            lastDomainCacheLoad = Instant.now();
        }
        return domainCategoryCache;
    }

    private String resolveCategory(String bundleId) {
        if (bundleId == null) return "Other";
        return getCategoryCache().getOrDefault(bundleId, "Other");
    }

    private String resolveDomainCategory(String domain) {
        if (domain == null) return "Browsing";
        // Try exact match first, then strip subdomain
        Map<String, String> cache = getDomainCategoryCache();
        String cat = cache.get(domain);
        if (cat != null) return cat;
        // Try without subdomain (e.g. "www.github.com" → "github.com")
        int dot = domain.indexOf('.');
        if (dot > 0 && domain.indexOf('.', dot + 1) > 0) {
            cat = cache.get(domain.substring(dot + 1));
            if (cat != null) return cat;
        }
        return "Browsing";
    }

    private boolean isBrowserBundle(String bundleId) {
        return "Browsing".equals(resolveCategory(bundleId));
    }

    // Sessions shorter than this are absorbed into their neighbor's focus block
    private static final long MERGE_THRESHOLD_SECONDS = 300; // 5 minutes

    // Idle gap longer than this splits sessions apart (10 min gap + 2 min idle detection ≈ 12 min real idle)
    private static final long GAP_THRESHOLD_SECONDS = 600; // 10 minutes

    // Shared helper: get day boundaries and overlapping sessions
    private record DayContext(LocalDate date, Instant startOfDay, Instant endOfDay, List<AppSession> sessions) {}

    private DayContext dayContext(LocalDate date, ZoneId zone, Instant now) {
        Instant startOfDay = date.atStartOfDay(zone).toInstant();
        Instant endOfDay = date.plusDays(1).atStartOfDay(zone).toInstant();
        List<AppSession> sessions = repository.findSessionsOverlapping(startOfDay, endOfDay);
        return new DayContext(date, startOfDay, endOfDay, sessions);
    }

    // Clamp session to day window, using 'now' for active sessions
    private Instant effectiveStart(AppSession session, Instant startOfDay) {
        return session.getStartedAt().isBefore(startOfDay) ? startOfDay : session.getStartedAt();
    }

    private Instant effectiveEnd(AppSession session, Instant endOfDay, Instant now) {
        Instant end = session.getEndedAt() != null ? session.getEndedAt() : now;
        return end.isAfter(endOfDay) ? endOfDay : end;
    }

    // ── Existing: daily stats (generalized to any date) ──

    public DailyStatsResponse getTimePerApp(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);

        Map<String, long[]> timeByBundle = new LinkedHashMap<>();
        Map<String, String> nameByBundle = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            String key = session.getBundleId() != null ? session.getBundleId() : session.getAppName();
            Instant effStart = effectiveStart(session, ctx.startOfDay());
            Instant effEnd = effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());

            timeByBundle.computeIfAbsent(key, k -> new long[1]);
            timeByBundle.get(key)[0] += seconds;
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

    // Keep backwards-compatible method
    public DailyStatsResponse getTimePerAppToday(ZoneId zone, Instant now) {
        return getTimePerApp(LocalDate.ofInstant(now, zone), zone, now);
    }

    // ── Focus session merging: builds bigger blocks from raw app switches ──

    private record Constituent(String appName, String bundleId, String category, long seconds) {}

    private record MergedBlock(String category, Instant start, Instant end, long seconds,
                               String label, List<Constituent> constituents) {}

    /**
     * Build merged focus sessions from raw app sessions.
     * 1. Convert sessions to category-tagged blocks (tracking constituents)
     * 2. Merge consecutive same-category blocks
     * 3. Absorb brief interruptions (< threshold) into neighbors
     * 4. Re-merge any adjacent same-category blocks created by absorption
     */
    private List<MergedBlock> buildMergedSessions(DayContext ctx, Instant now) {
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        List<MergedBlock> raw = ctx.sessions().stream()
            .filter(s -> {
                Instant effEnd = effectiveEnd(s, ctx.endOfDay(), now);
                return Duration.between(effectiveStart(s, ctx.startOfDay()), effEnd).getSeconds() > 0;
            })
            .sorted(Comparator.comparing(AppSession::getStartedAt))
            .map(s -> {
                Instant effStart = effectiveStart(s, ctx.startOfDay());
                Instant effEnd = effectiveEnd(s, ctx.endOfDay(), now);
                long secs = Duration.between(effStart, effEnd).getSeconds();
                String cat = resolveCategory(s.getBundleId());

                // For browser sessions, use dominant domain category instead of "Browsing"
                if (isBrowserBundle(s.getBundleId()) && !browserEvents.isEmpty()) {
                    Map<String, Long> domainTime = splitBrowserSessionByDomain(effStart, effEnd, browserEvents);
                    if (!domainTime.isEmpty()) {
                        cat = domainTime.entrySet().stream()
                            .max(Map.Entry.comparingByValue())
                            .map(Map.Entry::getKey).orElse(cat);
                    }
                }

                return new MergedBlock(cat, effStart, effEnd, secs, s.getAppName(),
                    List.of(new Constituent(s.getAppName(), s.getBundleId(), cat, secs)));
            })
            .toList();

        if (raw.size() <= 1) return raw;

        List<MergedBlock> merged = mergeAdjacentSameCategory(raw);
        merged = absorbSmallBlocks(merged);
        return mergeAdjacentSameCategory(merged);
    }

    private List<MergedBlock> mergeAdjacentSameCategory(List<MergedBlock> blocks) {
        if (blocks.isEmpty()) return blocks;
        List<MergedBlock> result = new ArrayList<>();
        MergedBlock current = blocks.getFirst();
        for (int i = 1; i < blocks.size(); i++) {
            MergedBlock next = blocks.get(i);
            long gap = Duration.between(current.end, next.start).getSeconds();
            if (next.category.equals(current.category) && gap < GAP_THRESHOLD_SECONDS) {
                var combined = new ArrayList<>(current.constituents);
                combined.addAll(next.constituents);
                current = new MergedBlock(
                    current.category, current.start, next.end,
                    current.seconds + next.seconds, current.label, combined
                );
            } else {
                result.add(current);
                current = next;
            }
        }
        result.add(current);
        return result;
    }

    private List<MergedBlock> absorbSmallBlocks(List<MergedBlock> blocks) {
        if (blocks.size() <= 1) return blocks;
        List<MergedBlock> result = new ArrayList<>(blocks);
        boolean changed = true;
        while (changed) {
            changed = false;
            for (int i = 0; i < result.size(); i++) {
                MergedBlock block = result.get(i);
                if (block.seconds < MERGE_THRESHOLD_SECONDS && result.size() > 1) {
                    // Find a neighbor that's close enough (gap < threshold)
                    int target = -1;
                    if (i > 0) {
                        long gap = Duration.between(result.get(i - 1).end, block.start).getSeconds();
                        if (gap < GAP_THRESHOLD_SECONDS) target = i - 1;
                    }
                    if (target == -1 && i + 1 < result.size()) {
                        long gap = Duration.between(block.end, result.get(i + 1).start).getSeconds();
                        if (gap < GAP_THRESHOLD_SECONDS) target = i + 1;
                    }
                    if (target == -1) continue; // isolated small block — keep it

                    MergedBlock neighbor = result.get(target);
                    Instant mergedStart = neighbor.start.isBefore(block.start) ? neighbor.start : block.start;
                    Instant mergedEnd = neighbor.end.isAfter(block.end) ? neighbor.end : block.end;
                    var combined = new ArrayList<>(neighbor.constituents);
                    combined.addAll(block.constituents);
                    String dominant = dominantCategory(combined);
                    result.set(target, new MergedBlock(
                        dominant, mergedStart, mergedEnd,
                        neighbor.seconds + block.seconds, neighbor.label, combined
                    ));
                    result.remove(i);
                    changed = true;
                    break;
                }
            }
        }
        return result;
    }

    private String dominantCategory(List<Constituent> constituents) {
        Map<String, Long> timeByCategory = new LinkedHashMap<>();
        for (Constituent c : constituents) {
            timeByCategory.merge(c.category(), c.seconds(), Long::sum);
        }
        return timeByCategory.entrySet().stream()
            .max(Map.Entry.comparingByValue())
            .map(Map.Entry::getKey)
            .orElse("Other");
    }

    // ── Timeline: merged focus session blocks for the day ──

    public List<TimelineEntry> getTimeline(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm").withZone(zone);

        return buildMergedSessions(ctx, now).stream()
            .map(block -> new TimelineEntry(
                timeFmt.format(block.start),
                timeFmt.format(block.end),
                block.label,
                null,
                block.category
            ))
            .toList();
    }

    // ── Activity log: chronological app switches ──

    public List<ActivityLogEntry> getActivityLog(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm:ss").withZone(zone);
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(ctx.startOfDay(), ctx.endOfDay());

        return ctx.sessions().stream()
            .filter(s -> {
                Instant effEnd = effectiveEnd(s, ctx.endOfDay(), now);
                return Duration.between(effectiveStart(s, ctx.startOfDay()), effEnd).getSeconds() > 0;
            })
            .sorted(Comparator.comparing(AppSession::getStartedAt))
            .map(s -> {
                Instant effStart = effectiveStart(s, ctx.startOfDay());
                Instant effEnd = effectiveEnd(s, ctx.endOfDay(), now);
                long secs = Duration.between(effStart, effEnd).getSeconds();
                String detail = s.getWindowTitle() != null ? s.getWindowTitle() : resolveCategory(s.getBundleId());

                // Enrich browser sessions with most recent domain/title
                if (isBrowserBundle(s.getBundleId()) && !browserEvents.isEmpty()) {
                    BrowserEvent latest = browserEvents.stream()
                        .filter(e -> !e.getTimestamp().isBefore(effStart) && e.getTimestamp().isBefore(effEnd))
                        .max(Comparator.comparing(BrowserEvent::getTimestamp))
                        .orElse(null);
                    if (latest != null) {
                        detail = latest.getDomain() + (latest.getTitle() != null ? " — " + latest.getTitle() : "");
                    }
                }

                return new ActivityLogEntry(
                    timeFmt.format(effStart),
                    s.getAppName(),
                    s.getBundleId(),
                    detail,
                    secs
                );
            })
            .toList();
    }

    // ── Workblocks: merged focus sessions ──

    public List<WorkblockEntry> getWorkblocks(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("H:mm").withZone(zone);

        return buildMergedSessions(ctx, now).stream()
            .map(block -> new WorkblockEntry(
                timeFmt.format(block.start),
                block.category,
                formatDuration(block.seconds),
                block.seconds
            ))
            .toList();
    }

    // ── Focus sessions: enriched merged blocks with per-app breakdowns ──

    public List<FocusSessionEntry> getFocusSessions(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("HH:mm").withZone(zone);
        List<BrowserEvent> dayBrowserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        return buildMergedSessions(ctx, now).stream()
            .map(block -> {
                // Per-app breakdown: aggregate constituent sessions by app
                // Also track start/end per app for browser event lookup
                Map<String, long[]> appTime = new LinkedHashMap<>();
                Map<String, String> appBundle = new LinkedHashMap<>();
                Map<String, String> appCategory = new LinkedHashMap<>();
                Map<String, Instant[]> appWindow = new LinkedHashMap<>(); // [start, end]

                for (Constituent c : block.constituents) {
                    String key = c.bundleId() != null ? c.bundleId() : c.appName();
                    appTime.computeIfAbsent(key, k -> new long[1]);
                    appTime.get(key)[0] += c.seconds();
                    appBundle.putIfAbsent(key, c.bundleId());
                    appCategory.putIfAbsent(key, c.category());
                }

                List<SessionAppBreakdown> apps = appTime.entrySet().stream()
                    .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
                    .map(e -> {
                        long secs = e.getValue()[0];
                        int pct = block.seconds > 0 ? (int) Math.round(secs * 100.0 / block.seconds) : 0;
                        String bundleId = appBundle.get(e.getKey());
                        String name = block.constituents.stream()
                            .filter(c -> e.getKey().equals(c.bundleId() != null ? c.bundleId() : c.appName()))
                            .map(Constituent::appName)
                            .findFirst().orElse(e.getKey());

                        return new SessionAppBreakdown(
                            name, bundleId, appCategory.get(e.getKey()), secs, pct, List.of());
                    })
                    .toList();

                // Per-category breakdown within this session
                Map<String, Long> catTime = new LinkedHashMap<>();
                for (Constituent c : block.constituents) {
                    catTime.merge(c.category(), c.seconds(), Long::sum);
                }
                List<CategoryBreakdownEntry> categories = catTime.entrySet().stream()
                    .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                    .map(e -> new CategoryBreakdownEntry(
                        e.getKey(), e.getValue(),
                        block.seconds > 0 ? (int) Math.round(e.getValue() * 100.0 / block.seconds) : 0))
                    .toList();

                // Top domains for the whole session (computed once, not per-app)
                List<SessionAppBreakdown.DomainTime> topDomains = List.of();
                boolean hasBrowser = apps.stream().anyMatch(a -> isBrowserBundle(a.bundleId()));
                if (hasBrowser && !dayBrowserEvents.isEmpty()) {
                    topDomains = getTopDomainsForSession(
                        block.start, block.end, dayBrowserEvents, 8);
                }

                return new FocusSessionEntry(
                    block.category,
                    timeFmt.format(block.start),
                    timeFmt.format(block.end),
                    block.seconds,
                    formatDuration(block.seconds),
                    apps,
                    categories,
                    topDomains
                );
            })
            .toList();
    }

    private String formatDuration(long totalSeconds) {
        long hours = totalSeconds / 3600;
        long minutes = (totalSeconds % 3600) / 60;
        if (hours > 0) {
            return hours + " hr " + minutes + " min";
        }
        return minutes + " min";
    }

    // ── Category breakdown: time grouped by category ──

    public List<CategoryBreakdownEntry> getCategoryBreakdown(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(ctx.startOfDay(), ctx.endOfDay());

        Map<String, Long> timeByCategory = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            Instant effStart = effectiveStart(session, ctx.startOfDay());
            Instant effEnd = effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
            if (seconds == 0) continue;

            if (isBrowserBundle(session.getBundleId()) && !browserEvents.isEmpty()) {
                // Split browser session time by domain category
                Map<String, Long> domainTime = splitBrowserSessionByDomain(
                    effStart, effEnd, browserEvents);
                if (!domainTime.isEmpty()) {
                    long accounted = domainTime.values().stream().mapToLong(Long::longValue).sum();
                    for (var entry : domainTime.entrySet()) {
                        timeByCategory.merge(entry.getKey(), entry.getValue(), Long::sum);
                    }
                    // Remainder stays as "Browsing"
                    long remainder = seconds - accounted;
                    if (remainder > 0) {
                        timeByCategory.merge("Browsing", remainder, Long::sum);
                    }
                } else {
                    timeByCategory.merge("Browsing", seconds, Long::sum);
                }
            } else {
                String category = resolveCategory(session.getBundleId());
                timeByCategory.merge(category, seconds, Long::sum);
            }
        }

        long total = timeByCategory.values().stream().mapToLong(Long::longValue).sum();

        return timeByCategory.entrySet().stream()
            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
            .map(e -> new CategoryBreakdownEntry(
                e.getKey(),
                e.getValue(),
                total > 0 ? (int) Math.round(e.getValue() * 100.0 / total) : 0
            ))
            .toList();
    }

    // ── Domain stats: per-category breakdown with app + domain sources ──

    public DomainStatsResponse getDomainStats(LocalDate date, ZoneId zone, Instant now) {
        DayContext ctx = dayContext(date, zone, now);
        List<BrowserEvent> browserEvents = browserEventRepo.findByTimestampBetween(
            ctx.startOfDay(), ctx.endOfDay());

        // category → source name → (type, seconds)
        Map<String, Map<String, long[]>> catSources = new LinkedHashMap<>();
        Map<String, Map<String, String>> catSourceTypes = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            Instant effStart = effectiveStart(session, ctx.startOfDay());
            Instant effEnd = effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
            if (seconds == 0) continue;

            if (isBrowserBundle(session.getBundleId()) && !browserEvents.isEmpty()) {
                // Split by domain
                List<BrowserEvent> relevant = browserEvents.stream()
                    .filter(e -> !e.getTimestamp().isBefore(effStart) && e.getTimestamp().isBefore(effEnd))
                    .sorted(Comparator.comparing(BrowserEvent::getTimestamp))
                    .toList();

                long accounted = 0;
                for (int i = 0; i < relevant.size(); i++) {
                    BrowserEvent event = relevant.get(i);
                    Instant start = event.getTimestamp();
                    Instant end = (i + 1 < relevant.size()) ? relevant.get(i + 1).getTimestamp() : effEnd;
                    long domSecs = Math.max(0, Duration.between(start, end).getSeconds());
                    if (domSecs == 0) continue;

                    String cat = resolveDomainCategory(event.getDomain());
                    catSources.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                        .computeIfAbsent(event.getDomain(), k -> new long[1])[0] += domSecs;
                    catSourceTypes.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                        .putIfAbsent(event.getDomain(), "domain");
                    accounted += domSecs;
                }
                long remainder = seconds - accounted;
                if (remainder > 0) {
                    catSources.computeIfAbsent("Browsing", k -> new LinkedHashMap<>())
                        .computeIfAbsent("(other browsing)", k -> new long[1])[0] += remainder;
                    catSourceTypes.computeIfAbsent("Browsing", k -> new LinkedHashMap<>())
                        .putIfAbsent("(other browsing)", "domain");
                }
            } else {
                String cat = resolveCategory(session.getBundleId());
                String appName = session.getAppName();
                catSources.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                    .computeIfAbsent(appName, k -> new long[1])[0] += seconds;
                catSourceTypes.computeIfAbsent(cat, k -> new LinkedHashMap<>())
                    .putIfAbsent(appName, "app");
            }
        }

        // Build response
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

    /**
     * Split a browser session's time by actual domain names.
     * Returns domain → seconds (top N, sorted by time desc).
     */
    /**
     * Top domains for a session. Queries browser_events in the session window,
     * allocates time from each event to the next, groups by domain, returns top N.
     */
    private List<SessionAppBreakdown.DomainTime> getTopDomainsForSession(
            Instant sessionStart, Instant sessionEnd, List<BrowserEvent> allBrowserEvents, int limit) {

        List<BrowserEvent> relevant = allBrowserEvents.stream()
            .filter(e -> !e.getTimestamp().isBefore(sessionStart) && e.getTimestamp().isBefore(sessionEnd))
            .sorted(Comparator.comparing(BrowserEvent::getTimestamp))
            .toList();

        if (relevant.isEmpty()) return List.of();

        Map<String, Long> domainTime = new LinkedHashMap<>();
        for (int i = 0; i < relevant.size(); i++) {
            BrowserEvent event = relevant.get(i);
            Instant start = event.getTimestamp();
            Instant end = (i + 1 < relevant.size()) ? relevant.get(i + 1).getTimestamp() : sessionEnd;
            long seconds = Math.max(0, Duration.between(start, end).getSeconds());
            if (seconds == 0) continue;
            domainTime.merge(event.getDomain(), seconds, Long::sum);
        }

        return domainTime.entrySet().stream()
            .sorted((a, b) -> Long.compare(b.getValue(), a.getValue()))
            .limit(limit)
            .map(e -> new SessionAppBreakdown.DomainTime(e.getKey(), e.getValue()))
            .toList();
    }

    /**
     * Split a browser session's time across domain categories based on browser events
     * within the session window. Returns domain_category → seconds.
     */
    private Map<String, Long> splitBrowserSessionByDomain(
            Instant sessionStart, Instant sessionEnd, List<BrowserEvent> allBrowserEvents) {

        List<BrowserEvent> relevant = allBrowserEvents.stream()
            .filter(e -> !e.getTimestamp().isBefore(sessionStart) && e.getTimestamp().isBefore(sessionEnd))
            .sorted(Comparator.comparing(BrowserEvent::getTimestamp))
            .toList();

        if (relevant.isEmpty()) return Map.of();

        Map<String, Long> result = new LinkedHashMap<>();

        for (int i = 0; i < relevant.size(); i++) {
            BrowserEvent event = relevant.get(i);
            Instant start = event.getTimestamp();
            Instant end = (i + 1 < relevant.size()) ? relevant.get(i + 1).getTimestamp() : sessionEnd;
            long seconds = Math.max(0, Duration.between(start, end).getSeconds());
            if (seconds == 0) continue;

            String category = resolveDomainCategory(event.getDomain());
            result.merge(category, seconds, Long::sum);
        }

        return result;
    }

    // ── Range aggregation: per-day breakdown over a date range ──

    public RangeResponse getRange(LocalDate from, LocalDate to, ZoneId zone, Instant now) {
        List<RangeDayBreakdown> days = new ArrayList<>();

        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            DayContext ctx = dayContext(date, zone, now);

            Map<String, Long> timeByCategory = new LinkedHashMap<>();
            for (AppSession session : ctx.sessions()) {
                Instant effStart = effectiveStart(session, ctx.startOfDay());
                Instant effEnd = effectiveEnd(session, ctx.endOfDay(), now);
                long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
                if (seconds == 0) continue;
                timeByCategory.merge(resolveCategory(session.getBundleId()), seconds, Long::sum);
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

    // ── Range summary: aggregate stats across a date range ──

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
}
