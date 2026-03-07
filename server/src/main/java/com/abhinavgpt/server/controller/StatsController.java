package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.DailyStatsResponse;
import com.abhinavgpt.server.service.StatsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.time.ZoneId;

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
}
