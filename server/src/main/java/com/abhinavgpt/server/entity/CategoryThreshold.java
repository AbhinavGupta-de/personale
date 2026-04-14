package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

@Table("category_thresholds")
public class CategoryThreshold {

    @Id
    private String category;
    private int idleThresholdSeconds;

    public CategoryThreshold() {}

    public CategoryThreshold(String category, int idleThresholdSeconds) {
        this.category = category;
        this.idleThresholdSeconds = idleThresholdSeconds;
    }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public int getIdleThresholdSeconds() { return idleThresholdSeconds; }
    public void setIdleThresholdSeconds(int idleThresholdSeconds) {
        this.idleThresholdSeconds = idleThresholdSeconds;
    }
}
