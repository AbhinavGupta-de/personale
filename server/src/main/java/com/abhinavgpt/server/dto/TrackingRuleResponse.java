package com.abhinavgpt.server.dto;

public record TrackingRuleResponse(
    Long id,
    String source,
    String appName,
    String keywords,
    String category,
    boolean alwaysBlock,
    boolean blockBreaks,
    boolean blockMeetings,
    boolean blockFocus,
    boolean trackTitles,
    boolean trackFullUrls
) {}
