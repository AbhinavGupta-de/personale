package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.config.SecurityConfig;
import com.abhinavgpt.server.dto.AppTimeEntry;
import com.abhinavgpt.server.dto.DailyStatsResponse;
import com.abhinavgpt.server.service.StatsService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StatsController.class)
@Import(SecurityConfig.class)
class StatsControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private StatsService statsService;

    @Test
    void getToday_returns200WithStats() throws Exception {
        DailyStatsResponse response = new DailyStatsResponse(
            "2026-03-07",
            List.of(
                new AppTimeEntry("Safari", "com.apple.Safari", 3600),
                new AppTimeEntry("Terminal", "com.apple.Terminal", 1800)
            ),
            5400
        );
        when(statsService.getTimePerAppToday(any(), any())).thenReturn(response);

        mockMvc.perform(get("/api/stats/today"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.date").value("2026-03-07"))
            .andExpect(jsonPath("$.apps").isArray())
            .andExpect(jsonPath("$.apps.length()").value(2))
            .andExpect(jsonPath("$.apps[0].appName").value("Safari"))
            .andExpect(jsonPath("$.apps[0].totalSeconds").value(3600))
            .andExpect(jsonPath("$.apps[1].appName").value("Terminal"))
            .andExpect(jsonPath("$.totalTrackedSeconds").value(5400));
    }

    @Test
    void getToday_noData_returnsEmptyList() throws Exception {
        DailyStatsResponse response = new DailyStatsResponse("2026-03-07", List.of(), 0);
        when(statsService.getTimePerAppToday(any(), any())).thenReturn(response);

        mockMvc.perform(get("/api/stats/today"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.apps").isEmpty())
            .andExpect(jsonPath("$.totalTrackedSeconds").value(0));
    }
}
