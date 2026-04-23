package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/settings")
public class SettingsController {

    private final CategoryMappingRepository categoryRepo;

    public SettingsController(CategoryMappingRepository categoryRepo) {
        this.categoryRepo = categoryRepo;
    }

    @GetMapping("/categories")
    public ResponseEntity<Map<String, Object>> getCategories() {
        Map<String, String> mappings = new LinkedHashMap<>();
        categoryRepo.findAll().forEach(m -> mappings.put(m.getBundleId(), m.getCategory()));
        return ResponseEntity.ok(Map.of("mappings", mappings));
    }

    public record MappingUpsertRequest(String bundleId, String category) {}

    /** Upsert a bundleId → category mapping. Used by FM auto-categorize on-device. */
    @PutMapping("/categories/mapping")
    public ResponseEntity<Map<String, String>> upsertMapping(@RequestBody MappingUpsertRequest req) {
        if (req.bundleId() == null || req.bundleId().isBlank()
            || req.category() == null || req.category().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "bundleId and category are required");
        }
        CategoryMapping m = categoryRepo.findByBundleId(req.bundleId())
            .orElseGet(() -> new CategoryMapping(req.bundleId(), req.category()));
        m.setCategory(req.category());
        categoryRepo.save(m);
        return ResponseEntity.ok(Map.of(
            "bundleId", req.bundleId(),
            "category", req.category()));
    }
}
