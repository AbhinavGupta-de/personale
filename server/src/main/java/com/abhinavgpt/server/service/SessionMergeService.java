package com.abhinavgpt.server.service;

import com.abhinavgpt.server.domain.AppUsage;
import com.abhinavgpt.server.domain.MergedBlock;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Builds focus blocks from raw app sessions. The algorithm:
 *   1. Clamp each session to the day window and resolve its category.
 *      Browser sessions pick the dominant domain category (GitHub-heavy
 *      session becomes "Code", not "Browsing").
 *   2. Merge adjacent blocks of the same category if the gap between them
 *      fits inside the *category's* idle threshold (M4 — thinking pauses
 *      in Code don't split a session).
 *   3. Absorb blocks shorter than MERGE_THRESHOLD into a neighbor, re-merge.
 */
@Service
public class SessionMergeService {

    /** Blocks shorter than this are absorbed into their neighbor. */
    private static final long MERGE_THRESHOLD_SECONDS = 300; // 5 min

    private final CategoryResolver categoryResolver;
    private final DomainTimeService domainTimeService;

    public SessionMergeService(CategoryResolver categoryResolver,
                               DomainTimeService domainTimeService) {
        this.categoryResolver = categoryResolver;
        this.domainTimeService = domainTimeService;
    }

    public List<MergedBlock> buildMergedBlocks(List<AppSession> sessions,
                                               Instant startOfDay,
                                               Instant endOfDay,
                                               Instant now,
                                               List<BrowserEvent> browserEvents) {
        List<MergedBlock> raw = sessions.stream()
            .filter(s -> sessionDurationSeconds(s, startOfDay, endOfDay, now) > 0)
            .sorted(Comparator.comparing(AppSession::getStartedAt))
            .map(s -> toInitialBlock(s, startOfDay, endOfDay, now, browserEvents))
            .toList();

        if (raw.size() <= 1) return raw;

        List<MergedBlock> merged = mergeAdjacentSameCategory(raw);
        merged = absorbSmallBlocks(merged);
        return mergeAdjacentSameCategory(merged);
    }

    // ── Block construction ──

    private long sessionDurationSeconds(AppSession s, Instant startOfDay, Instant endOfDay, Instant now) {
        Instant effStart = effectiveStart(s, startOfDay);
        Instant effEnd = effectiveEnd(s, endOfDay, now);
        return Duration.between(effStart, effEnd).getSeconds();
    }

    private MergedBlock toInitialBlock(AppSession s, Instant startOfDay, Instant endOfDay,
                                       Instant now, List<BrowserEvent> browserEvents) {
        Instant effStart = effectiveStart(s, startOfDay);
        Instant effEnd = effectiveEnd(s, endOfDay, now);
        long secs = Duration.between(effStart, effEnd).getSeconds();

        String category = categoryResolver.categoryForBundle(s.getBundleId());

        // Browser sessions: use dominant domain category as the block category
        if (categoryResolver.isBrowserBundle(s.getBundleId()) && !browserEvents.isEmpty()) {
            Map<String, Long> byCategory = domainTimeService.secondsPerDomainCategory(
                effStart, effEnd, browserEvents);
            if (!byCategory.isEmpty()) {
                category = byCategory.entrySet().stream()
                    .max(Map.Entry.comparingByValue())
                    .map(Map.Entry::getKey)
                    .orElse(category);
            }
        }

        AppUsage usage = new AppUsage(
            s.getAppName(), s.getBundleId(), category, effStart, effEnd, secs);
        return new MergedBlock(category, effStart, effEnd, secs, s.getAppName(), List.of(usage));
    }

    // ── Merging ──

    private List<MergedBlock> mergeAdjacentSameCategory(List<MergedBlock> blocks) {
        if (blocks.isEmpty()) return blocks;
        List<MergedBlock> result = new ArrayList<>();
        MergedBlock current = blocks.getFirst();
        for (int i = 1; i < blocks.size(); i++) {
            MergedBlock next = blocks.get(i);
            long gap = Duration.between(current.end(), next.start()).getSeconds();
            long threshold = categoryResolver.idleThresholdSeconds(current.category());
            if (next.category().equals(current.category()) && gap < threshold) {
                List<AppUsage> combined = new ArrayList<>(current.constituents());
                combined.addAll(next.constituents());
                current = new MergedBlock(
                    current.category(), current.start(), next.end(),
                    current.seconds() + next.seconds(), current.label(), combined);
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
                if (block.seconds() >= MERGE_THRESHOLD_SECONDS || result.size() <= 1) continue;

                int target = findAbsorbTarget(result, i);
                if (target == -1) continue;

                MergedBlock neighbor = result.get(target);
                Instant mergedStart = neighbor.start().isBefore(block.start()) ? neighbor.start() : block.start();
                Instant mergedEnd = neighbor.end().isAfter(block.end()) ? neighbor.end() : block.end();
                List<AppUsage> combined = new ArrayList<>(neighbor.constituents());
                combined.addAll(block.constituents());
                String dominant = dominantCategory(combined);
                result.set(target, new MergedBlock(
                    dominant, mergedStart, mergedEnd,
                    neighbor.seconds() + block.seconds(), neighbor.label(), combined));
                result.remove(i);
                changed = true;
                break;
            }
        }
        return result;
    }

    /**
     * Look for a neighbor whose gap to this block is within the idle threshold
     * of *either* the block's category or the neighbor's. Using either side's
     * threshold means a brief Code blip next to a long Reading block still gets
     * absorbed instead of stranding as a tiny isolated block.
     */
    private int findAbsorbTarget(List<MergedBlock> blocks, int index) {
        MergedBlock block = blocks.get(index);
        if (index > 0) {
            MergedBlock prev = blocks.get(index - 1);
            long gap = Duration.between(prev.end(), block.start()).getSeconds();
            long threshold = Math.max(
                categoryResolver.idleThresholdSeconds(prev.category()),
                categoryResolver.idleThresholdSeconds(block.category()));
            if (gap < threshold) return index - 1;
        }
        if (index + 1 < blocks.size()) {
            MergedBlock next = blocks.get(index + 1);
            long gap = Duration.between(block.end(), next.start()).getSeconds();
            long threshold = Math.max(
                categoryResolver.idleThresholdSeconds(block.category()),
                categoryResolver.idleThresholdSeconds(next.category()));
            if (gap < threshold) return index + 1;
        }
        return -1;
    }

    private String dominantCategory(List<AppUsage> constituents) {
        Map<String, Long> byCategory = new LinkedHashMap<>();
        for (AppUsage u : constituents) {
            byCategory.merge(u.category(), u.seconds(), Long::sum);
        }
        return byCategory.entrySet().stream()
            .max(Map.Entry.comparingByValue())
            .map(Map.Entry::getKey)
            .orElse("Other");
    }

    // ── Day boundary helpers ──

    static Instant effectiveStart(AppSession session, Instant startOfDay) {
        return session.getStartedAt().isBefore(startOfDay) ? startOfDay : session.getStartedAt();
    }

    static Instant effectiveEnd(AppSession session, Instant endOfDay, Instant now) {
        Instant end = session.getEndedAt() != null ? session.getEndedAt() : now;
        return end.isAfter(endOfDay) ? endOfDay : end;
    }
}
