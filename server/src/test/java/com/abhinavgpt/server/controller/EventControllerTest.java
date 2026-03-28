package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.config.SecurityConfig;
import com.abhinavgpt.server.dto.AppSwitchEvent;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.service.EventService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import java.time.format.DateTimeParseException;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(EventController.class)
@Import(SecurityConfig.class)
class EventControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private EventService eventService;

    @Test
    void postEvent_returns200() throws Exception {
        when(eventService.saveEvent(any())).thenReturn(
            new AppSession("Safari", "com.apple.Safari", null, Instant.now()));

        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "appName": "Safari",
                        "bundleId": "com.apple.Safari",
                        "windowTitle": null,
                        "timestamp": "2026-03-07T10:00:00Z"
                    }
                    """))
            .andExpect(status().isOk());
    }

    @Test
    void postEvent_callsServiceWithCorrectEvent() throws Exception {
        when(eventService.saveEvent(any())).thenReturn(
            new AppSession("Safari", "com.apple.Safari", null, Instant.now()));

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

        verify(eventService).saveEvent(any(AppSwitchEvent.class));
    }

    @Test
    void postEvent_missingBody_returns400() throws Exception {
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content(""))
            .andExpect(status().isBadRequest());
    }

    @Test
    void postEvent_malformedJson_returns400() throws Exception {
        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{invalid json}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void postEvent_invalidTimestamp_returns400() throws Exception {
        when(eventService.saveEvent(any())).thenThrow(
            new DateTimeParseException("bad", "not-a-timestamp", 0));

        mockMvc.perform(post("/api/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"appName":"Safari","bundleId":"com.apple.Safari","windowTitle":null,"timestamp":"not-a-timestamp"}
                    """))
            .andExpect(status().isBadRequest());
    }

    @Test
    void closeSession_returns200() throws Exception {
        mockMvc.perform(post("/api/events/close")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"timestamp":"2026-03-07T10:30:00Z"}
                    """))
            .andExpect(status().isOk());

        verify(eventService).closeActiveSession(Instant.parse("2026-03-07T10:30:00Z"), null, null);
    }

    @Test
    void closeSession_withIdentity_passesFieldsThrough() throws Exception {
        mockMvc.perform(post("/api/events/close")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"timestamp":"2026-03-07T10:30:00Z","bundleId":"com.apple.Safari","sessionStartedAt":"2026-03-07T10:00:00Z"}
                    """))
            .andExpect(status().isOk());

        verify(eventService).closeActiveSession(
            Instant.parse("2026-03-07T10:30:00Z"),
            "com.apple.Safari",
            Instant.parse("2026-03-07T10:00:00Z"));
    }
}
