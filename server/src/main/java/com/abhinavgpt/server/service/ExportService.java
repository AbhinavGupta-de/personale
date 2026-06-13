package com.abhinavgpt.server.service;

import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.List;

@Service
public class ExportService {

    private static final List<String> APP_CSV_HEADER = List.of(
        "id", "app_name", "bundle_id", "window_title", "started_at", "ended_at", "duration_seconds");
    private static final List<String> BROWSER_CSV_HEADER = List.of(
        "id", "domain", "title", "url", "browser", "timestamp");

    private final AppSessionRepository appSessionRepository;
    private final BrowserEventRepository browserEventRepository;

    public ExportService(AppSessionRepository appSessionRepository,
                         BrowserEventRepository browserEventRepository) {
        this.appSessionRepository = appSessionRepository;
        this.browserEventRepository = browserEventRepository;
    }

    public List<AppSessionExportRow> exportAppSessions(LocalDate from, LocalDate to, ZoneId zone) {
        DateWindow window = dateWindow(from, to, zone);
        return appSessionRepository.findByStartedAtBetween(window.start(), window.end()).stream()
            .map(this::toAppRow)
            .toList();
    }

    public String exportAppSessionsCsv(LocalDate from, LocalDate to, ZoneId zone) {
        return toCsv(APP_CSV_HEADER, exportAppSessions(from, to, zone).stream()
            .map(row -> Arrays.asList(
                stringValue(row.id()),
                stringValue(row.appName()),
                stringValue(row.bundleId()),
                stringValue(row.windowTitle()),
                stringValue(row.startedAt()),
                stringValue(row.endedAt()),
                stringValue(row.durationSeconds())))
            .toList());
    }

    public List<BrowserEventExportRow> exportBrowserEvents(LocalDate from, LocalDate to, ZoneId zone) {
        DateWindow window = dateWindow(from, to, zone);
        return browserEventRepository.findByStartedAtBetween(window.start(), window.end()).stream()
            .map(this::toBrowserRow)
            .toList();
    }

    public String exportBrowserEventsCsv(LocalDate from, LocalDate to, ZoneId zone) {
        return toCsv(BROWSER_CSV_HEADER, exportBrowserEvents(from, to, zone).stream()
            .map(row -> Arrays.asList(
                stringValue(row.id()),
                stringValue(row.domain()),
                stringValue(row.title()),
                stringValue(row.url()),
                stringValue(row.browser()),
                stringValue(row.timestamp())))
            .toList());
    }

    private DateWindow dateWindow(LocalDate from, LocalDate to, ZoneId zone) {
        if (to.isBefore(from)) {
            throw new IllegalArgumentException("to must be on or after from");
        }
        return new DateWindow(
            from.atStartOfDay(zone).toInstant(),
            to.plusDays(1).atStartOfDay(zone).toInstant());
    }

    private AppSessionExportRow toAppRow(AppSession session) {
        return new AppSessionExportRow(
            session.getId(),
            session.getAppName(),
            session.getBundleId(),
            session.getWindowTitle(),
            session.getStartedAt(),
            session.getEndedAt(),
            durationSeconds(session));
    }

    private BrowserEventExportRow toBrowserRow(BrowserEvent event) {
        return new BrowserEventExportRow(
            event.getId(),
            event.getDomain(),
            event.getTitle(),
            event.getUrl(),
            event.getBrowser(),
            event.getTimestamp());
    }

    private Long durationSeconds(AppSession session) {
        if (session.getStartedAt() == null || session.getEndedAt() == null) {
            return null;
        }
        return Duration.between(session.getStartedAt(), session.getEndedAt()).getSeconds();
    }

    private String toCsv(List<String> header, List<List<String>> rows) {
        StringBuilder csv = new StringBuilder();
        appendCsvRow(csv, header);
        for (List<String> row : rows) {
            appendCsvRow(csv, row);
        }
        return csv.toString();
    }

    private void appendCsvRow(StringBuilder csv, List<String> row) {
        for (int i = 0; i < row.size(); i++) {
            if (i > 0) {
                csv.append(',');
            }
            csv.append(escapeCsv(row.get(i)));
        }
        csv.append("\r\n");
    }

    private String escapeCsv(String value) {
        if (value == null) {
            return "";
        }
        boolean needsQuoting = value.indexOf(',') >= 0
            || value.indexOf('"') >= 0
            || value.indexOf('\r') >= 0
            || value.indexOf('\n') >= 0;
        if (!needsQuoting) {
            return value;
        }
        return "\"" + value.replace("\"", "\"\"") + "\"";
    }

    private String stringValue(Object value) {
        return value == null ? null : value.toString();
    }

    private record DateWindow(Instant start, Instant end) {}

    public record AppSessionExportRow(
        Long id,
        String appName,
        String bundleId,
        String windowTitle,
        Instant startedAt,
        Instant endedAt,
        Long durationSeconds) {}

    public record BrowserEventExportRow(
        Long id,
        String domain,
        String title,
        String url,
        String browser,
        Instant timestamp) {}
}
