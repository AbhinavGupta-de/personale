package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.dto.CategoryCreateRequest;
import com.abhinavgpt.server.dto.CategoryResponse;
import com.abhinavgpt.server.dto.CategoryUpdateRequest;
import com.abhinavgpt.server.service.CategoryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
public class CategoriesController {

    private final CategoryService service;

    public CategoriesController(CategoryService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<CategoryResponse>> list() {
        return ResponseEntity.ok(service.list());
    }

    @PostMapping
    public ResponseEntity<CategoryResponse> create(@RequestBody CategoryCreateRequest req) {
        return ResponseEntity.ok(service.create(req));
    }

    @PutMapping("/{name}")
    public ResponseEntity<CategoryResponse> update(@PathVariable String name,
                                                   @RequestBody CategoryUpdateRequest req) {
        return ResponseEntity.ok(service.update(name, req));
    }

    @DeleteMapping("/{name}")
    public ResponseEntity<Void> delete(@PathVariable String name) {
        service.delete(name);
        return ResponseEntity.noContent().build();
    }
}
