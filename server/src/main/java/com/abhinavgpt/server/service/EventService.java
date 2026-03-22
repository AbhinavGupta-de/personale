package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AppSwitchEvent;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.repository.AppSessionRepository;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

@Service
public class EventService {

    private static final Logger log = LoggerFactory.getLogger(EventService.class);
    private final AppSessionRepository repository;

    public EventService(AppSessionRepository repository) {
        this.repository = repository;
    }

    @PostConstruct
    @Transactional
    public void closeOrphanedSessions() {
        repository.findActiveSession().ifPresent(orphan -> {
            orphan.setEndedAt(orphan.getStartedAt());
            repository.save(orphan);
            log.info("Closed orphaned session: {} (started at {})",
                orphan.getAppName(), orphan.getStartedAt());
        });
    }

    @Transactional
    public void closeActiveSession(Instant closedAt) {
        repository.findActiveSession().ifPresent(active -> {
            active.setEndedAt(closedAt);
            repository.save(active);
            log.info("Closed active session: {} at {}", active.getAppName(), closedAt);
        });
    }

    private static final long DEDUPE_WINDOW_SECONDS = 2;

    @Transactional
    public AppSession saveEvent(AppSwitchEvent event) {
        Instant eventTime = Instant.parse(event.timestamp());

        // Idempotency: skip if same bundle and timestamp within 2s of active session
        var existing = repository.findActiveSession();
        if (existing.isPresent()) {
            AppSession active = existing.get();
            boolean sameBundleId = event.bundleId() != null
                && event.bundleId().equals(active.getBundleId());
            boolean tooClose = Math.abs(
                Duration.between(active.getStartedAt(), eventTime).getSeconds()
            ) <= DEDUPE_WINDOW_SECONDS;
            if (sameBundleId && tooClose) {
                log.debug("Skipping duplicate event: {} at {} (active since {})",
                    event.appName(), eventTime, active.getStartedAt());
                return active;
            }

            // Close the currently active session
            active.setEndedAt(eventTime);
            repository.save(active);
        }

        // Open a new session
        AppSession session = new AppSession(
            event.appName(),
            event.bundleId(),
            event.windowTitle(),
            eventTime
        );
        return repository.save(session);
    }
}
