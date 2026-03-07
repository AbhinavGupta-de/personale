package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.TestcontainersConfig;
import com.abhinavgpt.server.entity.AppSession;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jdbc.test.autoconfigure.DataJdbcTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.context.annotation.Import;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfig.class)
class AppSessionRepositoryTest {

    @Autowired
    private AppSessionRepository repository;

    @Test
    void save_persistsSession() {
        AppSession session = new AppSession(
            "Safari", "com.apple.Safari", "Google", Instant.parse("2026-03-07T10:00:00Z"));

        AppSession saved = repository.save(session);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getAppName()).isEqualTo("Safari");
        assertThat(saved.getBundleId()).isEqualTo("com.apple.Safari");
        assertThat(saved.getWindowTitle()).isEqualTo("Google");
        assertThat(saved.getStartedAt()).isEqualTo(Instant.parse("2026-03-07T10:00:00Z"));
        assertThat(saved.getEndedAt()).isNull();
    }

    @Test
    void findById_returnsSavedSession() {
        AppSession session = new AppSession(
            "Terminal", "com.apple.Terminal", null, Instant.parse("2026-03-07T11:00:00Z"));
        AppSession saved = repository.save(session);

        Optional<AppSession> found = repository.findById(saved.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getAppName()).isEqualTo("Terminal");
        assertThat(found.get().getBundleId()).isEqualTo("com.apple.Terminal");
    }

    @Test
    void save_withNullOptionalFields() {
        AppSession session = new AppSession(
            "Unknown", null, null, Instant.parse("2026-03-07T12:00:00Z"));

        AppSession saved = repository.save(session);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getBundleId()).isNull();
        assertThat(saved.getWindowTitle()).isNull();
    }

    @Test
    void count_reflectsInsertedRows() {
        long before = repository.count();

        AppSession first = repository.save(new AppSession(
            "Safari", "com.apple.Safari", null, Instant.parse("2026-03-07T10:00:00Z")));
        // Close first session before inserting second (unique index enforces single active)
        first.setEndedAt(Instant.parse("2026-03-07T10:01:00Z"));
        repository.save(first);

        repository.save(new AppSession(
            "Terminal", "com.apple.Terminal", null, Instant.parse("2026-03-07T10:01:00Z")));

        assertThat(repository.count()).isEqualTo(before + 2);
    }

    @Test
    void uniqueIndex_rejectsTwoActiveSessions() {
        repository.save(new AppSession(
            "Safari", "com.apple.Safari", null, Instant.parse("2026-03-07T10:00:00Z")));

        assertThatThrownBy(() -> repository.save(new AppSession(
            "Terminal", "com.apple.Terminal", null, Instant.parse("2026-03-07T10:01:00Z"))))
            .isInstanceOf(org.springframework.dao.DuplicateKeyException.class);
    }
}
