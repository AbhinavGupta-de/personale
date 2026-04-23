package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.TrackingRuleRequest;
import com.abhinavgpt.server.dto.TrackingRuleResponse;
import com.abhinavgpt.server.entity.TrackingRule;
import com.abhinavgpt.server.repository.TrackingRuleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrackingRuleServiceTest {

    @Mock
    private TrackingRuleRepository repo;

    private TrackingRuleService service;

    @BeforeEach
    void setUp() {
        service = new TrackingRuleService(repo);
    }

    @Test
    void create_rejectsInvalidSource() {
        TrackingRuleRequest bad = new TrackingRuleRequest(
            "desktop", "Firefox", null, "Browsing",
            null, null, null, null, null, null);

        assertThatThrownBy(() -> service.create(bad))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void create_rejectsMissingRequiredFields() {
        TrackingRuleRequest bad = new TrackingRuleRequest(
            "macos", null, null, "Browsing",
            null, null, null, null, null, null);

        assertThatThrownBy(() -> service.create(bad))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void create_appliesFlagDefaults() {
        when(repo.save(any(TrackingRule.class))).thenAnswer(inv -> {
            TrackingRule r = inv.getArgument(0);
            r.setId(1L);
            return r;
        });

        TrackingRuleResponse result = service.create(new TrackingRuleRequest(
            "macos", "com.apple.Safari", null, "Browsing",
            null, null, null, null, null, null));

        assertThat(result.alwaysBlock()).isFalse();
        assertThat(result.blockFocus()).isFalse();
        assertThat(result.trackTitles()).isTrue();
        assertThat(result.trackFullUrls()).isFalse();
    }

    @Test
    void list_sortsBySourceThenAppName() {
        when(repo.findAll()).thenReturn(List.of(
            rule(1L, "macos", "com.apple.Safari", "Browsing"),
            rule(2L, "browser", "github.com", "Code"),
            rule(3L, "macos", "com.apple.Mail", "Communication")
        ));

        List<TrackingRuleResponse> result = service.list();

        assertThat(result).extracting(TrackingRuleResponse::source, TrackingRuleResponse::appName)
            .containsExactly(
                org.assertj.core.groups.Tuple.tuple("browser", "github.com"),
                org.assertj.core.groups.Tuple.tuple("macos", "com.apple.Mail"),
                org.assertj.core.groups.Tuple.tuple("macos", "com.apple.Safari")
            );
    }

    @Test
    void update_onlyChangesProvidedFields() {
        TrackingRule existing = rule(5L, "macos", "com.apple.Safari", "Browsing");
        when(repo.findById(5L)).thenReturn(Optional.of(existing));
        when(repo.save(any(TrackingRule.class))).thenAnswer(inv -> inv.getArgument(0));

        TrackingRuleResponse updated = service.update(5L, new TrackingRuleRequest(
            null, null, null, "Media", null, null, null, true, null, null));

        assertThat(updated.category()).isEqualTo("Media");
        assertThat(updated.blockFocus()).isTrue();
        assertThat(updated.appName()).isEqualTo("com.apple.Safari");
    }

    private TrackingRule rule(Long id, String source, String appName, String category) {
        TrackingRule r = new TrackingRule(source, appName, null, category,
            false, false, false, false, true, false);
        r.setId(id);
        return r;
    }
}
