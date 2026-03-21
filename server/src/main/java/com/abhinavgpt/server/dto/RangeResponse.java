package com.abhinavgpt.server.dto;

import java.util.List;

public record RangeResponse(String from, String to, List<RangeDayBreakdown> days) {}
