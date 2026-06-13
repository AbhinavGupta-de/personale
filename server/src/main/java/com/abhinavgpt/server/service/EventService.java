package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AppSwitchEvent;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.repository.AppSessionRepository;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.scheduling.annotation.Scheduled;
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

    // Cap recovered orphan sessions at this duration past their start.
    // Real focus sessions rarely exceed 4h without an app switch; anything
    // beyond is almost certainly a crashed Swift app that never closed.
    private static final Duration MAX_ACTIVE_SESSION = Duration.ofHours(4);
    // Fallback duration applied to an orphan when we have no signal of real activity.
    private static final Duration ORPHAN_RECOVERY_DURATION = Duration.ofMinutes(5);

    private static Instant cappedEnd(Instant startedAt, Instant proposedEnd) {
        if (proposedEnd.isBefore(startedAt)) return startedAt;
        Instant ceiling = startedAt.plus(MAX_ACTIVE_SESSION);
        return proposedEnd.isAfter(ceiling) ? startedAt.plus(ORPHAN_RECOVERY_DURATION) : proposedEnd;
    }

    @PostConstruct
    @Transactional
    public void closeOrphanedSessions() {
        repository.findActiveSession().ifPresent(orphan -> {
            Instant end = orphan.getStartedAt().plus(ORPHAN_RECOVERY_DURATION);
            orphan.setEndedAt(end);
            repository.save(orphan);
            log.info("Closed orphaned session on startup: {} (started {}, capped at {})",
                orphan.getAppName(), orphan.getStartedAt(), end);
        });
    }

    /** Runs every 5 min. Caps any active session older than MAX_ACTIVE_SESSION;
     *  protects against Swift AppTracker crashing/sleeping without sending close. */
    @Scheduled(fixedDelay = 5 * 60 * 1000L, initialDelay = 5 * 60 * 1000L)
    @Transactional
    public void capStaleActiveSessions() {
        repository.findActiveSession().ifPresent(active -> {
            Duration age = Duration.between(active.getStartedAt(), Instant.now());
            if (age.compareTo(MAX_ACTIVE_SESSION) <= 0) return;
            Instant end = active.getStartedAt().plus(ORPHAN_RECOVERY_DURATION);
            active.setEndedAt(end);
            repository.save(active);
            log.warn("Auto-capped stale active session {} (started {}, age {}h) → ended {}",
                active.getAppName(), active.getStartedAt(), age.toHours(), end);
        });
    }

    @Transactional
    public void closeActiveSession(Instant closedAt, String bundleId, Instant sessionStartedAt) {
        repository.findActiveSession().ifPresent(active -> {
            // If both identity fields are provided, verify they match the active session
            if (bundleId != null && sessionStartedAt != null) {
                boolean bundleMatch = bundleId.equals(active.getBundleId());
                boolean startMatch = sessionStartedAt.equals(active.getStartedAt());
                if (!bundleMatch || !startMatch) {
                    log.info("Rejecting stale close for {} (started {}) — active is {} (started {})",
                        bundleId, sessionStartedAt, active.getBundleId(), active.getStartedAt());
                    return;
                }
            }
            Instant endTime = cappedEnd(active.getStartedAt(), closedAt);
            active.setEndedAt(endTime);
            repository.save(active);
            log.info("Closed active session: {} at {}", active.getAppName(), endTime);
        });
    }

    @Transactional
    public AppSession recordIdleBlock(Instant start, Instant end) {
        Instant capped = cappedEnd(start, end);
        long seconds = Duration.between(start, capped).getSeconds();
        if (seconds < 60) {
            log.debug("Skipping idle block shorter than 60s: {} → {}", start, capped);
            return null;
        }
        return repository.save(AppSession.idleBlock(start, capped));
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

            // Close the currently active session, capping orphan ages so a crashed
            // tracker doesn't produce multi-day fake sessions on resume.
            Instant endTime = cappedEnd(active.getStartedAt(), eventTime);
            active.setEndedAt(endTime);
            repository.save(active);
        }

        // Open a new session — retry once if a concurrent request just inserted an active session
        AppSession session = new AppSession(
            event.appName(),
            event.bundleId(),
            event.windowTitle(),
            eventTime
        );
        session.setEnrichedContext(event.enrichedContext());
        try {
            return repository.save(session);
        } catch (DuplicateKeyException e) {
            // Another concurrent request created an active session; close it first, then retry
            log.warn("Concurrent active session detected, closing and retrying: {}", event.appName());
            repository.findActiveSession().ifPresent(stale -> {
                Instant endTime = cappedEnd(stale.getStartedAt(), eventTime);
                stale.setEndedAt(endTime);
                repository.save(stale);
            });
            return repository.save(session);
        }
    }
}
