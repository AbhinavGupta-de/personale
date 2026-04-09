package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.BrowserEventRequest;
import com.abhinavgpt.server.service.BrowserEventService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.format.DateTimeParseException;

@RestController
@RequestMapping("/api")
public class BrowserEventController {

    private static final Logger log = LoggerFactory.getLogger(BrowserEventController.class);
    private final BrowserEventService browserEventService;

    public BrowserEventController(BrowserEventService browserEventService) {
        this.browserEventService = browserEventService;
    }

    @PostMapping("/events/browser")
    public ResponseEntity<Void> receiveBrowserEvent(@RequestBody BrowserEventRequest event) {
        log.info("[{}] Browser: {} — {}", event.timestamp(), event.domain(), event.title());
        browserEventService.saveBrowserEvent(event);
        return ResponseEntity.ok().build();
    }

    @ExceptionHandler(DateTimeParseException.class)
    public ResponseEntity<String> handleBadTimestamp(DateTimeParseException ex) {
        return ResponseEntity.badRequest().body("Invalid timestamp: " + ex.getParsedString());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleValidation(IllegalArgumentException ex) {
        return ResponseEntity.badRequest().body(ex.getMessage());
    }
}
