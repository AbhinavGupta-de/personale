package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.TrackingRuleRequest;
import com.abhinavgpt.server.dto.TrackingRuleResponse;
import com.abhinavgpt.server.entity.TrackingRule;
import com.abhinavgpt.server.repository.TrackingRuleRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

@Service
public class TrackingRuleService {

    private static final Set<String> VALID_SOURCES = Set.of("macos", "browser");

    private final TrackingRuleRepository repo;

    public TrackingRuleService(TrackingRuleRepository repo) {
        this.repo = repo;
    }

    public List<TrackingRuleResponse> list() {
        List<TrackingRuleResponse> out = new ArrayList<>();
        repo.findAll().forEach(r -> out.add(toResponse(r)));
        out.sort(Comparator
            .comparing(TrackingRuleResponse::source)
            .thenComparing(TrackingRuleResponse::appName, String.CASE_INSENSITIVE_ORDER));
        return out;
    }

    public TrackingRuleResponse create(TrackingRuleRequest req) {
        validate(req, true);
        TrackingRule rule = new TrackingRule(
            req.source().trim(),
            req.appName().trim(),
            normalizeKeywords(req.keywords()),
            req.category().trim(),
            flag(req.alwaysBlock(), false),
            flag(req.blockBreaks(), false),
            flag(req.blockMeetings(), false),
            flag(req.blockFocus(), false),
            flag(req.trackTitles(), true),
            flag(req.trackFullUrls(), false)
        );
        rule.setCreatedAt(java.time.Instant.now());
        return toResponse(repo.save(rule));
    }

    public TrackingRuleResponse update(Long id, TrackingRuleRequest req) {
        TrackingRule rule = repo.findById(id).orElseThrow(
            () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "rule not found"));
        validate(req, false);
        if (req.source() != null) rule.setSource(req.source().trim());
        if (req.appName() != null) rule.setAppName(req.appName().trim());
        if (req.keywords() != null) rule.setKeywords(normalizeKeywords(req.keywords()));
        if (req.category() != null) rule.setCategory(req.category().trim());
        if (req.alwaysBlock() != null) rule.setAlwaysBlock(req.alwaysBlock());
        if (req.blockBreaks() != null) rule.setBlockBreaks(req.blockBreaks());
        if (req.blockMeetings() != null) rule.setBlockMeetings(req.blockMeetings());
        if (req.blockFocus() != null) rule.setBlockFocus(req.blockFocus());
        if (req.trackTitles() != null) rule.setTrackTitles(req.trackTitles());
        if (req.trackFullUrls() != null) rule.setTrackFullUrls(req.trackFullUrls());
        return toResponse(repo.save(rule));
    }

    public void delete(Long id) {
        if (!repo.existsById(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "rule not found");
        }
        repo.deleteById(id);
    }

    // ── Resolver helpers (M13 hook into CategoryResolver) ──

    /** Snapshot of (source, appName) → category for fast lookup by CategoryResolver. */
    public java.util.Map<String, String> categoryOverridesSnapshot() {
        java.util.Map<String, String> out = new java.util.HashMap<>();
        for (TrackingRule r : repo.findAll()) {
            out.put(r.getSource() + ":" + r.getAppName().toLowerCase(), r.getCategory());
        }
        return out;
    }

    // ── Private ──

    private void validate(TrackingRuleRequest req, boolean requireAll) {
        if (requireAll) {
            if (req.source() == null || req.appName() == null || req.category() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "source, appName, category are required");
            }
        }
        if (req.source() != null && !VALID_SOURCES.contains(req.source())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "source must be 'macos' or 'browser'");
        }
    }

    private static boolean flag(Boolean provided, boolean fallback) {
        return provided != null ? provided : fallback;
    }

    private static String normalizeKeywords(String raw) {
        if (raw == null) return null;
        String trimmed = raw.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private TrackingRuleResponse toResponse(TrackingRule r) {
        return new TrackingRuleResponse(
            r.getId(), r.getSource(), r.getAppName(), r.getKeywords(), r.getCategory(),
            r.isAlwaysBlock(), r.isBlockBreaks(), r.isBlockMeetings(), r.isBlockFocus(),
            r.isTrackTitles(), r.isTrackFullUrls()
        );
    }
}
