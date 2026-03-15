package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.*;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import org.springframework.stereotype.Service;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
public class StatsService {

    private final AppSessionRepository repository;
    private final CategoryMappingRepository categoryRepo;

    // In-memory cache of bundle_id → category with TTL-based refresh
    private Map<String, String> categoryCache;
    private Instant lastCacheLoad;
    private static final Duration CACHE_TTL = Duration.ofMinutes(5);

    public StatsService(AppSessionRepository repository, CategoryMappingRepository categoryRepo) {
        this.repository = repository;
        this.categoryRepo = categoryRepo;
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

    private String resolveCategory(String bundleId) {
        if (bundleId == null) return "Other";
        return getCategoryCache().getOrDefault(bundleId, "Other");
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
                    result.set(target, new MergedBlock(
                        neighbor.category, mergedStart, mergedEnd,
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

        return buildMergedSessions(ctx, now).stream()
            .map(block -> {
                // Per-app breakdown: aggregate constituent sessions by app
                Map<String, long[]> appTime = new LinkedHashMap<>();
                Map<String, String> appBundle = new LinkedHashMap<>();
                Map<String, String> appCategory = new LinkedHashMap<>();

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
                        // Resolve app name from the key (bundleId or appName)
                        String name = block.constituents.stream()
                            .filter(c -> e.getKey().equals(c.bundleId() != null ? c.bundleId() : c.appName()))
                            .map(Constituent::appName)
                            .findFirst().orElse(e.getKey());
                        return new SessionAppBreakdown(
                            name, appBundle.get(e.getKey()), appCategory.get(e.getKey()), secs, pct);
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

                return new FocusSessionEntry(
                    block.category,
                    timeFmt.format(block.start),
                    timeFmt.format(block.end),
                    block.seconds,
                    formatDuration(block.seconds),
                    apps,
                    categories
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

        Map<String, Long> timeByCategory = new LinkedHashMap<>();

        for (AppSession session : ctx.sessions()) {
            Instant effStart = effectiveStart(session, ctx.startOfDay());
            Instant effEnd = effectiveEnd(session, ctx.endOfDay(), now);
            long seconds = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
            if (seconds == 0) continue;

            String category = resolveCategory(session.getBundleId());
            timeByCategory.merge(category, seconds, Long::sum);
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
}
