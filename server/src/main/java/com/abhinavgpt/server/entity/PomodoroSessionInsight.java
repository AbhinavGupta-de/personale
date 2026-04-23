package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.domain.Persistable;
import org.springframework.data.relational.core.mapping.Column;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;

@Table("pomodoro_session_insights")
public class PomodoroSessionInsight implements Persistable<Long> {

    @Id
    @Column("session_id")
    private Long sessionId;
    private String title;
    private String description;
    private String model;
    private Instant generatedAt;

    // Spring Data JDBC can't tell insert vs update when we set the @Id ourselves;
    // Persistable.isNew() disambiguates. We track it with a transient flag.
    @org.springframework.data.annotation.Transient
    private boolean newRecord = true;

    public PomodoroSessionInsight() {}

    public PomodoroSessionInsight(Long sessionId, String title, String description, String model) {
        this.sessionId = sessionId;
        this.title = title;
        this.description = description;
        this.model = model;
        this.generatedAt = Instant.now();
    }

    @Override public Long getId() { return sessionId; }
    @Override public boolean isNew() { return newRecord; }
    public void markPersisted() { this.newRecord = false; }

    public Long getSessionId() { return sessionId; }
    public void setSessionId(Long sessionId) { this.sessionId = sessionId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }

    public Instant getGeneratedAt() { return generatedAt; }
    public void setGeneratedAt(Instant generatedAt) { this.generatedAt = generatedAt; }
}
