package com.abhinavgpt.server.dto;

/** Used for both create (id null) and update. */
public record TrackingRuleRequest(
    String source,
    String appName,
    String keywords,
    String category,
    Boolean alwaysBlock,
    Boolean blockBreaks,
    Boolean blockMeetings,
    Boolean blockFocus,
    Boolean trackTitles,
    Boolean trackFullUrls
) {}
