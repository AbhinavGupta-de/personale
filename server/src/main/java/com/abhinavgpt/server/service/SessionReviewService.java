package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.*;
import com.abhinavgpt.server.entity.SessionReview;
import com.abhinavgpt.server.repository.SessionReviewRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

/**
 * Builds editable "review blocks" over top of the auto-merged focus sessions
 * from StatsService.getFocusSessions. Keys are sha256 hashes of
 * (date, startTime, endTime, category) — stable as long as merge boundaries
 * don't shift. User-edited fields + status live in session_reviews.
 */
@Service
public class SessionReviewService {

    private final StatsService statsService;
    private final SessionReviewRepository repo;

    public SessionReviewService(StatsService statsService, SessionReviewRepository repo) {
        this.statsService = statsService;
        this.repo = repo;
    }

    public List<SessionReviewResponse> listForDate(LocalDate date, ZoneId zone,
                                                   Instant now, int dayStartHour,
                                                   String statusFilter) {
        List<FocusSessionEntry> blocks = statsService.getFocusSessions(date, zone, now, dayStartHour);
        Map<String, SessionReview> stored = new java.util.HashMap<>();
        repo.findByBlockDate(date).forEach(r -> stored.put(r.getBlockKey(), r));

        List<SessionReviewResponse> out = new ArrayList<>();
        for (FocusSessionEntry block : blocks) {
            String key = blockKey(date, block.startTime(), block.endTime(), block.name());
            SessionReview stored_ = stored.get(key);
            String status = stored_ != null ? stored_.getStatus() : "pending";
            if (statusFilter != null && !statusFilter.equalsIgnoreCase("all")
                && !statusFilter.equalsIgnoreCase(status)) continue;
            out.add(toResponse(key, date, block, stored_));
        }
        return out;
    }

    public SessionReviewResponse update(String key, SessionReviewUpdateRequest req,
                                         LocalDate date, ZoneId zone, Instant now,
                                         int dayStartHour) {
        FocusSessionEntry block = findBlock(key, date, zone, now, dayStartHour);
        SessionReview r = repo.findById(key).orElseGet(() -> freshRow(key, date, block));
        if (req.title() != null) r.setTitle(req.title());
        if (req.description() != null) r.setDescription(req.description());
        if (req.task() != null) r.setTask(req.task());
        if (req.project() != null) r.setProject(req.project());
        if (req.client() != null) r.setClient(req.client());
        if (req.category() != null) r.setOverrideCategory(req.category().isBlank() ? null : req.category());
        r.setUpdatedAt(Instant.now());
        SessionReview saved = repo.save(r);
        saved.markPersisted();
        return toResponse(key, date, block, saved);
    }

    public SessionReviewResponse setStatus(String key, String status,
                                            LocalDate date, ZoneId zone, Instant now,
                                            int dayStartHour) {
        if (!java.util.Set.of("pending", "approved", "rejected").contains(status)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "status must be pending|approved|rejected");
        }
        FocusSessionEntry block = findBlock(key, date, zone, now, dayStartHour);
        SessionReview r = repo.findById(key).orElseGet(() -> freshRow(key, date, block));
        r.setStatus(status);
        r.setUpdatedAt(Instant.now());
        SessionReview saved = repo.save(r);
        saved.markPersisted();
        return toResponse(key, date, block, saved);
    }

    /** Store AI-generated title/description. Called by SessionInsightService. */
    public SessionReview upsertAiInsight(String key, LocalDate date, FocusSessionEntry block,
                                          String aiTitle, String aiDescription, String model) {
        SessionReview r = repo.findById(key).orElseGet(() -> freshRow(key, date, block));
        r.setAiTitle(aiTitle);
        r.setAiDescription(aiDescription);
        r.setAiModel(model);
        r.setAiGeneratedAt(Instant.now());
        r.setUpdatedAt(Instant.now());
        // If user hasn't edited a title/desc yet, promote AI values as the draft.
        if (r.getTitle() == null || r.getTitle().isBlank()) r.setTitle(aiTitle);
        if (r.getDescription() == null || r.getDescription().isBlank()) r.setDescription(aiDescription);
        SessionReview saved = repo.save(r);
        saved.markPersisted();
        return saved;
    }

    public FocusSessionEntry findBlock(String key, LocalDate date, ZoneId zone, Instant now,
                                        int dayStartHour) {
        for (FocusSessionEntry b : statsService.getFocusSessions(date, zone, now, dayStartHour)) {
            if (blockKey(date, b.startTime(), b.endTime(), b.name()).equals(key)) return b;
        }
        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "block not found for key " + key);
    }

    public static String blockKey(LocalDate date, String startTime, String endTime, String category) {
        String input = date + "|" + startTime + "|" + endTime + "|" + category;
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(input.getBytes(StandardCharsets.UTF_8)))
                .substring(0, 16);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private SessionReview freshRow(String key, LocalDate date, FocusSessionEntry block) {
        SessionReview r = new SessionReview();
        r.setBlockKey(key);
        r.setBlockDate(date);
        r.setStartTime(block.startTime());
        r.setEndTime(block.endTime());
        r.setCategory(block.name());
        r.setStatus("pending");
        r.setCreatedAt(Instant.now());
        r.setUpdatedAt(Instant.now());
        return r;
    }

    private SessionReviewResponse toResponse(String key, LocalDate date, FocusSessionEntry block,
                                              SessionReview stored) {
        List<AppTimeEntry> apps = block.apps().stream()
            .map(a -> new AppTimeEntry(a.appName(), a.bundleId(), a.totalSeconds()))
            .toList();
        // Effective category: user override wins over derived.
        String effectiveCategory = stored != null && stored.getOverrideCategory() != null
            ? stored.getOverrideCategory()
            : block.name();
        return new SessionReviewResponse(
            key,
            date.toString(),
            block.startTime(),
            block.endTime(),
            block.durationSeconds(),
            effectiveCategory,
            stored != null ? stored.getTitle() : null,
            stored != null ? stored.getDescription() : null,
            stored != null ? stored.getTask() : null,
            stored != null ? stored.getProject() : null,
            stored != null ? stored.getClient() : null,
            stored != null ? stored.getStatus() : "pending",
            stored != null ? stored.getAiTitle() : null,
            stored != null ? stored.getAiDescription() : null,
            stored != null && stored.getAiGeneratedAt() != null
                ? stored.getAiGeneratedAt().toString() : null,
            apps,
            block.categories(),
            block.topDomains()
        );
    }
}
