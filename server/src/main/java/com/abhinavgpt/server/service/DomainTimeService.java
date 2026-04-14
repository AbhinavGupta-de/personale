package com.abhinavgpt.server.service;

import com.abhinavgpt.server.domain.DomainUsage;
import com.abhinavgpt.server.entity.BrowserEvent;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Pure time-allocation logic for browser events within a time window.
 * Each event is credited the time until the next event (or the window end).
 */
@Service
public class DomainTimeService {

    private final CategoryResolver categoryResolver;

    public DomainTimeService(CategoryResolver categoryResolver) {
        this.categoryResolver = categoryResolver;
    }

    /**
     * Top N domains (by actual domain name) within a session window.
     */
    public List<DomainUsage> topDomainsInWindow(
            Instant start, Instant end, List<BrowserEvent> allEvents, int limit) {

        Map<String, Long> perDomain = allocatePerDomain(start, end, allEvents);
        return perDomain.entrySet().stream()
            .sorted((a, b) -> Long.compare(b.getValue(), a.getValue()))
            .limit(limit)
            .map(e -> new DomainUsage(e.getKey(), e.getValue()))
            .toList();
    }

    /**
     * Domain → seconds map (no limit). Used by session merging to find the
     * dominant category for a browser block.
     */
    public Map<String, Long> secondsPerDomain(
            Instant start, Instant end, List<BrowserEvent> allEvents) {
        return allocatePerDomain(start, end, allEvents);
    }

    /**
     * Time split by *domain category* rather than domain — used when we want
     * a browser session's time to roll up into whatever category it was
     * actually spent on (Code, Reading, etc.) instead of the generic "Browsing".
     */
    public Map<String, Long> secondsPerDomainCategory(
            Instant start, Instant end, List<BrowserEvent> allEvents) {

        List<BrowserEvent> relevant = eventsInWindow(start, end, allEvents);
        if (relevant.isEmpty()) return Map.of();

        Map<String, Long> byCategory = new LinkedHashMap<>();
        for (int i = 0; i < relevant.size(); i++) {
            BrowserEvent event = relevant.get(i);
            Instant s = event.getTimestamp();
            Instant e = (i + 1 < relevant.size()) ? relevant.get(i + 1).getTimestamp() : end;
            long seconds = Math.max(0, Duration.between(s, e).getSeconds());
            if (seconds == 0) continue;
            String cat = categoryResolver.categoryForDomain(event.getDomain());
            byCategory.merge(cat, seconds, Long::sum);
        }
        return byCategory;
    }

    // ── Internals ──

    private Map<String, Long> allocatePerDomain(
            Instant start, Instant end, List<BrowserEvent> allEvents) {

        List<BrowserEvent> relevant = eventsInWindow(start, end, allEvents);
        if (relevant.isEmpty()) return Map.of();

        Map<String, Long> perDomain = new LinkedHashMap<>();
        for (int i = 0; i < relevant.size(); i++) {
            BrowserEvent event = relevant.get(i);
            Instant s = event.getTimestamp();
            Instant e = (i + 1 < relevant.size()) ? relevant.get(i + 1).getTimestamp() : end;
            long seconds = Math.max(0, Duration.between(s, e).getSeconds());
            if (seconds == 0) continue;
            perDomain.merge(event.getDomain(), seconds, Long::sum);
        }
        return perDomain;
    }

    private List<BrowserEvent> eventsInWindow(
            Instant start, Instant end, List<BrowserEvent> allEvents) {
        return allEvents.stream()
            .filter(e -> !e.getTimestamp().isBefore(start) && e.getTimestamp().isBefore(end))
            .sorted(Comparator.comparing(BrowserEvent::getTimestamp))
            .toList();
    }
}
