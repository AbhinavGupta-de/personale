package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.FocusSessionEntry;
import com.abhinavgpt.server.dto.SessionReviewResponse;
import com.abhinavgpt.server.dto.SessionReviewUpdateRequest;
import com.abhinavgpt.server.entity.SessionReview;
import com.abhinavgpt.server.service.SessionInsightService;
import com.abhinavgpt.server.service.SessionReviewService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.*;
import java.util.List;

@RestController
@RequestMapping("/api/reviews")
public class SessionReviewController {

    private final SessionReviewService service;
    private final SessionInsightService insight;

    public SessionReviewController(SessionReviewService service, SessionInsightService insight) {
        this.service = service;
        this.insight = insight;
    }

    @GetMapping
    public ResponseEntity<List<SessionReviewResponse>> list(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour,
            @RequestParam(defaultValue = "all") String status) {
        return ResponseEntity.ok(service.listForDate(
            LocalDate.parse(date), ZoneId.systemDefault(), Instant.now(), dayStartHour, status));
    }

    @PutMapping("/{key}")
    public ResponseEntity<SessionReviewResponse> update(
            @PathVariable String key,
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour,
            @RequestBody SessionReviewUpdateRequest req) {
        return ResponseEntity.ok(service.update(key, req,
            LocalDate.parse(date), ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @PostMapping("/{key}/status")
    public ResponseEntity<SessionReviewResponse> setStatus(
            @PathVariable String key,
            @RequestParam String status,
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(service.setStatus(key, status,
            LocalDate.parse(date), ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    /** Fire AI generate for every block on this day that doesn't yet have an
     *  AI draft. Returns the refreshed list. Blocks already drafted are skipped. */
    @PostMapping("/generate-missing")
    public ResponseEntity<List<SessionReviewResponse>> generateMissing(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        LocalDate d = LocalDate.parse(date);
        ZoneId zone = ZoneId.systemDefault();
        Instant now = Instant.now();
        int dsh = dayStartHour;
        List<SessionReviewResponse> current = service.listForDate(d, zone, now, dsh, "all");
        for (SessionReviewResponse r : current) {
            if (r.aiTitle() != null && !r.aiTitle().isBlank()) continue;
            try {
                FocusSessionEntry block = service.findBlock(r.blockKey(), d, zone, now, dsh);
                Instant dayStart = d.atStartOfDay(zone)
                    .plusHours(Math.max(0, Math.min(23, dsh))).toInstant();
                Instant blockStart = parseHHmm(block.startTime(), dayStart, zone);
                Instant blockEnd = parseHHmm(block.endTime(), dayStart, zone);
                if (blockEnd.isBefore(blockStart)) blockEnd = blockEnd.plusSeconds(86_400);
                String[] td = insight.generateForWindow(block.name(), blockStart, blockEnd);
                service.upsertAiInsight(r.blockKey(), d, block, td[0], td[1], td[2]);
            } catch (Exception ignored) {
                // One failure shouldn't block the batch; user can retry per-block.
            }
        }
        return ResponseEntity.ok(service.listForDate(d, zone, now, dsh, "all"));
    }

    @PostMapping("/{key}/generate")
    public ResponseEntity<SessionReviewResponse> generate(
            @PathVariable String key,
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        LocalDate d = LocalDate.parse(date);
        ZoneId zone = ZoneId.systemDefault();
        Instant now = Instant.now();
        FocusSessionEntry block = service.findBlock(key, d, zone, now, dayStartHour);

        // Parse "HH:mm" start/end against the day window start.
        Instant dayStart = d.atStartOfDay(zone).plusHours(Math.max(0, Math.min(23, dayStartHour))).toInstant();
        Instant blockStart = parseHHmm(block.startTime(), dayStart, zone);
        Instant blockEnd = parseHHmm(block.endTime(), dayStart, zone);
        if (blockEnd.isBefore(blockStart)) blockEnd = blockEnd.plusSeconds(86_400);

        String[] titleDescModel = insight.generateForWindow(block.name(), blockStart, blockEnd);
        SessionReview saved = service.upsertAiInsight(key, d, block,
            titleDescModel[0], titleDescModel[1], titleDescModel[2]);

        return ResponseEntity.ok(service.listForDate(d, zone, now, dayStartHour, "all").stream()
            .filter(r -> r.blockKey().equals(key))
            .findFirst().orElseThrow());
    }

    private static Instant parseHHmm(String hhmm, Instant dayStart, ZoneId zone) {
        String[] parts = hhmm.split(":");
        int h = Integer.parseInt(parts[0]);
        int m = Integer.parseInt(parts[1]);
        ZonedDateTime dayStartZ = dayStart.atZone(zone);
        int dayStartHour = dayStartZ.getHour();
        // Wrap past midnight if block's HH < day-start hour.
        int dayOffset = h < dayStartHour ? 1 : 0;
        return dayStartZ.withHour(h).withMinute(m).withSecond(0).plusDays(dayOffset).toInstant();
    }
}
