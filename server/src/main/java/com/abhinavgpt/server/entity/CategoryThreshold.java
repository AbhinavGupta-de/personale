package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

/**
 * Per-category config: how long a gap before a session is split, plus the
 * four tracking flags that drive Focus aggregation, Work Hours totals,
 * idle detection, and distraction blocking.
 */
@Table("category_thresholds")
public class CategoryThreshold {

    @Id
    private String category;
    private int idleThresholdSeconds;
    private boolean focus;
    private boolean workHours;
    private boolean idleDetection;
    private boolean distractionBlocker;
    private int dailyGoalSeconds;    // 0 = no goal
    private boolean goalIsMax;       // true = ceiling, false = floor

    public CategoryThreshold() {}

    /** Convenience ctor for tests — flag columns default to the user-facing sensible defaults. */
    public CategoryThreshold(String category, int idleThresholdSeconds) {
        this(category, idleThresholdSeconds, true, true, true, false);
    }

    public CategoryThreshold(String category, int idleThresholdSeconds,
                             boolean focus, boolean workHours,
                             boolean idleDetection, boolean distractionBlocker) {
        this.category = category;
        this.idleThresholdSeconds = idleThresholdSeconds;
        this.focus = focus;
        this.workHours = workHours;
        this.idleDetection = idleDetection;
        this.distractionBlocker = distractionBlocker;
    }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public int getIdleThresholdSeconds() { return idleThresholdSeconds; }
    public void setIdleThresholdSeconds(int idleThresholdSeconds) {
        this.idleThresholdSeconds = idleThresholdSeconds;
    }

    public boolean isFocus() { return focus; }
    public void setFocus(boolean focus) { this.focus = focus; }

    public boolean isWorkHours() { return workHours; }
    public void setWorkHours(boolean workHours) { this.workHours = workHours; }

    public boolean isIdleDetection() { return idleDetection; }
    public void setIdleDetection(boolean idleDetection) { this.idleDetection = idleDetection; }

    public boolean isDistractionBlocker() { return distractionBlocker; }
    public void setDistractionBlocker(boolean distractionBlocker) {
        this.distractionBlocker = distractionBlocker;
    }

    public int getDailyGoalSeconds() { return dailyGoalSeconds; }
    public void setDailyGoalSeconds(int dailyGoalSeconds) {
        this.dailyGoalSeconds = dailyGoalSeconds;
    }

    public boolean isGoalIsMax() { return goalIsMax; }
    public void setGoalIsMax(boolean goalIsMax) { this.goalIsMax = goalIsMax; }
}
