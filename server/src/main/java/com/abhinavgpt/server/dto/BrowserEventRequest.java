package com.abhinavgpt.server.dto;

public record BrowserEventRequest(
    String domain,
    String title,
    String url,
    String browser,
    String timestamp
) {}
