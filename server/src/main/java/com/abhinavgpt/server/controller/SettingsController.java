package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.repository.CategoryMappingRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
}
