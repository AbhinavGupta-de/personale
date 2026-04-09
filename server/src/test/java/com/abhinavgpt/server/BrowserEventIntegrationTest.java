package com.abhinavgpt.server;

import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.repository.BrowserEventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.stream.StreamSupport;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfig.class)
class BrowserEventIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private BrowserEventRepository browserEventRepository;

    @BeforeEach
    void setUp() {
        browserEventRepository.deleteAll();
    }

    @Test
    void postBrowserEvent_persistsToDatabase() throws Exception {
        mockMvc.perform(post("/api/events/browser")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "domain": "github.com",
                        "title": "Pull Request #42",
                        "url": "https://github.com/user/repo/pull/42",
                        "browser": "chrome",
                        "timestamp": "2026-04-09T10:00:00Z"
                    }
                    """))
            .andExpect(status().isOk());

        List<BrowserEvent> events = StreamSupport.stream(
            browserEventRepository.findAll().spliterator(), false).toList();
        assertThat(events).hasSize(1);

        BrowserEvent event = events.getFirst();
        assertThat(event.getDomain()).isEqualTo("github.com");
        assertThat(event.getTitle()).isEqualTo("Pull Request #42");
        assertThat(event.getBrowser()).isEqualTo("chrome");
    }

    @Test
    void postBrowserEvent_invalidTimestamp_returns400() throws Exception {
        mockMvc.perform(post("/api/events/browser")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"domain":"github.com","title":"test","url":"https://github.com","browser":"chrome","timestamp":"bad"}
                    """))
            .andExpect(status().isBadRequest());
    }

    @Test
    void multipleBrowserEvents_allPersisted() throws Exception {
        mockMvc.perform(post("/api/events/browser")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"domain":"github.com","title":"Code Review","url":"https://github.com","browser":"chrome","timestamp":"2026-04-09T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        mockMvc.perform(post("/api/events/browser")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"domain":"youtube.com","title":"Conference Talk","url":"https://youtube.com/watch","browser":"chrome","timestamp":"2026-04-09T10:05:00Z"}
                    """))
            .andExpect(status().isOk());

        assertThat(browserEventRepository.count()).isEqualTo(2);
    }
}
