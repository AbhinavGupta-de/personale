package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.TrackingRuleRequest;
import com.abhinavgpt.server.dto.TrackingRuleResponse;
import com.abhinavgpt.server.service.TrackingRuleService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tracking-rules")
public class TrackingRulesController {

    private final TrackingRuleService service;

    public TrackingRulesController(TrackingRuleService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<TrackingRuleResponse>> list() {
        return ResponseEntity.ok(service.list());
    }

    @PostMapping
    public ResponseEntity<TrackingRuleResponse> create(@RequestBody TrackingRuleRequest req) {
        return ResponseEntity.ok(service.create(req));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TrackingRuleResponse> update(@PathVariable Long id,
                                                       @RequestBody TrackingRuleRequest req) {
        return ResponseEntity.ok(service.update(id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
