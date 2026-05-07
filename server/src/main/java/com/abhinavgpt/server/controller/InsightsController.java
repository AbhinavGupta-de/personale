package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.InsightsNarrativeResponse;
import com.abhinavgpt.server.dto.InsightsOverviewResponse;
import com.abhinavgpt.server.service.InsightsNarrativeService;
import com.abhinavgpt.server.service.InsightsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

@RestController
@RequestMapping("/api/insights")
public class InsightsController {

    private final InsightsService insightsService;
    private final InsightsNarrativeService narrativeService;

    public InsightsController(InsightsService insightsService,
                              InsightsNarrativeService narrativeService) {
        this.insightsService = insightsService;
        this.narrativeService = narrativeService;
    }

    @GetMapping("/overview")
    public ResponseEntity<InsightsOverviewResponse> overview(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(insightsService.getOverview(
            LocalDate.parse(from), LocalDate.parse(to),
            ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }

    @PostMapping("/narrative")
    public ResponseEntity<InsightsNarrativeResponse> narrative(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(narrativeService.generate(
            LocalDate.parse(from), LocalDate.parse(to),
            ZoneId.systemDefault(), Instant.now(), dayStartHour));
    }
}
