package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;

@Table("app_sessions")
public class AppSession {

    @Id
    private Long id;
    private String appName;
    private String bundleId;
    private String windowTitle;
    private String enrichedContext;
    private String kind = "active";
    private Instant startedAt;
    private Instant endedAt;

    public AppSession() {}

    public AppSession(String appName, String bundleId, String windowTitle, Instant startedAt) {
        this.appName = appName;
        this.bundleId = bundleId;
        this.windowTitle = windowTitle;
        this.startedAt = startedAt;
    }

    public static AppSession idleBlock(Instant startedAt, Instant endedAt) {
        AppSession session = new AppSession("Away", null, null, startedAt);
        session.setKind("idle");
        session.setEndedAt(endedAt);
        return session;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getAppName() { return appName; }
    public void setAppName(String appName) { this.appName = appName; }

    public String getBundleId() { return bundleId; }
    public void setBundleId(String bundleId) { this.bundleId = bundleId; }

    public String getWindowTitle() { return windowTitle; }
    public void setWindowTitle(String windowTitle) { this.windowTitle = windowTitle; }

    public String getEnrichedContext() { return enrichedContext; }
    public void setEnrichedContext(String enrichedContext) { this.enrichedContext = enrichedContext; }

    public String getKind() { return kind; }
    public void setKind(String kind) { this.kind = kind; }

    public Instant getStartedAt() { return startedAt; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }

    public Instant getEndedAt() { return endedAt; }
    public void setEndedAt(Instant endedAt) { this.endedAt = endedAt; }
}
