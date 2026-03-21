package com.abhinavgpt.server.dto;

import java.util.List;

public record RangeDayBreakdown(String date, long totalTrackedSeconds,
                                List<CategorySeconds> categories) {

    public record CategorySeconds(String category, long seconds) {}
}
