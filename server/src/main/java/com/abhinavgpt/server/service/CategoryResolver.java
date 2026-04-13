package com.abhinavgpt.server.service;

import com.abhinavgpt.server.repository.CategoryMappingRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import com.abhinavgpt.server.repository.DomainCategoryMappingRepository;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Supplier;

/**
 * Resolves a bundle id or domain to a category, with TTL-based in-memory caching.
 * Also serves per-category idle thresholds used by the merge algorithm.
 *
 * Thread safety: each cache is held behind a volatile snapshot that bundles
 * the data and its load timestamp. Readers always see a consistent pair, and
 * a stale snapshot is replaced atomically by a fresh one.
 */
@Service
public class CategoryResolver {

    private static final Duration CACHE_TTL = Duration.ofMinutes(5);
    private static final String DEFAULT_CATEGORY = "Other";
    private static final String BROWSER_CATEGORY = "Browsing";
    private static final int DEFAULT_IDLE_THRESHOLD_SECONDS = 300; // 5 min fallback

    private record Snapshot<V>(Map<String, V> data, Instant loadedAt) {
        boolean isFresh() {
            return loadedAt != null && Instant.now().isBefore(loadedAt.plus(CACHE_TTL));
        }
    }

    private final CategoryMappingRepository bundleRepo;
    private final DomainCategoryMappingRepository domainRepo;
    private final CategoryThresholdRepository thresholdRepo;

    private volatile Snapshot<String> bundles;
    private volatile Snapshot<String> domains;
    private volatile Snapshot<Integer> thresholds;

    public CategoryResolver(CategoryMappingRepository bundleRepo,
                            DomainCategoryMappingRepository domainRepo,
                            CategoryThresholdRepository thresholdRepo) {
        this.bundleRepo = bundleRepo;
        this.domainRepo = domainRepo;
        this.thresholdRepo = thresholdRepo;
    }

    public String categoryForBundle(String bundleId) {
        if (bundleId == null) return DEFAULT_CATEGORY;
        return bundleMap().getOrDefault(bundleId, DEFAULT_CATEGORY);
    }

    public String categoryForDomain(String domain) {
        if (domain == null) return BROWSER_CATEGORY;
        Map<String, String> cache = domainMap();
        String cat = cache.get(domain);
        if (cat != null) return cat;
        // Strip one subdomain level: "www.github.com" → "github.com"
        int dot = domain.indexOf('.');
        if (dot > 0 && domain.indexOf('.', dot + 1) > 0) {
            cat = cache.get(domain.substring(dot + 1));
            if (cat != null) return cat;
        }
        return BROWSER_CATEGORY;
    }

    public boolean isBrowserBundle(String bundleId) {
        return BROWSER_CATEGORY.equals(categoryForBundle(bundleId));
    }

    /**
     * Idle threshold in seconds for a given category. Falls back to the
     * default if the category has no explicit configuration.
     */
    public long idleThresholdSeconds(String category) {
        if (category == null) return DEFAULT_IDLE_THRESHOLD_SECONDS;
        return thresholdMap().getOrDefault(category, DEFAULT_IDLE_THRESHOLD_SECONDS);
    }

    // ── Snapshot loading ──

    private Map<String, String> bundleMap() {
        Snapshot<String> snap = bundles;
        if (snap == null || !snap.isFresh()) {
            snap = loadSnapshot(() -> {
                Map<String, String> fresh = new HashMap<>();
                bundleRepo.findAll().forEach(m -> fresh.put(m.getBundleId(), m.getCategory()));
                return fresh;
            });
            bundles = snap;
        }
        return snap.data();
    }

    private Map<String, String> domainMap() {
        Snapshot<String> snap = domains;
        if (snap == null || !snap.isFresh()) {
            snap = loadSnapshot(() -> {
                Map<String, String> fresh = new HashMap<>();
                domainRepo.findAll().forEach(m -> fresh.put(m.getDomain(), m.getCategory()));
                return fresh;
            });
            domains = snap;
        }
        return snap.data();
    }

    private Map<String, Integer> thresholdMap() {
        Snapshot<Integer> snap = thresholds;
        if (snap == null || !snap.isFresh()) {
            snap = loadSnapshot(() -> {
                Map<String, Integer> fresh = new HashMap<>();
                thresholdRepo.findAll().forEach(t ->
                    fresh.put(t.getCategory(), t.getIdleThresholdSeconds()));
                return fresh;
            });
            thresholds = snap;
        }
        return snap.data();
    }

    private <V> Snapshot<V> loadSnapshot(Supplier<Map<String, V>> loader) {
        return new Snapshot<>(loader.get(), Instant.now());
    }
}
