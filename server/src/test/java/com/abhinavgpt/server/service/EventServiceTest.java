package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AppSwitchEvent;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.repository.AppSessionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EventServiceTest {

    @Mock
    private AppSessionRepository repository;

    @InjectMocks
    private EventService eventService;

    @Test
    void saveEvent_mapsFieldsCorrectly() {
        AppSwitchEvent event = new AppSwitchEvent(
            "Safari", "com.apple.Safari", "Google", "2026-03-07T10:00:00Z");
        when(repository.findActiveSession()).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        eventService.saveEvent(event);

        ArgumentCaptor<AppSession> captor = ArgumentCaptor.forClass(AppSession.class);
        verify(repository).save(captor.capture());

        AppSession session = captor.getValue();
        assertThat(session.getAppName()).isEqualTo("Safari");
        assertThat(session.getBundleId()).isEqualTo("com.apple.Safari");
        assertThat(session.getWindowTitle()).isEqualTo("Google");
        assertThat(session.getStartedAt()).isEqualTo(Instant.parse("2026-03-07T10:00:00Z"));
        assertThat(session.getEndedAt()).isNull();
    }

    @Test
    void saveEvent_parsesIso8601Timestamp() {
        AppSwitchEvent event = new AppSwitchEvent(
            "Terminal", "com.apple.Terminal", null, "2026-03-07T14:30:00Z");
        when(repository.findActiveSession()).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        eventService.saveEvent(event);

        ArgumentCaptor<AppSession> captor = ArgumentCaptor.forClass(AppSession.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getStartedAt()).isEqualTo(Instant.parse("2026-03-07T14:30:00Z"));
    }

    @Test
    void saveEvent_returnsPersistedSession() {
        AppSwitchEvent event = new AppSwitchEvent(
            "Safari", "com.apple.Safari", null, "2026-03-07T10:00:00Z");
        when(repository.findActiveSession()).thenReturn(Optional.empty());
        AppSession expected = new AppSession("Safari", "com.apple.Safari", null, Instant.now());
        expected.setId(1L);
        when(repository.save(any())).thenReturn(expected);

        AppSession result = eventService.saveEvent(event);

        assertThat(result.getId()).isEqualTo(1L);
    }

    @Test
    void saveEvent_invalidTimestamp_throwsException() {
        AppSwitchEvent event = new AppSwitchEvent(
            "Safari", "com.apple.Safari", null, "not-a-timestamp");

        assertThatThrownBy(() -> eventService.saveEvent(event))
            .isInstanceOf(java.time.format.DateTimeParseException.class);
    }

    @Test
    void saveEvent_closesActiveSession() {
        AppSession active = new AppSession(
            "Safari", "com.apple.Safari", null, Instant.parse("2026-03-07T10:00:00Z"));
        active.setId(1L);
        when(repository.findActiveSession()).thenReturn(Optional.of(active));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        AppSwitchEvent event = new AppSwitchEvent(
            "Terminal", "com.apple.Terminal", null, "2026-03-07T10:30:00Z");

        eventService.saveEvent(event);

        // Two saves: one to close active, one for new session
        ArgumentCaptor<AppSession> captor = ArgumentCaptor.forClass(AppSession.class);
        verify(repository, times(2)).save(captor.capture());

        AppSession closed = captor.getAllValues().get(0);
        assertThat(closed.getId()).isEqualTo(1L);
        assertThat(closed.getEndedAt()).isEqualTo(Instant.parse("2026-03-07T10:30:00Z"));

        AppSession opened = captor.getAllValues().get(1);
        assertThat(opened.getAppName()).isEqualTo("Terminal");
        assertThat(opened.getEndedAt()).isNull();
    }

    @Test
    void saveEvent_noActiveSession_onlySavesNewSession() {
        when(repository.findActiveSession()).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        AppSwitchEvent event = new AppSwitchEvent(
            "Safari", "com.apple.Safari", null, "2026-03-07T10:00:00Z");

        eventService.saveEvent(event);

        verify(repository, times(1)).save(any());
        verify(repository, never()).findById(any());
    }

    @Test
    void closeActiveSession_closesExistingSession() {
        AppSession active = new AppSession(
            "Safari", "com.apple.Safari", null, Instant.parse("2026-03-07T10:00:00Z"));
        active.setId(1L);
        when(repository.findActiveSession()).thenReturn(Optional.of(active));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Instant closeTime = Instant.parse("2026-03-07T10:30:00Z");
        eventService.closeActiveSession(closeTime);

        ArgumentCaptor<AppSession> captor = ArgumentCaptor.forClass(AppSession.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getEndedAt()).isEqualTo(closeTime);
    }

    @Test
    void closeActiveSession_noActiveSession_doesNothing() {
        when(repository.findActiveSession()).thenReturn(Optional.empty());

        eventService.closeActiveSession(Instant.parse("2026-03-07T10:00:00Z"));

        verify(repository, never()).save(any());
    }
}
