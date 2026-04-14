package com.abhinavgpt.server.service;

import com.abhinavgpt.server.domain.DomainUsage;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.entity.DomainCategoryMapping;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import com.abhinavgpt.server.repository.DomainCategoryMappingRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;

@ExtendWith(MockitoExtension.class)
class DomainTimeServiceTest {

    @Mock private CategoryMappingRepository bundleRepo;
    @Mock private DomainCategoryMappingRepository domainRepo;
    @Mock private CategoryThresholdRepository thresholdRepo;

    private DomainTimeService domainTimeService;

    @BeforeEach
    void setUp() {
        lenient().when(domainRepo.findAll()).thenReturn(List.of(
            new DomainCategoryMapping("github.com", "Code"),
            new DomainCategoryMapping("news.ycombinator.com", "Reading")));
        CategoryResolver resolver = new CategoryResolver(bundleRepo, domainRepo, thresholdRepo);
        domainTimeService = new DomainTimeService(resolver);
    }

    private BrowserEvent event(String iso, String domain) {
        return new BrowserEvent(domain, null, null, "chrome", Instant.parse(iso));
    }

    @Test
    void topDomains_allocatesTimeToNextEvent() {
        List<BrowserEvent> events = List.of(
            event("2026-04-10T10:00:00Z", "github.com"),
            event("2026-04-10T10:05:00Z", "news.ycombinator.com"),
            event("2026-04-10T10:07:00Z", "github.com"));

        Instant start = Instant.parse("2026-04-10T10:00:00Z");
        Instant end = Instant.parse("2026-04-10T10:10:00Z");

        List<DomainUsage> top = domainTimeService.topDomainsInWindow(start, end, events, 5);

        // github.com: 10:00-10:05 (300s) + 10:07-10:10 (180s) = 480s
        // news.ycombinator.com: 10:05-10:07 = 120s
        assertThat(top).hasSize(2);
        assertThat(top.getFirst().domain()).isEqualTo("github.com");
        assertThat(top.getFirst().seconds()).isEqualTo(480);
        assertThat(top.get(1).domain()).isEqualTo("news.ycombinator.com");
        assertThat(top.get(1).seconds()).isEqualTo(120);
    }

    @Test
    void topDomains_respectsLimit() {
        List<BrowserEvent> events = List.of(
            event("2026-04-10T10:00:00Z", "a.com"),
            event("2026-04-10T10:01:00Z", "b.com"),
            event("2026-04-10T10:02:00Z", "c.com"));

        List<DomainUsage> top = domainTimeService.topDomainsInWindow(
            Instant.parse("2026-04-10T10:00:00Z"),
            Instant.parse("2026-04-10T10:03:00Z"),
            events, 2);

        assertThat(top).hasSize(2);
    }

    @Test
    void topDomains_emptyEvents_returnsEmpty() {
        List<DomainUsage> top = domainTimeService.topDomainsInWindow(
            Instant.parse("2026-04-10T10:00:00Z"),
            Instant.parse("2026-04-10T11:00:00Z"),
            List.of(), 5);
        assertThat(top).isEmpty();
    }

    @Test
    void topDomains_filtersOutsideWindow() {
        List<BrowserEvent> events = List.of(
            event("2026-04-10T09:00:00Z", "before.com"),
            event("2026-04-10T10:30:00Z", "during.com"),
            event("2026-04-10T12:00:00Z", "after.com"));

        List<DomainUsage> top = domainTimeService.topDomainsInWindow(
            Instant.parse("2026-04-10T10:00:00Z"),
            Instant.parse("2026-04-10T11:00:00Z"),
            events, 5);

        assertThat(top).hasSize(1);
        assertThat(top.getFirst().domain()).isEqualTo("during.com");
    }

    @Test
    void secondsPerDomainCategory_groupsByResolvedCategory() {
        List<BrowserEvent> events = List.of(
            event("2026-04-10T10:00:00Z", "github.com"),
            event("2026-04-10T10:05:00Z", "news.ycombinator.com"));

        Map<String, Long> byCategory = domainTimeService.secondsPerDomainCategory(
            Instant.parse("2026-04-10T10:00:00Z"),
            Instant.parse("2026-04-10T10:10:00Z"),
            events);

        // github.com (Code): 300s, news.ycombinator.com (Reading): 300s
        assertThat(byCategory).containsEntry("Code", 300L);
        assertThat(byCategory).containsEntry("Reading", 300L);
    }
}
