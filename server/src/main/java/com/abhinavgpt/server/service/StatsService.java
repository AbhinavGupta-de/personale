package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.AppTimeEntry;
import com.abhinavgpt.server.dto.DailyStatsResponse;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.repository.AppSessionRepository;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class StatsService {

    private final AppSessionRepository repository;

    public StatsService(AppSessionRepository repository) {
        this.repository = repository;
    }

    public DailyStatsResponse getTimePerAppToday(ZoneId zone, Instant now) {
        LocalDate today = LocalDate.ofInstant(now, zone);
        Instant startOfDay = today.atStartOfDay(zone).toInstant();
        Instant endOfDay = today.plusDays(1).atStartOfDay(zone).toInstant();

        List<AppSession> sessions = repository.findSessionsOverlapping(startOfDay, endOfDay);

        // Group by bundleId (more reliable than appName), sum durations
        Map<String, long[]> timeByBundle = new LinkedHashMap<>();
        Map<String, String> nameByBundle = new LinkedHashMap<>();

        for (AppSession session : sessions) {
            String key = session.getBundleId() != null ? session.getBundleId() : session.getAppName();

            // Clamp session boundaries to the day window
            Instant effectiveStart = session.getStartedAt().isBefore(startOfDay) ? startOfDay : session.getStartedAt();
            Instant effectiveEnd = session.getEndedAt() != null ? session.getEndedAt() : now;
            if (effectiveEnd.isAfter(endOfDay)) {
                effectiveEnd = endOfDay;
            }

            long seconds = Math.max(0, Duration.between(effectiveStart, effectiveEnd).getSeconds());

            timeByBundle.computeIfAbsent(key, k -> new long[1]);
            timeByBundle.get(key)[0] += seconds;
            nameByBundle.putIfAbsent(key, session.getAppName());
        }

        List<AppTimeEntry> apps = timeByBundle.entrySet().stream()
            .map(e -> {
                String bundleId = e.getKey().equals(nameByBundle.get(e.getKey())) ? null : e.getKey();
                return new AppTimeEntry(nameByBundle.get(e.getKey()), bundleId, e.getValue()[0]);
            })
            .sorted(Comparator.comparingLong(AppTimeEntry::totalSeconds).reversed())
            .toList();

        long total = apps.stream().mapToLong(AppTimeEntry::totalSeconds).sum();

        return new DailyStatsResponse(today.toString(), apps, total);
    }
}
