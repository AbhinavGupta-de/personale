package com.abhinavgpt.server;

import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.repository.AppSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.stream.StreamSupport;

import org.springframework.context.annotation.Import;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfig.class)
class EventIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AppSessionRepository repository;

    @BeforeEach
    void setUp() {
        repository.deleteAll();
    }

    @Test
    void postEvent_persistsToDatabase() throws Exception {
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "appName": "Safari",
                        "bundleId": "com.apple.Safari",
                        "windowTitle": "Google",
                        "timestamp": "2026-03-07T10:00:00Z"
                    }
                    """))
            .andExpect(status().isOk());

        Iterable<AppSession> sessions = repository.findAll();
        assertThat(sessions).hasSize(1);

        AppSession session = sessions.iterator().next();
        assertThat(session.getAppName()).isEqualTo("Safari");
        assertThat(session.getBundleId()).isEqualTo("com.apple.Safari");
        assertThat(session.getWindowTitle()).isEqualTo("Google");
        assertThat(session.getStartedAt()).isNotNull();
        assertThat(session.getEndedAt()).isNull();
    }

    @Test
    void multipleEvents_allPersisted() throws Exception {
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"2026-03-07T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Terminal","bundleId":"com.apple.Terminal","windowTitle":null,"timestamp":"2026-03-07T10:01:00Z"}
                    """))
            .andExpect(status().isOk());

        assertThat(repository.count()).isEqualTo(2);
    }

    @Test
    void postEvent_withNullWindowTitle_persists() throws Exception {
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Finder","bundleId":"com.apple.finder","windowTitle":null,"timestamp":"2026-03-07T12:00:00Z"}
                    """))
            .andExpect(status().isOk());

        AppSession session = repository.findAll().iterator().next();
        assertThat(session.getWindowTitle()).isNull();
    }

    @Test
    void sessionLifecycle_secondEventClosesPrevious() throws Exception {
        // First event: open Safari
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":"Google","timestamp":"2026-03-07T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        // Second event: switch to Terminal — should close Safari
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Terminal","bundleId":"com.apple.Terminal","windowTitle":null,"timestamp":"2026-03-07T10:30:00Z"}
                    """))
            .andExpect(status().isOk());

        List<AppSession> sessions = StreamSupport.stream(
            repository.findAll().spliterator(), false).toList();
        assertThat(sessions).hasSize(2);

        // Safari session should be closed
        AppSession safari = sessions.stream()
            .filter(s -> "Safari".equals(s.getAppName())).findFirst().orElseThrow();
        assertThat(safari.getEndedAt()).isEqualTo(Instant.parse("2026-03-07T10:30:00Z"));

        // Terminal session should still be active
        AppSession terminal = sessions.stream()
            .filter(s -> "Terminal".equals(s.getAppName())).findFirst().orElseThrow();
        assertThat(terminal.getEndedAt()).isNull();
    }

    @Test
    void postEvent_invalidTimestamp_returns400() throws Exception {
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"not-a-timestamp"}
                    """))
            .andExpect(status().isBadRequest());

        assertThat(repository.count()).isZero();
    }

    @Test
    void statsToday_returnsTimePerApp() throws Exception {
        // Create two closed sessions and one active
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"2026-03-07T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Terminal","bundleId":"com.apple.Terminal","windowTitle":null,"timestamp":"2026-03-07T10:30:00Z"}
                    """))
            .andExpect(status().isOk());

        // Query stats
        mockMvc.perform(get("/api/stats/today"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.date").isNotEmpty())
            .andExpect(jsonPath("$.apps").isArray())
            .andExpect(jsonPath("$.totalTrackedSeconds").isNumber());
    }

    @Test
    void closeSession_closesActiveWithoutOpeningNew() throws Exception {
        // Open Safari
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"2026-03-07T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        // Close session (sleep)
        mockMvc.perform(post("/api/events/close")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"timestamp":"2026-03-07T10:30:00Z"}
                    """))
            .andExpect(status().isOk());

        List<AppSession> sessions = StreamSupport.stream(
            repository.findAll().spliterator(), false).toList();
        assertThat(sessions).hasSize(1);

        // Safari should be closed, no new session opened
        AppSession safari = sessions.getFirst();
        assertThat(safari.getAppName()).isEqualTo("Safari");
        assertThat(safari.getEndedAt()).isEqualTo(Instant.parse("2026-03-07T10:30:00Z"));
        assertThat(repository.findActiveSession()).isEmpty();
    }

    @Test
    void sleepWakeCycle_noInflatedDuration() throws Exception {
        // Using Safari at 10:00
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"2026-03-07T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        // Mac sleeps at 10:30
        mockMvc.perform(post("/api/events/close")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"timestamp":"2026-03-07T10:30:00Z"}
                    """))
            .andExpect(status().isOk());

        // Mac wakes at 18:30 (8 hours later), user is on Safari again
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"2026-03-07T18:30:00Z"}
                    """))
            .andExpect(status().isOk());

        List<AppSession> sessions = StreamSupport.stream(
            repository.findAll().spliterator(), false).toList();
        assertThat(sessions).hasSize(2);

        // First session: 30 minutes (10:00 to 10:30), not 8.5 hours
        AppSession first = sessions.stream()
            .filter(s -> s.getEndedAt() != null).findFirst().orElseThrow();
        assertThat(first.getEndedAt()).isEqualTo(Instant.parse("2026-03-07T10:30:00Z"));

        // Second session: still active from 18:30
        AppSession second = sessions.stream()
            .filter(s -> s.getEndedAt() == null).findFirst().orElseThrow();
        assertThat(second.getStartedAt()).isEqualTo(Instant.parse("2026-03-07T18:30:00Z"));
    }
}
