package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.PomodoroSessionResponse;
import com.abhinavgpt.server.dto.PomodoroStartRequest;
import com.abhinavgpt.server.dto.SessionInsightResponse;
import com.abhinavgpt.server.service.PomodoroService;
import com.abhinavgpt.server.service.SessionInsightService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

@RestController
@RequestMapping("/api/pomodoro")
public class PomodoroController {

    private final PomodoroService service;
    private final SessionInsightService insightService;

    public PomodoroController(PomodoroService service, SessionInsightService insightService) {
        this.service = service;
        this.insightService = insightService;
    }

    @PostMapping("/start")
    public ResponseEntity<PomodoroSessionResponse> start(@RequestBody PomodoroStartRequest req) {
        return ResponseEntity.ok(service.start(req));
    }

    @PostMapping("/{id}/end")
    public ResponseEntity<PomodoroSessionResponse> end(
            @PathVariable Long id,
            @RequestParam(defaultValue = "false") boolean discard) {
        return ResponseEntity.ok(service.end(id, discard));
    }

    @GetMapping
    public ResponseEntity<List<PomodoroSessionResponse>> list(
            @RequestParam String date,
            @RequestParam(defaultValue = "0") int dayStartHour) {
        return ResponseEntity.ok(service.list(
            LocalDate.parse(date), ZoneId.systemDefault(), dayStartHour));
    }

    @PostMapping("/{id}/insight")
    public ResponseEntity<SessionInsightResponse> generateInsight(@PathVariable Long id) {
        return ResponseEntity.ok(insightService.generate(id));
    }

    @GetMapping("/{id}/insight")
    public ResponseEntity<SessionInsightResponse> getInsight(@PathVariable Long id) {
        return insightService.fetchExisting(id)
            .map(ResponseEntity::ok)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "no insight yet"));
    }
}
