package com.abhinavgpt.server.dto;

public record TimelineEntry(String startTime, String endTime, String appName, String bundleId, String category) {}
