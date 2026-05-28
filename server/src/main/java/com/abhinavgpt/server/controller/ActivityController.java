package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.CurrentActivityResponse;
import com.abhinavgpt.server.service.ActivityService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.ZoneId;

@RestController
@RequestMapping("/api/activity")
public class ActivityController {

    private final ActivityService activityService;

    public ActivityController(ActivityService activityService) {
        this.activityService = activityService;
    }

    @GetMapping("/current")
    public ResponseEntity<CurrentActivityResponse> getCurrent(
            @RequestParam(defaultValue = "0") int dayStartHour,
            @RequestParam(defaultValue = "8") int targetHours) {
        return ResponseEntity.ok(
            activityService.getCurrentActivity(
                ZoneId.systemDefault(), Instant.now(), dayStartHour, targetHours));
    }
}
