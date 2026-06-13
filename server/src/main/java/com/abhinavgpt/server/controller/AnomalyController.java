package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.AnomalyReportResponse;
import com.abhinavgpt.server.service.AnomalyService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

@RestController
@RequestMapping("/api/insights")
public class AnomalyController {

    private final AnomalyService anomalyService;

    public AnomalyController(AnomalyService anomalyService) {
        this.anomalyService = anomalyService;
    }

    @GetMapping("/anomalies")
    public ResponseEntity<AnomalyReportResponse> anomalies(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour,
            @RequestParam(defaultValue = "14") int lookbackDays) {
        return ResponseEntity.ok(anomalyService.computeAnomalies(
            LocalDate.parse(date),
            ZoneId.systemDefault(),
            Instant.now(),
            dayStartHour,
            lookbackDays));
    }
}
