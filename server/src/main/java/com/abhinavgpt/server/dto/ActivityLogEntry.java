package com.abhinavgpt.server.dto;

public record ActivityLogEntry(String time, String appName, String bundleId, String detail, long durationSeconds) {}
