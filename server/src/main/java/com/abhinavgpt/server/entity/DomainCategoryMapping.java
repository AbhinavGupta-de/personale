package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

@Table("domain_category_mappings")
public class DomainCategoryMapping {

    @Id
    private Long id;
    private String domain;
    private String category;

    public DomainCategoryMapping() {}

    public DomainCategoryMapping(String domain, String category) {
        this.domain = domain;
        this.category = category;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getDomain() { return domain; }
    public void setDomain(String domain) { this.domain = domain; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
}
