package com.abhinavgpt.server.dto;

import java.util.List;

/**
 * AI-generated self-knowledge narrative for the Insights page. The model
 * gets aggregated stats + reviewed-session titles for the range and produces
 * a short prose recap plus discrete "patterns" (e.g., "you focus best on
 * Wednesday mornings"). Patterns render as separate bullets in the UI.
 */
public record InsightsNarrativeResponse(
    String from,
    String to,
    String summary,           // 2-3 sentence recap
    List<String> patterns,    // bullet-style observations
    List<String> wins,        // standout productive moments
    List<String> watchouts,   // distractions / regressions worth noticing
    String model,
    String generatedAt
) {}
