package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.entity.BrowserEvent;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface BrowserEventRepository extends CrudRepository<BrowserEvent, Long> {

    @Query("SELECT * FROM browser_events WHERE timestamp >= :start AND timestamp < :end ORDER BY timestamp LIMIT 10000")
    List<BrowserEvent> findByTimestampBetween(@Param("start") Instant start, @Param("end") Instant end);
}
