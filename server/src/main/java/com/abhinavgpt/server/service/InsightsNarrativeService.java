package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.InsightsNarrativeResponse;
import com.abhinavgpt.server.dto.InsightsOverviewResponse;
import com.abhinavgpt.server.dto.InsightsOverviewResponse.*;
import com.abhinavgpt.server.entity.SessionReview;
import com.abhinavgpt.server.repository.SessionReviewRepository;
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
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Asks Haiku for a short self-knowledge writeup about the user's last N days.
 * Same wire-style as `SessionInsightService` (raw HTTP, no SDK). Reads from
 * `InsightsService` for stats + `SessionReviewRepository` for the user's
 * already-reviewed block titles, so the narrative cites real activities by
 * name instead of generic "you used a coding app" filler.
 *
 * Not cached — the user explicitly hits "Generate" to call. Keeps Anthropic
 * spend under their control, since the page is otherwise free to render.
 */
@Service
public class InsightsNarrativeService {

    private static final String API_URL = "https://api.anthropic.com/v1/messages";
    private static final String DEFAULT_MODEL = "claude-haiku-4-5";

    private final InsightsService insightsService;
    private final SessionReviewRepository reviewRepo;
    private final HttpClient http;
    private final String apiKey;
    private final String model;

    public InsightsNarrativeService(InsightsService insightsService,
                                    SessionReviewRepository reviewRepo,
                                    @Value("${ANTHROPIC_API_KEY:}") String apiKey,
                                    @Value("${personale.insight.model:" + DEFAULT_MODEL + "}") String model) {
        this.insightsService = insightsService;
        this.reviewRepo = reviewRepo;
        this.apiKey = apiKey;
        this.model = model;
        this.http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10)).build();
    }

    public InsightsNarrativeResponse generate(LocalDate from, LocalDate to,
                                              ZoneId zone, Instant now, int dayStartHour) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                "ANTHROPIC_API_KEY not configured");
        }
        InsightsOverviewResponse overview = insightsService.getOverview(
            from, to, zone, now, dayStartHour);
        String summary = buildSummary(overview, from, to);
        String prompt = buildPrompt(summary);
        String json = """
            {
              "model": "%s",
              "max_tokens": 700,
              "messages": [{"role": "user", "content": %s}]
            }
            """.formatted(model, jsonEscape(prompt));
        HttpRequest req = HttpRequest.newBuilder(URI.create(API_URL))
            .timeout(Duration.ofSeconds(40))
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
        return new InsightsNarrativeResponse(
            from.toString(), to.toString(),
            extractTag(content, "summary", 800),
            extractListTag(content, "patterns"),
            extractListTag(content, "wins"),
            extractListTag(content, "watchouts"),
            model,
            Instant.now().toString());
    }

    // ── prompt construction ──

    private String buildSummary(InsightsOverviewResponse o, LocalDate from, LocalDate to) {
        StringBuilder sb = new StringBuilder();
        sb.append("Range: ").append(from).append(" to ").append(to)
          .append(" (").append(o.daysWithData()).append(" days with data).\n");
        sb.append("Totals: ")
          .append("tracked ").append(formatHours(o.totalTrackedSeconds()))
          .append(", productive ").append(formatHours(o.totalProductiveSeconds()))
          .append(", context switches ").append(o.totalContextSwitches())
          .append(".\n");

        sb.append("\nDay-of-week productive averages:\n");
        String[] dowNames = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"};
        for (DayOfWeekStat s : o.dayOfWeek()) {
            if (s.days() == 0) continue;
            sb.append("- ").append(dowNames[s.weekday() - 1])
              .append(": ").append(formatHours(s.avgProductiveSeconds()))
              .append(" productive / ").append(formatHours(s.avgTotalSeconds()))
              .append(" total over ").append(s.days()).append(" days\n");
        }

        sb.append("\nTop hours of the week (productive seconds, weekday + hour):\n");
        List<HeatmapCell> cells = new ArrayList<>(o.heatmap());
        cells.sort((a, b) -> Long.compare(b.productiveSeconds(), a.productiveSeconds()));
        int shown = 0;
        for (HeatmapCell c : cells) {
            if (c.productiveSeconds() == 0 || shown >= 8) break;
            sb.append("- ").append(dowNames[c.weekday() - 1])
              .append(" ").append(String.format("%02d:00", c.hour()))
              .append(" — ").append(formatHours(c.productiveSeconds())).append("\n");
            shown++;
        }

        sb.append("\nTop distractions (last 7 days, non-productive categories):\n");
        for (DistractionEntry d : o.topDistractions().stream().limit(6).toList()) {
            sb.append("- ").append(d.appName())
              .append(" (").append(d.category()).append(") — ")
              .append(formatHours(d.totalSeconds())).append(", ")
              .append(d.sessionCount()).append(" sessions\n");
        }

        sb.append("\nLongest single focus blocks:\n");
        for (LongestFocusEntry f : o.longestFocusSessions()) {
            sb.append("- ").append(f.date()).append(" ").append(f.startTime())
              .append("-").append(f.endTime())
              .append(" · ").append(f.category())
              .append(" · ").append(formatHours(f.durationSeconds()))
              .append("\n");
        }

        sb.append("\nCategory mix (current period vs prior):\n");
        for (var c : o.categoryBreakdown()) {
            sb.append("- ").append(c.category()).append(": ")
              .append(c.percent()).append("% (")
              .append(formatHours(c.totalSeconds())).append(")\n");
        }
        if (!o.categoryBreakdownPriorPeriod().isEmpty()) {
            sb.append("Prior period:\n");
            for (var c : o.categoryBreakdownPriorPeriod().stream().limit(5).toList()) {
                sb.append("- ").append(c.category()).append(": ")
                  .append(c.percent()).append("%\n");
            }
        }

        sb.append("\nStreaks (productive day = 4+ hrs): current ")
          .append(o.streaks().currentStreak())
          .append(", longest ").append(o.streaks().longestStreak())
          .append(".\n");

        // Reviewed block titles — concrete activities the user already named.
        List<SessionReview> reviews = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            reviews.addAll(reviewRepo.findByBlockDate(d));
        }
        if (!reviews.isEmpty()) {
            sb.append("\nReviewed activities (titles the user already approved):\n");
            int shownReviews = 0;
            for (SessionReview r : reviews) {
                String title = r.getTitle() != null && !r.getTitle().isBlank()
                    ? r.getTitle() : r.getAiTitle();
                if (title == null || title.isBlank()) continue;
                sb.append("- ").append(r.getBlockDate()).append(" ")
                  .append(r.getStartTime()).append(" · ")
                  .append(r.getCategory()).append(" · ")
                  .append(clip(title, 100)).append("\n");
                if (++shownReviews >= 25) break;
            }
        }
        return sb.toString();
    }

    private String buildPrompt(String summary) {
        return """
            You are a personal-analytics coach reading aggregated time-tracking data
            for one user. Produce a short, specific, second-person writeup. Cite
            concrete numbers, weekday/time patterns, and named activities from the
            data. No motivational filler, no generic platitudes.

            Return EXACTLY this XML structure (no extra commentary):
            <summary>2-3 sentences on the period's overall shape. Mention specific
            hours / days / activities by name.</summary>
            <patterns>
              <item>One observed pattern (e.g., "Tuesday + Wednesday are your strongest
              focus days, averaging 5.2 hrs vs 2.1 on Friday").</item>
              <item>...up to 5 items, each grounded in the data.</item>
            </patterns>
            <wins>
              <item>Standout productive moment, by date + activity.</item>
              <item>...up to 3 items.</item>
            </wins>
            <watchouts>
              <item>Concrete distraction or regression, by app/category + magnitude.</item>
              <item>...up to 3 items.</item>
            </watchouts>

            Aggregated data:
            %s
            """.formatted(summary);
    }

    // ── parsing ──

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

    private List<String> extractListTag(String text, String tag) {
        String section = extractTag(text, tag, 4000);
        if (section.isBlank()) return List.of();
        Matcher m = Pattern.compile("<item>(.*?)</item>", Pattern.DOTALL).matcher(section);
        List<String> out = new ArrayList<>();
        while (m.find()) {
            String v = m.group(1).trim().replaceAll("\\s+", " ");
            if (!v.isEmpty()) out.add(clip(v, 300));
            if (out.size() >= 6) break;
        }
        return out;
    }

    // ── utils ──

    private static String formatHours(long secs) {
        if (secs <= 0) return "0";
        long hours = secs / 3600;
        long mins = (secs % 3600) / 60;
        if (hours == 0) return mins + "m";
        if (mins == 0) return hours + "h";
        return hours + "h " + mins + "m";
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
}
