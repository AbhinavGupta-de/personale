package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.BrowserEventRequest;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
public class BrowserEventService {

    private static final Logger log = LoggerFactory.getLogger(BrowserEventService.class);
    private final BrowserEventRepository repository;

    public BrowserEventService(BrowserEventRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public BrowserEvent saveBrowserEvent(BrowserEventRequest request) {
        if (request.domain() == null || request.domain().isBlank()) {
            throw new IllegalArgumentException("domain is required");
        }
        if (request.timestamp() == null || request.timestamp().isBlank()) {
            throw new IllegalArgumentException("timestamp is required");
        }

        Instant timestamp = Instant.parse(request.timestamp());

        BrowserEvent event = new BrowserEvent(
            request.domain(),
            request.title(),
            request.url(),
            request.browser(),
            timestamp
        );

        BrowserEvent saved = repository.save(event);
        log.info("[{}] Browser event: {} — {}", request.timestamp(), request.domain(), request.title());
        return saved;
    }
}
