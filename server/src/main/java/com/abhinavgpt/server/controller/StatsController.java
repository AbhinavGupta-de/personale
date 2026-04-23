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
    public ResponseEntity<DailyStatsResponse> getToday(
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getTimePerAppToday(ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/day")
    public ResponseEntity<DailyStatsResponse> getDay(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getTimePerApp(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/timeline")
    public ResponseEntity<List<TimelineEntry>> getTimeline(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getTimeline(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/activity")
    public ResponseEntity<List<ActivityLogEntry>> getActivity(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getActivityLog(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/categories")
    public ResponseEntity<List<CategoryBreakdownEntry>> getCategories(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getCategoryBreakdown(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/workblocks")
    public ResponseEntity<List<WorkblockEntry>> getWorkblocks(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getWorkblocks(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/sessions")
    public ResponseEntity<List<FocusSessionEntry>> getSessions(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getFocusSessions(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/range")
    public ResponseEntity<RangeResponse> getRange(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getRange(LocalDate.parse(from), LocalDate.parse(to),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/range/summary")
    public ResponseEntity<RangeSummaryResponse> getRangeSummary(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getRangeSummary(LocalDate.parse(from), LocalDate.parse(to),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/interruptors")
    public ResponseEntity<List<InterruptorEntry>> getInterruptors(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getInterruptors(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/interruptors/range")
    public ResponseEntity<List<InterruptorEntry>> getInterruptorsRange(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getInterruptorsRange(LocalDate.parse(from), LocalDate.parse(to),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @GetMapping("/domains")
    public ResponseEntity<DomainStatsResponse> getDomains(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(
            statsService.getDomainStats(LocalDate.parse(date),
                ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }
}
