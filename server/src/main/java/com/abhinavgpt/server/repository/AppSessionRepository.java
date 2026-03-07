package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.entity.AppSession;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface AppSessionRepository extends CrudRepository<AppSession, Long> {

    @Query("SELECT * FROM app_sessions WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1 FOR UPDATE")
    Optional<AppSession> findActiveSession();

    @Query("SELECT * FROM app_sessions WHERE started_at < :endExclusive AND (ended_at >= :start OR ended_at IS NULL)")
    List<AppSession> findSessionsOverlapping(@Param("start") Instant start,
                                             @Param("endExclusive") Instant endExclusive);
}
