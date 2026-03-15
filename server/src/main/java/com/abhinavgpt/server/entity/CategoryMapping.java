package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

@Table("category_mappings")
public class CategoryMapping {

    @Id
    private Long id;
    private String bundleId;
    private String category;

    public CategoryMapping() {}

    public CategoryMapping(String bundleId, String category) {
        this.bundleId = bundleId;
        this.category = category;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getBundleId() { return bundleId; }
    public void setBundleId(String bundleId) { this.bundleId = bundleId; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
}
