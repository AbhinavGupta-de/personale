package com.abhinavgpt.server.dto;

public record AppSwitchEvent(
    String appName,
    String bundleId,
    String windowTitle,
    String timestamp
) {}
