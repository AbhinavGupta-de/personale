package com.abhinavgpt.server.dto;

public record SessionReviewUpdateRequest(
    String title,
    String description,
    String task,
    String project,
    String client,
    String category    // override — nullable to keep derived category
) {}
