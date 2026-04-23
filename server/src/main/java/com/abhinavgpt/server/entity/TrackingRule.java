package com.abhinavgpt.server.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;

@Table("tracking_rules")
public class TrackingRule {

    @Id
    private Long id;
    private String source;        // "macos" | "browser"
    private String appName;       // bundle id or domain
    private String keywords;      // optional, comma-separated
    private String category;
    private boolean alwaysBlock;
    private boolean blockBreaks;
    private boolean blockMeetings;
    private boolean blockFocus;
    private boolean trackTitles;
    private boolean trackFullUrls;
    private Instant createdAt;

    public TrackingRule() {}

    public TrackingRule(String source, String appName, String keywords, String category,
                        boolean alwaysBlock, boolean blockBreaks,
                        boolean blockMeetings, boolean blockFocus,
                        boolean trackTitles, boolean trackFullUrls) {
        this.source = source;
        this.appName = appName;
        this.keywords = keywords;
        this.category = category;
        this.alwaysBlock = alwaysBlock;
        this.blockBreaks = blockBreaks;
        this.blockMeetings = blockMeetings;
        this.blockFocus = blockFocus;
        this.trackTitles = trackTitles;
        this.trackFullUrls = trackFullUrls;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }

    public String getAppName() { return appName; }
    public void setAppName(String appName) { this.appName = appName; }

    public String getKeywords() { return keywords; }
    public void setKeywords(String keywords) { this.keywords = keywords; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public boolean isAlwaysBlock() { return alwaysBlock; }
    public void setAlwaysBlock(boolean alwaysBlock) { this.alwaysBlock = alwaysBlock; }

    public boolean isBlockBreaks() { return blockBreaks; }
    public void setBlockBreaks(boolean blockBreaks) { this.blockBreaks = blockBreaks; }

    public boolean isBlockMeetings() { return blockMeetings; }
    public void setBlockMeetings(boolean blockMeetings) { this.blockMeetings = blockMeetings; }

    public boolean isBlockFocus() { return blockFocus; }
    public void setBlockFocus(boolean blockFocus) { this.blockFocus = blockFocus; }

    public boolean isTrackTitles() { return trackTitles; }
    public void setTrackTitles(boolean trackTitles) { this.trackTitles = trackTitles; }

    public boolean isTrackFullUrls() { return trackFullUrls; }
    public void setTrackFullUrls(boolean trackFullUrls) { this.trackFullUrls = trackFullUrls; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
