package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.AppSwitchEvent;
import com.abhinavgpt.server.dto.CloseSessionRequest;
import com.abhinavgpt.server.service.EventService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.time.format.DateTimeParseException;

@RestController
@RequestMapping("/api")
public class EventController {

    private static final Logger log = LoggerFactory.getLogger(EventController.class);
    private final EventService eventService;

    public EventController(EventService eventService) {
        this.eventService = eventService;
    }

    @PostMapping("/events")
    public ResponseEntity<Void> receiveEvent(@RequestBody AppSwitchEvent event) {
        log.info("[{}] Switched to: {} ({})",
            event.timestamp(),
            event.appName(),
            event.bundleId());
        eventService.saveEvent(event);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/events/close")
    public ResponseEntity<Void> closeSession(@RequestBody CloseSessionRequest request) {
        log.info("[{}] Session close requested (sleep/idle)", request.timestamp());
        eventService.closeActiveSession(Instant.parse(request.timestamp()));
        return ResponseEntity.ok().build();
    }

    @ExceptionHandler(DateTimeParseException.class)
    public ResponseEntity<String> handleBadTimestamp(DateTimeParseException ex) {
        return ResponseEntity.badRequest().body("Invalid timestamp: " + ex.getParsedString());
    }
}
