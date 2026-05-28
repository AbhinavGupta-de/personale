package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.CategoryBreakdownEntry;
import com.abhinavgpt.server.dto.CurrentActivityResponse;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Computes the live activity state for the desktop-pet companion (Shiro)
 * from the currently-active app_session plus today's tracked time.
 *
 * State machine (away | idle | break | scattered | focused) is the core
 * logic here; everything else (category resolution, day-windowed totals)
 * is delegated to CategoryResolver / StatsService so this stays a thin
 * decision layer.
 */
@Service
public class ActivityService {

    /** A category counts as "break-like" only when it is the dedicated Break
     *  category: not work hours AND named exactly "Break". */
    private static final String BREAK_CATEGORY = "Break";
    private static final long AWAY_AFTER_SECONDS = 5 * 60;   // > 5 min since last session ended → away
    private static final int FOCUSED_AFTER_MINUTES = 15;      // sustained block ≥ 15 min → focused
    private static final int SCATTERED_SWITCHES = 12;         // ≥ 12 switches/last hour → scattered

    private final AppSessionRepository sessionRepo;
    private final CategoryResolver categoryResolver;
    private final CategoryThresholdRepository thresholdRepo;
    private final StatsService statsService;

    public ActivityService(AppSessionRepository sessionRepo,
                           CategoryResolver categoryResolver,
                           CategoryThresholdRepository thresholdRepo,
                           StatsService statsService) {
        this.sessionRepo = sessionRepo;
        this.categoryResolver = categoryResolver;
        this.thresholdRepo = thresholdRepo;
        this.statsService = statsService;
    }

    /**
     * Live activity snapshot. `findActiveSession()` uses FOR UPDATE, so this
     * must run in a transaction.
     */
    @Transactional
    public CurrentActivityResponse getCurrentActivity(ZoneId zone, Instant now,
                                                      int dayStartHour, int targetHours) {
        Optional<AppSession> active = sessionRepo.findActiveSession();
        int contextSwitchesLastHour =
            (int) sessionRepo.countSessionsStartedSince(now.minus(Duration.ofHours(1)));
        double dailyTargetPct = computeDailyTargetPct(zone, now, dayStartHour, targetHours);

        String category;
        String app;
        String state;
        int focusMinutes;

        if (active.isEmpty()) {
            category = "";
            app = "";
            focusMinutes = 0;
            state = awayOrIdle(now);
        } else {
            AppSession s = active.get();
            category = categoryResolver.categoryForBundle(s.getBundleId());
            app = s.getAppName() != null ? s.getAppName() : "";
            focusMinutes = (int) Duration.between(s.getStartedAt(), now).toMinutes();
            if (focusMinutes < 0) focusMinutes = 0;
            state = resolveActiveState(category, focusMinutes, contextSwitchesLastHour);
        }

        return new CurrentActivityResponse(
            category, app, state, focusMinutes, contextSwitchesLastHour,
            dailyTargetPct, Instant.now().toString());
    }

    /** No active session: away if the last session ended > 5 min ago, else idle. */
    private String awayOrIdle(Instant now) {
        Optional<Instant> lastEnded = sessionRepo.findMostRecentEndedAt();
        if (lastEnded.isEmpty()) return "idle";
        long sinceSeconds = Duration.between(lastEnded.get(), now).getSeconds();
        return sinceSeconds > AWAY_AFTER_SECONDS ? "away" : "idle";
    }

    /** Active session: break > scattered > focused > idle, in that precedence. */
    private String resolveActiveState(String category, int focusMinutes, int contextSwitchesLastHour) {
        if (isBreakLike(category)) return "break";
        if (contextSwitchesLastHour >= SCATTERED_SWITCHES) return "scattered";
        if (focusMinutes >= FOCUSED_AFTER_MINUTES) return "focused";
        return "idle";
    }

    /** Break-like = a category whose workHours flag is false AND name equals "Break". */
    private boolean isBreakLike(String category) {
        if (!BREAK_CATEGORY.equals(category)) return false;
        return thresholdRepo.findById(category)
            .map(t -> !t.isWorkHours())
            .orElse(false);
    }

    /**
     * (work-hours tracked seconds today) / (targetHours * 3600), clamped to >= 0.
     * Uses the same day-windowing the other stats endpoints use (effective day
     * via dayStartHour). May exceed 1.0. Returns 0 when targetHours <= 0.
     */
    private double computeDailyTargetPct(ZoneId zone, Instant now, int dayStartHour, int targetHours) {
        if (targetHours <= 0) return 0.0;

        LocalDate today = effectiveDate(now, zone, dayStartHour);
        List<CategoryBreakdownEntry> breakdown =
            statsService.getCategoryBreakdown(today, zone, now, dayStartHour);

        Map<String, Boolean> workHoursByCategory = new HashMap<>();
        for (CategoryThreshold t : thresholdRepo.findAll()) {
            workHoursByCategory.put(t.getCategory(), t.isWorkHours());
        }

        long workSeconds = 0;
        for (CategoryBreakdownEntry e : breakdown) {
            if (Boolean.TRUE.equals(workHoursByCategory.get(e.category()))) {
                workSeconds += e.totalSeconds();
            }
        }

        double pct = workSeconds / (targetHours * 3600.0);
        return Math.max(0.0, pct);
    }

    /** The logical date whose [dayStartHour, dayStartHour+24h) window contains `now`. */
    private static LocalDate effectiveDate(Instant now, ZoneId zone, int dayStartHour) {
        LocalDateTime ldt = LocalDateTime.ofInstant(now, zone);
        int shift = Math.max(0, Math.min(23, dayStartHour));
        return ldt.getHour() < shift ? ldt.toLocalDate().minusDays(1) : ldt.toLocalDate();
    }
}
