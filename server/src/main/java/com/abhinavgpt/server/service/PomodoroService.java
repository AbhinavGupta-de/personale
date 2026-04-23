package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.PomodoroSessionResponse;
import com.abhinavgpt.server.dto.PomodoroStartRequest;
import com.abhinavgpt.server.entity.PomodoroSession;
import com.abhinavgpt.server.repository.PomodoroSessionRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

@Service
public class PomodoroService {

    private final PomodoroSessionRepository repo;

    public PomodoroService(PomodoroSessionRepository repo) {
        this.repo = repo;
    }

    public PomodoroSessionResponse start(PomodoroStartRequest req) {
        String goal = req.goal() == null || req.goal().isBlank()
            ? "Untitled session" : req.goal().trim();
        int target = req.targetSeconds() != null && req.targetSeconds() > 0
            ? req.targetSeconds() : 25 * 60;
        PomodoroSession s = new PomodoroSession(goal, Instant.now(), target);
        return toResponse(repo.save(s));
    }

    public PomodoroSessionResponse end(Long id, boolean discard) {
        PomodoroSession s = repo.findById(id).orElseThrow(
            () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "session not found"));
        s.setEndedAt(Instant.now());
        s.setStatus(discard ? "discarded" : "completed");
        return toResponse(repo.save(s));
    }

    public List<PomodoroSessionResponse> list(LocalDate date, ZoneId zone, int dayStartHour) {
        int shift = Math.max(0, Math.min(23, dayStartHour));
        Instant start = date.atStartOfDay(zone).plusHours(shift).toInstant();
        Instant end = date.plusDays(1).atStartOfDay(zone).plusHours(shift).toInstant();
        List<PomodoroSessionResponse> out = new ArrayList<>();
        for (PomodoroSession s : repo.findByStartedAtBetween(start, end)) {
            out.add(toResponse(s));
        }
        return out;
    }

    private PomodoroSessionResponse toResponse(PomodoroSession s) {
        int duration = s.getEndedAt() != null
            ? (int) Duration.between(s.getStartedAt(), s.getEndedAt()).getSeconds()
            : (int) Duration.between(s.getStartedAt(), Instant.now()).getSeconds();
        return new PomodoroSessionResponse(
            s.getId(), s.getGoal(),
            s.getStartedAt().toString(),
            s.getEndedAt() != null ? s.getEndedAt().toString() : null,
            s.getTargetSeconds(),
            Math.max(0, duration),
            s.getStatus()
        );
    }
}
