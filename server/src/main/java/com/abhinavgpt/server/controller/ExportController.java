package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.service.ExportService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.Locale;

@RestController
@RequestMapping("/api/export")
public class ExportController {

    private static final MediaType TEXT_CSV = MediaType.parseMediaType("text/csv");

    private final ExportService exportService;

    public ExportController(ExportService exportService) {
        this.exportService = exportService;
    }

    @GetMapping
    public ResponseEntity<?> exportAppSessions(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "json") String format) {
        LocalDate fromDate = LocalDate.parse(from);
        LocalDate toDate = LocalDate.parse(to);
        ZoneId zone = exportZone();
        return switch (normalizedFormat(format)) {
            case "json" -> ResponseEntity.ok(exportService.exportAppSessions(fromDate, toDate, zone));
            case "csv" -> ResponseEntity.ok()
                .contentType(TEXT_CSV)
                .body(exportService.exportAppSessionsCsv(fromDate, toDate, zone));
            default -> throw new IllegalArgumentException("format must be json or csv");
        };
    }

    @GetMapping("/browser")
    public ResponseEntity<?> exportBrowserEvents(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(defaultValue = "json") String format) {
        LocalDate fromDate = LocalDate.parse(from);
        LocalDate toDate = LocalDate.parse(to);
        ZoneId zone = exportZone();
        return switch (normalizedFormat(format)) {
            case "json" -> ResponseEntity.ok(exportService.exportBrowserEvents(fromDate, toDate, zone));
            case "csv" -> ResponseEntity.ok()
                .contentType(TEXT_CSV)
                .body(exportService.exportBrowserEventsCsv(fromDate, toDate, zone));
            default -> throw new IllegalArgumentException("format must be json or csv");
        };
    }

    private ZoneId exportZone() {
        // Calendar dates use the server's system-default zone; the export window is
        // [from 00:00, to + 1 day 00:00), matching local desktop tracking days.
        return ZoneId.systemDefault();
    }

    private String normalizedFormat(String format) {
        return format.toLowerCase(Locale.ROOT);
    }

    @ExceptionHandler(DateTimeParseException.class)
    public ResponseEntity<String> handleBadDate(DateTimeParseException ex) {
        return ResponseEntity.badRequest().body("Invalid date: " + ex.getParsedString());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleValidation(IllegalArgumentException ex) {
        return ResponseEntity.badRequest().body(ex.getMessage());
    }
}
