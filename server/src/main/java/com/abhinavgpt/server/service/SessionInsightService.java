package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.SessionInsightResponse;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.entity.PomodoroSession;
import com.abhinavgpt.server.entity.PomodoroSessionInsight;
import com.abhinavgpt.server.repository.AppSessionRepository;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import com.abhinavgpt.server.repository.PomodoroSessionInsightRepository;
import com.abhinavgpt.server.repository.PomodoroSessionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * M16 — generates an AI title + description for a pomodoro session by summarizing
 * the app sessions and browser domains active during that window. Uses Anthropic
 * Messages API directly over HTTP (no SDK dependency) with claude-haiku for cost.
 * Key via env var ANTHROPIC_API_KEY. Idempotent per session id.
 */
@Service
public class SessionInsightService {

    private static final String API_URL = "https://api.anthropic.com/v1/messages";
    private static final String DEFAULT_MODEL = "claude-haiku-4-5";

    private final PomodoroSessionRepository pomodoroRepo;
    private final PomodoroSessionInsightRepository insightRepo;
    private final AppSessionRepository appSessionRepo;
    private final BrowserEventRepository browserEventRepo;
    private final HttpClient http;
    private final String apiKey;
    private final String model;

    public SessionInsightService(
            PomodoroSessionRepository pomodoroRepo,
            PomodoroSessionInsightRepository insightRepo,
            AppSessionRepository appSessionRepo,
            BrowserEventRepository browserEventRepo,
            @Value("${ANTHROPIC_API_KEY:}") String apiKey,
            @Value("${personale.insight.model:" + DEFAULT_MODEL + "}") String model) {
        this.pomodoroRepo = pomodoroRepo;
        this.insightRepo = insightRepo;
        this.appSessionRepo = appSessionRepo;
        this.browserEventRepo = browserEventRepo;
        this.apiKey = apiKey;
        this.model = model;
        this.http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10)).build();
    }

    public Optional<SessionInsightResponse> fetchExisting(Long sessionId) {
        return insightRepo.findById(sessionId).map(this::toResponse);
    }

    /** Generate a title/description for a window [start, end). Returns (title, description). */
    public String[] generateForWindow(String goal, Instant start, Instant end) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                "ANTHROPIC_API_KEY not configured");
        }
        String summary = buildActivitySummary(start, end);
        String prompt = buildPrompt(goal, summary);
        String json = """
            {
              "model": "%s",
              "max_tokens": 300,
              "messages": [{"role": "user", "content": %s}]
            }
            """.formatted(model, jsonEscape(prompt));
        HttpRequest req = HttpRequest.newBuilder(URI.create(API_URL))
            .timeout(Duration.ofSeconds(20))
            .header("Content-Type", "application/json")
            .header("x-api-key", apiKey)
            .header("anthropic-version", "2023-06-01")
            .POST(HttpRequest.BodyPublishers.ofString(json))
            .build();
        HttpResponse<String> res;
        try {
            res = http.send(req, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Anthropic request failed: " + e.getMessage());
        }
        if (res.statusCode() < 200 || res.statusCode() >= 300) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Anthropic returned " + res.statusCode() + ": " + res.body());
        }
        String content = extractText(res.body());
        String title = extractTag(content, "title", 80);
        String description = extractTag(content, "description", 400);
        if (title.isEmpty()) title = goal == null ? "Focus session" : goal;
        if (description.isEmpty()) description = "No summary available.";
        return new String[]{title, description, model};
    }

    public SessionInsightResponse generate(Long sessionId) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                "ANTHROPIC_API_KEY not configured");
        }

        PomodoroSession session = pomodoroRepo.findById(sessionId).orElseThrow(
            () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "pomodoro session not found"));

        Instant start = session.getStartedAt();
        Instant end = session.getEndedAt() != null ? session.getEndedAt() : Instant.now();

        String summary = buildActivitySummary(start, end);
        String prompt = buildPrompt(session.getGoal(), summary);

        String json = """
            {
              "model": "%s",
              "max_tokens": 300,
              "messages": [{"role": "user", "content": %s}]
            }
            """.formatted(model, jsonEscape(prompt));

        HttpRequest req = HttpRequest.newBuilder(URI.create(API_URL))
            .timeout(Duration.ofSeconds(20))
            .header("Content-Type", "application/json")
            .header("x-api-key", apiKey)
            .header("anthropic-version", "2023-06-01")
            .POST(HttpRequest.BodyPublishers.ofString(json))
            .build();

        HttpResponse<String> res;
        try {
            res = http.send(req, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Anthropic request failed: " + e.getMessage());
        }
        if (res.statusCode() < 200 || res.statusCode() >= 300) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                "Anthropic returned " + res.statusCode() + ": " + res.body());
        }

        String content = extractText(res.body());
        String title = extractTag(content, "title", 80);
        String description = extractTag(content, "description", 400);
        if (title.isEmpty()) title = session.getGoal();
        if (description.isEmpty()) description = "No summary available.";

        // Upsert
        PomodoroSessionInsight existing = insightRepo.findById(sessionId).orElse(null);
        PomodoroSessionInsight entity;
        if (existing != null) {
            existing.setTitle(title);
            existing.setDescription(description);
            existing.setModel(model);
            existing.setGeneratedAt(Instant.now());
            existing.markPersisted();
            entity = existing;
        } else {
            entity = new PomodoroSessionInsight(sessionId, title, description, model);
        }
        PomodoroSessionInsight saved = insightRepo.save(entity);
        saved.markPersisted();
        return toResponse(saved);
    }

    // ── prompt construction ──

    private String buildActivitySummary(Instant start, Instant end) {
        List<AppSession> sessions = appSessionRepo.findSessionsOverlapping(start, end);
        Map<String, long[]> perApp = new HashMap<>();       // [seconds, count]
        Map<String, String> titles = new HashMap<>();
        for (AppSession s : sessions) {
            Instant effStart = s.getStartedAt().isBefore(start) ? start : s.getStartedAt();
            Instant effEnd = s.getEndedAt() == null ? end
                : (s.getEndedAt().isAfter(end) ? end : s.getEndedAt());
            long secs = Math.max(0, Duration.between(effStart, effEnd).getSeconds());
            if (secs == 0) continue;
            String app = s.getAppName();
            long[] agg = perApp.computeIfAbsent(app, k -> new long[2]);
            agg[0] += secs;
            agg[1] += 1;
            if (s.getWindowTitle() != null && titles.get(app) == null) {
                titles.put(app, s.getWindowTitle());
            }
        }

        List<BrowserEvent> events = browserEventRepo.findByTimestampBetween(start, end);
        Map<String, Long> perDomain = new HashMap<>();
        for (BrowserEvent e : events) {
            perDomain.merge(e.getDomain(), 1L, Long::sum);
        }

        StringBuilder sb = new StringBuilder();
        sb.append("Apps used (seconds, session count):\n");
        perApp.entrySet().stream()
            .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
            .limit(10)
            .forEach(e -> sb.append("- ").append(e.getKey())
                .append(" — ").append(e.getValue()[0]).append("s, ")
                .append(e.getValue()[1]).append(" sessions")
                .append(titles.containsKey(e.getKey())
                    ? " (sample window title: \"" + clip(titles.get(e.getKey()), 80) + "\")"
                    : "")
                .append("\n"));

        if (!perDomain.isEmpty()) {
            sb.append("\nBrowser domains visited (visit count):\n");
            perDomain.entrySet().stream()
                .sorted((a, b) -> Long.compare(b.getValue(), a.getValue()))
                .limit(15)
                .forEach(e -> sb.append("- ").append(e.getKey()).append(" — ").append(e.getValue()).append("\n"));
        }
        return sb.toString();
    }

    private String buildPrompt(String goal, String summary) {
        return """
            You are summarizing a single focus session from a time-tracking app. Produce:
            - a concise TITLE (4-8 words) describing what the user did
            - a 1-2 sentence DESCRIPTION of the actual activity

            Be specific. Favor concrete nouns from the data (repo names, domain names,
            window titles) over generic phrases like "worked on code".

            Return exactly this format:
            <title>...</title>
            <description>...</description>

            User's stated goal: %s

            Activity data:
            %s
            """.formatted(goal == null ? "(none)" : goal, summary);
    }

    // ── response parsing ──

    private static final Pattern TEXT_FIELD = Pattern.compile("\"text\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"");

    private String extractText(String body) {
        Matcher m = TEXT_FIELD.matcher(body);
        if (m.find()) return unescape(m.group(1));
        return "";
    }

    private String extractTag(String text, String tag, int max) {
        Pattern p = Pattern.compile("<" + tag + ">(.*?)</" + tag + ">", Pattern.DOTALL);
        Matcher m = p.matcher(text);
        if (!m.find()) return "";
        String v = m.group(1).trim();
        return v.length() > max ? v.substring(0, max) : v;
    }

    private static String jsonEscape(String s) {
        StringBuilder sb = new StringBuilder("\"");
        for (char c : s.toCharArray()) {
            switch (c) {
                case '\\': sb.append("\\\\"); break;
                case '"':  sb.append("\\\""); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
            }
        }
        return sb.append('"').toString();
    }

    private static String unescape(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\\' && i + 1 < s.length()) {
                char n = s.charAt(++i);
                switch (n) {
                    case '"': sb.append('"'); break;
                    case '\\': sb.append('\\'); break;
                    case 'n': sb.append('\n'); break;
                    case 'r': sb.append('\r'); break;
                    case 't': sb.append('\t'); break;
                    case 'u':
                        if (i + 4 < s.length()) {
                            sb.append((char) Integer.parseInt(s.substring(i + 1, i + 5), 16));
                            i += 4;
                        }
                        break;
                    default: sb.append(n);
                }
            } else { sb.append(c); }
        }
        return sb.toString();
    }

    private static String clip(String s, int max) {
        return s.length() > max ? s.substring(0, max) : s;
    }

    private SessionInsightResponse toResponse(PomodoroSessionInsight i) {
        return new SessionInsightResponse(
            i.getSessionId(), i.getTitle(), i.getDescription(),
            i.getModel(), i.getGeneratedAt().toString()
        );
    }
}
