package com.abhinavgpt.server.service;

import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.entity.DomainCategoryMapping;
import com.abhinavgpt.server.entity.TrackingRule;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import com.abhinavgpt.server.repository.DomainCategoryMappingRepository;
import com.abhinavgpt.server.repository.TrackingRuleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CategoryResolverTest {

    @Mock private CategoryMappingRepository bundleRepo;
    @Mock private DomainCategoryMappingRepository domainRepo;
    @Mock private CategoryThresholdRepository thresholdRepo;

    private CategoryResolver resolver;

    @BeforeEach
    void setUp() {
        resolver = new CategoryResolver(bundleRepo, domainRepo, thresholdRepo);
    }

    @Test
    void unknownBundle_fallsBackToOther() {
        when(bundleRepo.findAll()).thenReturn(List.of());
        assertThat(resolver.categoryForBundle("com.unknown.app")).isEqualTo("Other");
    }

    @Test
    void nullBundle_returnsOther() {
        assertThat(resolver.categoryForBundle(null)).isEqualTo("Other");
    }

    @Test
    void knownBundle_returnsMappedCategory() {
        when(bundleRepo.findAll())
            .thenReturn(List.of(new CategoryMapping("com.apple.dt.Xcode", "Code")));
        assertThat(resolver.categoryForBundle("com.apple.dt.Xcode")).isEqualTo("Code");
    }

    @Test
    void subdomainStrip_matchesParent() {
        when(domainRepo.findAll())
            .thenReturn(List.of(new DomainCategoryMapping("github.com", "Code")));
        assertThat(resolver.categoryForDomain("www.github.com")).isEqualTo("Code");
    }

    @Test
    void unknownDomain_fallsBackToBrowsing() {
        when(domainRepo.findAll()).thenReturn(List.of());
        assertThat(resolver.categoryForDomain("example.com")).isEqualTo("Browsing");
    }

    @Test
    void isBrowserBundle_truForBrowserCategory() {
        when(bundleRepo.findAll())
            .thenReturn(List.of(new CategoryMapping("com.apple.Safari", "Browsing")));
        assertThat(resolver.isBrowserBundle("com.apple.Safari")).isTrue();
        assertThat(resolver.isBrowserBundle("com.unknown.thing")).isFalse();
    }

    @Test
    void idleThreshold_returnsConfiguredValue() {
        when(thresholdRepo.findAll()).thenReturn(List.of(
            new CategoryThreshold("Reading", 900),
            new CategoryThreshold("Communication", 180)));
        assertThat(resolver.idleThresholdSeconds("Reading")).isEqualTo(900);
        assertThat(resolver.idleThresholdSeconds("Communication")).isEqualTo(180);
    }

    @Test
    void idleThreshold_unknownCategory_fallsBackToDefault() {
        when(thresholdRepo.findAll()).thenReturn(List.of());
        assertThat(resolver.idleThresholdSeconds("Nonexistent")).isEqualTo(300);
    }

    // ── M13 rule override hook ──

    @org.junit.jupiter.api.Nested
    class WithRuleOverrides {
        @Mock private TrackingRuleRepository ruleRepo;
        private CategoryResolver resolverWithRules;

        @BeforeEach
        void setUp() {
            resolverWithRules = new CategoryResolver(bundleRepo, domainRepo, thresholdRepo, ruleRepo);
        }

        @Test
        void macosRuleOverridesBundleMapping() {
            when(ruleRepo.findAll()).thenReturn(List.of(
                rule("macos", "org.mozilla.firefox", "Reading")));

            assertThat(resolverWithRules.categoryForBundle("org.mozilla.firefox"))
                .isEqualTo("Reading");
        }

        @Test
        void browserRuleOverridesDomainMapping() {
            when(ruleRepo.findAll()).thenReturn(List.of(
                rule("browser", "youtube.com", "Learning")));

            assertThat(resolverWithRules.categoryForDomain("youtube.com"))
                .isEqualTo("Learning");
        }

        @Test
        void ruleMatchingIsCaseInsensitive() {
            when(ruleRepo.findAll()).thenReturn(List.of(
                rule("browser", "GitHub.com", "Code")));
            assertThat(resolverWithRules.categoryForDomain("github.com"))
                .isEqualTo("Code");
        }

        @Test
        void noMatchingRule_fallsBackToMapping() {
            when(bundleRepo.findAll()).thenReturn(List.of(
                new CategoryMapping("com.apple.dt.Xcode", "Code")));
            when(ruleRepo.findAll()).thenReturn(List.of(
                rule("macos", "org.mozilla.firefox", "Reading")));
            assertThat(resolverWithRules.categoryForBundle("com.apple.dt.Xcode"))
                .isEqualTo("Code");
        }

        private TrackingRule rule(String source, String appName, String category) {
            TrackingRule r = new TrackingRule(source, appName, null, category,
                false, false, false, false, true, false);
            r.setId(1L);
            return r;
        }
    }
}
