package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;

@Table("pomodoro_sessions")
public class PomodoroSession {

    @Id
    private Long id;
    private String goal;
    private Instant startedAt;
    private Instant endedAt;
    private int targetSeconds;
    private String status;   // running | completed | discarded

    public PomodoroSession() {}

    public PomodoroSession(String goal, Instant startedAt, int targetSeconds) {
        this.goal = goal;
        this.startedAt = startedAt;
        this.targetSeconds = targetSeconds;
        this.status = "running";
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getGoal() { return goal; }
    public void setGoal(String goal) { this.goal = goal; }

    public Instant getStartedAt() { return startedAt; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }

    public Instant getEndedAt() { return endedAt; }
    public void setEndedAt(Instant endedAt) { this.endedAt = endedAt; }

    public int getTargetSeconds() { return targetSeconds; }
    public void setTargetSeconds(int targetSeconds) { this.targetSeconds = targetSeconds; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}
