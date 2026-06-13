package com.abhinavgpt.server.service;

import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ExportServiceTest {

    @Mock
    private AppSessionRepository appSessionRepository;

    @Mock
    private BrowserEventRepository browserEventRepository;

    private ExportService service;

    @BeforeEach
    void setUp() {
        service = new ExportService(appSessionRepository, browserEventRepository);
    }

    @Test
    void exportAppSessionsCsv_escapesCommaQuoteAndNewline() {
        AppSession session = new AppSession(
            "Editor, Pro",
            "com.example.\"editor\"",
            "Line one\nLine two",
            Instant.parse("2026-03-07T10:00:00Z"));
        session.setId(7L);
        session.setEndedAt(Instant.parse("2026-03-07T10:05:30Z"));
        when(appSessionRepository.findByStartedAtBetween(any(), any())).thenReturn(List.of(session));

        String csv = service.exportAppSessionsCsv(
            LocalDate.of(2026, 3, 7), LocalDate.of(2026, 3, 7), ZoneOffset.UTC);

        assertThat(csv).isEqualTo(
            "id,app_name,bundle_id,window_title,started_at,ended_at,duration_seconds\r\n"
                + "7,\"Editor, Pro\",\"com.example.\"\"editor\"\"\",\"Line one\nLine two\","
                + "2026-03-07T10:00:00Z,2026-03-07T10:05:30Z,330\r\n");
    }

    @Test
    void exportAppSessionsJson_exposesExpectedFieldNamesAndValues() {
        AppSession session = new AppSession(
            "Safari", "com.apple.Safari", "Docs", Instant.parse("2026-03-07T10:00:00Z"));
        session.setId(11L);
        session.setEndedAt(Instant.parse("2026-03-07T10:30:00Z"));
        when(appSessionRepository.findByStartedAtBetween(any(), any())).thenReturn(List.of(session));

        List<ExportService.AppSessionExportRow> rows = service.exportAppSessions(
            LocalDate.of(2026, 3, 7), LocalDate.of(2026, 3, 7), ZoneOffset.UTC);

        List<String> fieldNames = Arrays.stream(ExportService.AppSessionExportRow.class.getRecordComponents())
            .map(RecordComponent::getName)
            .toList();
        ExportService.AppSessionExportRow row = rows.get(0);

        assertThat(fieldNames).containsExactly(
            "id", "appName", "bundleId", "windowTitle", "startedAt", "endedAt", "durationSeconds");
        assertThat(row.id()).isEqualTo(11L);
        assertThat(row.appName()).isEqualTo("Safari");
        assertThat(row.bundleId()).isEqualTo("com.apple.Safari");
        assertThat(row.windowTitle()).isEqualTo("Docs");
        assertThat(row.startedAt()).isEqualTo(Instant.parse("2026-03-07T10:00:00Z"));
        assertThat(row.endedAt()).isEqualTo(Instant.parse("2026-03-07T10:30:00Z"));
        assertThat(row.durationSeconds()).isEqualTo(1800L);
    }

    @Test
    void exportAppSessions_queriesStartedAtWindowInProvidedZone() {
        when(appSessionRepository.findByStartedAtBetween(any(), any())).thenReturn(List.of());

        service.exportAppSessions(
            LocalDate.of(2026, 3, 7),
            LocalDate.of(2026, 3, 8),
            ZoneId.of("Asia/Kolkata"));

        ArgumentCaptor<Instant> startCaptor = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> endCaptor = ArgumentCaptor.forClass(Instant.class);
        verify(appSessionRepository).findByStartedAtBetween(startCaptor.capture(), endCaptor.capture());
        assertThat(startCaptor.getValue()).isEqualTo(Instant.parse("2026-03-06T18:30:00Z"));
        assertThat(endCaptor.getValue()).isEqualTo(Instant.parse("2026-03-08T18:30:00Z"));
    }

    @Test
    void exportBrowserEventsCsv_usesBrowserEventEntityColumns() {
        BrowserEvent event = new BrowserEvent(
            "example.com",
            "Example",
            "https://example.com",
            "Safari",
            Instant.parse("2026-03-07T10:00:00Z"));
        event.setId(3L);
        when(browserEventRepository.findByStartedAtBetween(any(), any())).thenReturn(List.of(event));

        String csv = service.exportBrowserEventsCsv(
            LocalDate.of(2026, 3, 7), LocalDate.of(2026, 3, 7), ZoneOffset.UTC);

        assertThat(csv).isEqualTo(
            "id,domain,title,url,browser,timestamp\r\n"
                + "3,example.com,Example,https://example.com,Safari,2026-03-07T10:00:00Z\r\n");
    }
}
