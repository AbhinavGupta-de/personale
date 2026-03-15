package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.*;
import com.abhinavgpt.server.service.StatsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

@RestController
@RequestMapping("/api/stats")
public class StatsController {

    private final StatsService statsService;

    public StatsController(StatsService statsService) {
        this.statsService = statsService;
    }

    @GetMapping("/today")
    public ResponseEntity<DailyStatsResponse> getToday() {
        return ResponseEntity.ok(
            statsService.getTimePerAppToday(ZoneId.systemDefault(), Instant.now()));
    }

    @GetMapping("/day")
    public ResponseEntity<DailyStatsResponse> getDay(@RequestParam String date) {
        LocalDate day = LocalDate.parse(date);
        return ResponseEntity.ok(
            statsService.getTimePerApp(day, ZoneId.systemDefault(), Instant.now()));
    }

    @GetMapping("/timeline")
    public ResponseEntity<List<TimelineEntry>> getTimeline(@RequestParam String date) {
        LocalDate day = LocalDate.parse(date);
        return ResponseEntity.ok(
            statsService.getTimeline(day, ZoneId.systemDefault(), Instant.now()));
    }

    @GetMapping("/activity")
    public ResponseEntity<List<ActivityLogEntry>> getActivity(@RequestParam String date) {
        LocalDate day = LocalDate.parse(date);
        return ResponseEntity.ok(
            statsService.getActivityLog(day, ZoneId.systemDefault(), Instant.now()));
    }

    @GetMapping("/categories")
    public ResponseEntity<List<CategoryBreakdownEntry>> getCategories(@RequestParam String date) {
        LocalDate day = LocalDate.parse(date);
        return ResponseEntity.ok(
            statsService.getCategoryBreakdown(day, ZoneId.systemDefault(), Instant.now()));
    }

    @GetMapping("/workblocks")
    public ResponseEntity<List<WorkblockEntry>> getWorkblocks(@RequestParam String date) {
        LocalDate day = LocalDate.parse(date);
        return ResponseEntity.ok(
            statsService.getWorkblocks(day, ZoneId.systemDefault(), Instant.now()));
    }

    @GetMapping("/sessions")
    public ResponseEntity<List<FocusSessionEntry>> getSessions(@RequestParam String date) {
        LocalDate day = LocalDate.parse(date);
        return ResponseEntity.ok(
            statsService.getFocusSessions(day, ZoneId.systemDefault(), Instant.now()));
    }
}
