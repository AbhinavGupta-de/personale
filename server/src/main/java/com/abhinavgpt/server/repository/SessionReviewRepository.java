package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.entity.SessionReview;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface SessionReviewRepository extends CrudRepository<SessionReview, String> {

    @Query("SELECT * FROM session_reviews WHERE block_date = :date")
    List<SessionReview> findByBlockDate(@Param("date") LocalDate date);
}
