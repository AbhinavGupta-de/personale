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
    private Instant startedAt;
    private Instant endedAt;

    public AppSession() {}

    public AppSession(String appName, String bundleId, String windowTitle, Instant startedAt) {
        this.appName = appName;
        this.bundleId = bundleId;
        this.windowTitle = windowTitle;
        this.startedAt = startedAt;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getAppName() { return appName; }
    public void setAppName(String appName) { this.appName = appName; }

    public String getBundleId() { return bundleId; }
    public void setBundleId(String bundleId) { this.bundleId = bundleId; }

    public String getWindowTitle() { return windowTitle; }
    public void setWindowTitle(String windowTitle) { this.windowTitle = windowTitle; }

    public Instant getStartedAt() { return startedAt; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }

    public Instant getEndedAt() { return endedAt; }
    public void setEndedAt(Instant endedAt) { this.endedAt = endedAt; }
}
