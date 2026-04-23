package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.PomodoroSessionResponse;
import com.abhinavgpt.server.dto.PomodoroStartRequest;
import com.abhinavgpt.server.entity.PomodoroSession;
import com.abhinavgpt.server.repository.PomodoroSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PomodoroServiceTest {

    @Mock
    private PomodoroSessionRepository repo;

    private PomodoroService service;

    @BeforeEach
    void setUp() { service = new PomodoroService(repo); }

    @Test
    void start_nullGoalAndTarget_appliesDefaults() {
        when(repo.save(any(PomodoroSession.class))).thenAnswer(inv -> {
            PomodoroSession s = inv.getArgument(0);
            s.setId(1L);
            return s;
        });

        PomodoroSessionResponse r = service.start(new PomodoroStartRequest(null, null));

        assertThat(r.goal()).isEqualTo("Untitled session");
        assertThat(r.targetSeconds()).isEqualTo(25 * 60);
        assertThat(r.status()).isEqualTo("running");
        assertThat(r.endedAt()).isNull();
    }

    @Test
    void start_respectsProvidedTarget() {
        when(repo.save(any(PomodoroSession.class))).thenAnswer(inv -> {
            PomodoroSession s = inv.getArgument(0);
            s.setId(1L);
            return s;
        });

        PomodoroSessionResponse r = service.start(new PomodoroStartRequest("deep work", 45 * 60));

        assertThat(r.goal()).isEqualTo("deep work");
        assertThat(r.targetSeconds()).isEqualTo(45 * 60);
    }

    @Test
    void end_markCompletedByDefault() {
        PomodoroSession existing = new PomodoroSession("task", Instant.parse("2026-04-20T09:00:00Z"), 1500);
        existing.setId(7L);
        when(repo.findById(7L)).thenReturn(Optional.of(existing));
        when(repo.save(any(PomodoroSession.class))).thenAnswer(inv -> inv.getArgument(0));

        PomodoroSessionResponse r = service.end(7L, false);

        assertThat(r.status()).isEqualTo("completed");
        assertThat(r.endedAt()).isNotNull();
    }

    @Test
    void end_discardFlagMarksDiscarded() {
        PomodoroSession existing = new PomodoroSession("task", Instant.parse("2026-04-20T09:00:00Z"), 1500);
        existing.setId(7L);
        when(repo.findById(7L)).thenReturn(Optional.of(existing));
        when(repo.save(any(PomodoroSession.class))).thenAnswer(inv -> inv.getArgument(0));

        PomodoroSessionResponse r = service.end(7L, true);

        assertThat(r.status()).isEqualTo("discarded");
    }

    @Test
    void end_unknownId_throws() {
        when(repo.findById(99L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.end(99L, false))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void list_shiftsWindowByDayStartHour() {
        when(repo.findByStartedAtBetween(any(), any())).thenReturn(List.of());

        service.list(LocalDate.of(2026, 4, 20), ZoneOffset.UTC, 6);

        org.mockito.ArgumentCaptor<Instant> startCap = org.mockito.ArgumentCaptor.forClass(Instant.class);
        org.mockito.ArgumentCaptor<Instant> endCap = org.mockito.ArgumentCaptor.forClass(Instant.class);
        org.mockito.Mockito.verify(repo).findByStartedAtBetween(startCap.capture(), endCap.capture());
        assertThat(startCap.getValue()).isEqualTo(Instant.parse("2026-04-20T06:00:00Z"));
        assertThat(endCap.getValue()).isEqualTo(Instant.parse("2026-04-21T06:00:00Z"));
    }

    @Test
    void list_returnsRunningSessionDurationFromNow() {
        Instant started = Instant.now().minusSeconds(300);
        PomodoroSession running = new PomodoroSession("now", started, 1500);
        running.setId(1L);
        when(repo.findByStartedAtBetween(any(), any())).thenReturn(List.of(running));

        List<PomodoroSessionResponse> result = service.list(
            LocalDate.now(ZoneOffset.UTC), ZoneOffset.UTC, 0);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).durationSeconds()).isBetween(299, 320);
        assertThat(result.get(0).status()).isEqualTo("running");
    }
}
