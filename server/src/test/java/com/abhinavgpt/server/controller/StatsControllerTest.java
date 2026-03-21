package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.config.SecurityConfig;
import com.abhinavgpt.server.dto.*;
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
            5400,
            0
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
        DailyStatsResponse response = new DailyStatsResponse("2026-03-07", List.of(), 0, 0);
        when(statsService.getTimePerAppToday(any(), any())).thenReturn(response);

        mockMvc.perform(get("/api/stats/today"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.apps").isEmpty())
            .andExpect(jsonPath("$.totalTrackedSeconds").value(0));
    }

    // ── /api/stats/day ──

    @Test
    void getDay_returns200WithStats() throws Exception {
        DailyStatsResponse response = new DailyStatsResponse(
            "2026-03-10",
            List.of(new AppTimeEntry("Xcode", "com.apple.dt.Xcode", 7200)),
            7200, 2
        );
        when(statsService.getTimePerApp(any(), any(), any())).thenReturn(response);

        mockMvc.perform(get("/api/stats/day").param("date", "2026-03-10"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.date").value("2026-03-10"))
            .andExpect(jsonPath("$.apps[0].appName").value("Xcode"))
            .andExpect(jsonPath("$.idleSessionCount").value(2));
    }

    // ── /api/stats/timeline ──

    @Test
    void getTimeline_returns200WithBlocks() throws Exception {
        when(statsService.getTimeline(any(), any(), any())).thenReturn(List.of(
            new TimelineEntry("09:00", "10:00", "Xcode", "com.apple.dt.Xcode", "Code"),
            new TimelineEntry("10:00", "10:30", "Safari", "com.apple.Safari", "Browsing")
        ));

        mockMvc.perform(get("/api/stats/timeline").param("date", "2026-03-07"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(2))
            .andExpect(jsonPath("$[0].startTime").value("09:00"))
            .andExpect(jsonPath("$[0].endTime").value("10:00"))
            .andExpect(jsonPath("$[0].appName").value("Xcode"))
            .andExpect(jsonPath("$[0].category").value("Code"))
            .andExpect(jsonPath("$[1].category").value("Browsing"));
    }

    // ── /api/stats/activity ──

    @Test
    void getActivity_returns200WithLog() throws Exception {
        when(statsService.getActivityLog(any(), any(), any())).thenReturn(List.of(
            new ActivityLogEntry("09:00:00", "Terminal", "com.apple.Terminal", "zsh", 1800),
            new ActivityLogEntry("09:30:00", "Safari", "com.apple.Safari", "GitHub", 1800)
        ));

        mockMvc.perform(get("/api/stats/activity").param("date", "2026-03-07"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(2))
            .andExpect(jsonPath("$[0].time").value("09:00:00"))
            .andExpect(jsonPath("$[0].appName").value("Terminal"))
            .andExpect(jsonPath("$[0].detail").value("zsh"))
            .andExpect(jsonPath("$[0].durationSeconds").value(1800));
    }

    // ── /api/stats/categories ──

    @Test
    void getCategories_returns200WithBreakdown() throws Exception {
        when(statsService.getCategoryBreakdown(any(), any(), any())).thenReturn(List.of(
            new CategoryBreakdownEntry("Code", 5400, 75),
            new CategoryBreakdownEntry("Browsing", 1800, 25)
        ));

        mockMvc.perform(get("/api/stats/categories").param("date", "2026-03-07"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(2))
            .andExpect(jsonPath("$[0].category").value("Code"))
            .andExpect(jsonPath("$[0].totalSeconds").value(5400))
            .andExpect(jsonPath("$[0].percent").value(75))
            .andExpect(jsonPath("$[1].category").value("Browsing"));
    }

    // ── /api/stats/workblocks ──

    @Test
    void getWorkblocks_returns200WithBlocks() throws Exception {
        when(statsService.getWorkblocks(any(), any(), any())).thenReturn(List.of(
            new WorkblockEntry("9:00", "Code", "1 hr 30 min", 5400),
            new WorkblockEntry("10:30", "Browsing", "30 min", 1800)
        ));

        mockMvc.perform(get("/api/stats/workblocks").param("date", "2026-03-07"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(2))
            .andExpect(jsonPath("$[0].time").value("9:00"))
            .andExpect(jsonPath("$[0].task").value("Code"))
            .andExpect(jsonPath("$[0].duration").value("1 hr 30 min"))
            .andExpect(jsonPath("$[0].durationSeconds").value(5400));
    }

    // ── /api/stats/sessions ──

    @Test
    void getSessions_returns200WithFocusSessions() throws Exception {
        when(statsService.getFocusSessions(any(), any(), any())).thenReturn(List.of(
            new FocusSessionEntry("Code", "09:00", "10:30", 5400, "1 hr 30 min",
                List.of(
                    new SessionAppBreakdown("Xcode", "com.apple.dt.Xcode", "Code", 3600, 67),
                    new SessionAppBreakdown("Terminal", "com.apple.Terminal", "Code", 1800, 33)
                ),
                List.of(new CategoryBreakdownEntry("Code", 5400, 100))
            )
        ));

        mockMvc.perform(get("/api/stats/sessions").param("date", "2026-03-07"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(1))
            .andExpect(jsonPath("$[0].name").value("Code"))
            .andExpect(jsonPath("$[0].startTime").value("09:00"))
            .andExpect(jsonPath("$[0].endTime").value("10:30"))
            .andExpect(jsonPath("$[0].durationSeconds").value(5400))
            .andExpect(jsonPath("$[0].apps.length()").value(2))
            .andExpect(jsonPath("$[0].apps[0].appName").value("Xcode"))
            .andExpect(jsonPath("$[0].apps[0].totalSeconds").value(3600))
            .andExpect(jsonPath("$[0].apps[0].percent").value(67))
            .andExpect(jsonPath("$[0].categories[0].category").value("Code"));
    }

    // ── /api/stats/range ──

    @Test
    void getRange_returns200WithDays() throws Exception {
        when(statsService.getRange(any(), any(), any(), any())).thenReturn(
            new RangeResponse("2026-03-01", "2026-03-02", List.of(
                new RangeDayBreakdown("2026-03-01", 3600, List.of(
                    new RangeDayBreakdown.CategorySeconds("Code", 3600))),
                new RangeDayBreakdown("2026-03-02", 1800, List.of(
                    new RangeDayBreakdown.CategorySeconds("Browsing", 1800)))
            ))
        );

        mockMvc.perform(get("/api/stats/range")
                .param("from", "2026-03-01").param("to", "2026-03-02"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.from").value("2026-03-01"))
            .andExpect(jsonPath("$.to").value("2026-03-02"))
            .andExpect(jsonPath("$.days.length()").value(2))
            .andExpect(jsonPath("$.days[0].date").value("2026-03-01"))
            .andExpect(jsonPath("$.days[0].totalTrackedSeconds").value(3600))
            .andExpect(jsonPath("$.days[0].categories[0].category").value("Code"));
    }

    // ── /api/stats/range/summary ──

    @Test
    void getRangeSummary_returns200WithAggregates() throws Exception {
        when(statsService.getRangeSummary(any(), any(), any(), any())).thenReturn(
            new RangeSummaryResponse("2026-03-01", "2026-03-07", 36000, 5, 7200, 36000,
                List.of(new CategoryBreakdownEntry("Code", 36000, 100)))
        );

        mockMvc.perform(get("/api/stats/range/summary")
                .param("from", "2026-03-01").param("to", "2026-03-07"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalTrackedSeconds").value(36000))
            .andExpect(jsonPath("$.daysWithData").value(5))
            .andExpect(jsonPath("$.avgSecondsPerDay").value(7200))
            .andExpect(jsonPath("$.avgSecondsPerWeek").value(36000))
            .andExpect(jsonPath("$.categoryBreakdown[0].category").value("Code"));
    }
}
