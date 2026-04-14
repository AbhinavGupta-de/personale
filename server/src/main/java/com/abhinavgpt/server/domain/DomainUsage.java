package com.abhinavgpt.server.domain;

/**
 * Time spent on a single domain within a bounded window.
 */
public record DomainUsage(String domain, long seconds) {}
