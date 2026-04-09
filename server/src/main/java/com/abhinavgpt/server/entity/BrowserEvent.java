package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;

@Table("browser_events")
public class BrowserEvent {

    @Id
    private Long id;
    private String domain;
    private String title;
    private String url;
    private String browser;
    private Instant timestamp;

    public BrowserEvent() {}

    public BrowserEvent(String domain, String title, String url, String browser, Instant timestamp) {
        this.domain = domain;
        this.title = title;
        this.url = url;
        this.browser = browser;
        this.timestamp = timestamp;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getDomain() { return domain; }
    public void setDomain(String domain) { this.domain = domain; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }

    public String getBrowser() { return browser; }
    public void setBrowser(String browser) { this.browser = browser; }

    public Instant getTimestamp() { return timestamp; }
    public void setTimestamp(Instant timestamp) { this.timestamp = timestamp; }
}
