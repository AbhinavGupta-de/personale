package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.Transient;
import org.springframework.data.domain.Persistable;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;
import java.time.LocalDate;

@Table("session_reviews")
public class SessionReview implements Persistable<String> {

    @Id
    private String blockKey;
    private LocalDate blockDate;
    private String startTime;
    private String endTime;
    private String category;
    private String title;
    private String description;
    private String task;
    private String project;
    private String client;
    private String status;
    private String aiTitle;
    private String aiDescription;
    private String aiModel;
    private Instant aiGeneratedAt;
    private String overrideCategory;
    private Instant createdAt;
    private Instant updatedAt;

    @Transient
    private boolean newRecord = true;

    public SessionReview() {}

    @Override public String getId() { return blockKey; }
    @Override public boolean isNew() { return newRecord; }
    public void markPersisted() { this.newRecord = false; }

    public String getBlockKey() { return blockKey; }
    public void setBlockKey(String blockKey) { this.blockKey = blockKey; }
    public LocalDate getBlockDate() { return blockDate; }
    public void setBlockDate(LocalDate blockDate) { this.blockDate = blockDate; }
    public String getStartTime() { return startTime; }
    public void setStartTime(String startTime) { this.startTime = startTime; }
    public String getEndTime() { return endTime; }
    public void setEndTime(String endTime) { this.endTime = endTime; }
    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getTask() { return task; }
    public void setTask(String task) { this.task = task; }
    public String getProject() { return project; }
    public void setProject(String project) { this.project = project; }
    public String getClient() { return client; }
    public void setClient(String client) { this.client = client; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getAiTitle() { return aiTitle; }
    public void setAiTitle(String aiTitle) { this.aiTitle = aiTitle; }
    public String getAiDescription() { return aiDescription; }
    public void setAiDescription(String aiDescription) { this.aiDescription = aiDescription; }
    public String getAiModel() { return aiModel; }
    public void setAiModel(String aiModel) { this.aiModel = aiModel; }
    public Instant getAiGeneratedAt() { return aiGeneratedAt; }
    public void setAiGeneratedAt(Instant aiGeneratedAt) { this.aiGeneratedAt = aiGeneratedAt; }
    public String getOverrideCategory() { return overrideCategory; }
    public void setOverrideCategory(String overrideCategory) { this.overrideCategory = overrideCategory; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
