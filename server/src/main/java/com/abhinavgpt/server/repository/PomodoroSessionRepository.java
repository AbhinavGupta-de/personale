package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.entity.PomodoroSession;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface PomodoroSessionRepository extends CrudRepository<PomodoroSession, Long> {

    @Query("""
        SELECT * FROM pomodoro_sessions
        WHERE started_at >= :start AND started_at < :end
        ORDER BY started_at DESC
        """)
    List<PomodoroSession> findByStartedAtBetween(@Param("start") Instant start,
                                                 @Param("end") Instant end);
}
