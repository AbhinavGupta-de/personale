package com.abhinavgpt.server.dto;

public record AppSwitchEvent(
    String appName,
    String bundleId,
    String windowTitle,
    String enrichedContext,    // optional — app-specific extras (git branch, cwd, etc.)
    String timestamp
) {}
