package com.abhinavgpt.server.dto;

public record SessionInsightResponse(
    Long sessionId,
    String title,
    String description,
    String model,
    String generatedAt
) {}
