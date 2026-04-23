package com.abhinavgpt.server.config;

import com.abhinavgpt.server.entity.PomodoroSessionInsight;
import com.abhinavgpt.server.entity.SessionReview;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.relational.core.mapping.event.AfterConvertCallback;

/**
 * Spring Data JDBC uses Persistable.isNew() to decide insert vs update.
 * Our entities default newRecord=true, so we need to flip it after load.
 * Without this, save() on a loaded entity triggers a duplicate-key error.
 */
@Configuration
class PersistableCallbacks {

    @Bean
    AfterConvertCallback<SessionReview> sessionReviewAfterConvert() {
        return entity -> { entity.markPersisted(); return entity; };
    }

    @Bean
    AfterConvertCallback<PomodoroSessionInsight> pomodoroInsightAfterConvert() {
        return entity -> { entity.markPersisted(); return entity; };
    }
}
