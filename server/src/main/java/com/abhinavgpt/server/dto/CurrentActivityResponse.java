package com.abhinavgpt.server.dto;

/**
 * Live activity snapshot computed server-side from the currently-active
 * app_session. Drives the desktop-pet companion (Shiro) that mirrors the
 * user's work day.
 *
 * `state` is one of: away | idle | break | scattered | focused.
 */
public record CurrentActivityResponse(
    String category,                // active foreground category; "" when no active session
    String app,                     // active app name; "" when none
    String state,                   // away | idle | break | scattered | focused
    int focusMinutes,               // minutes in current sustained block; 0 if idle/away
    int contextSwitchesLastHour,    // sessions started within the last 60 minutes
    double dailyTargetPct,          // work-hours seconds today / (targetHours * 3600); >= 0, may exceed 1.0
    String updatedAt                // ISO-8601 UTC string (Instant.now().toString())
) {}
