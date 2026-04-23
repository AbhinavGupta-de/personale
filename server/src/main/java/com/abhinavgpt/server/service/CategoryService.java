package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.CategoryCreateRequest;
import com.abhinavgpt.server.dto.CategoryResponse;
import com.abhinavgpt.server.dto.CategoryUpdateRequest;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Comparator;
import java.util.List;

@Service
public class CategoryService {

    private static final int DEFAULT_IDLE_THRESHOLD = 300;

    private final CategoryThresholdRepository repo;

    public CategoryService(CategoryThresholdRepository repo) {
        this.repo = repo;
    }

    public List<CategoryResponse> list() {
        List<CategoryResponse> out = new java.util.ArrayList<>();
        repo.findAll().forEach(t -> out.add(toResponse(t)));
        out.sort(Comparator.comparing(CategoryResponse::name, String.CASE_INSENSITIVE_ORDER));
        return out;
    }

    public CategoryResponse create(CategoryCreateRequest req) {
        String name = req.name() == null ? "" : req.name().trim();
        if (name.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "name is required");
        }
        if (repo.existsById(name)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "category already exists");
        }
        CategoryThreshold t = new CategoryThreshold(
            name,
            req.idleThresholdSeconds() != null ? req.idleThresholdSeconds() : DEFAULT_IDLE_THRESHOLD,
            req.focus() != null ? req.focus() : true,
            req.workHours() != null ? req.workHours() : true,
            req.idleDetection() != null ? req.idleDetection() : true,
            req.distractionBlocker() != null ? req.distractionBlocker() : false
        );
        if (req.dailyGoalSeconds() != null) t.setDailyGoalSeconds(Math.max(0, req.dailyGoalSeconds()));
        if (req.goalIsMax() != null) t.setGoalIsMax(req.goalIsMax());
        return toResponse(repo.save(t));
    }

    public CategoryResponse update(String name, CategoryUpdateRequest req) {
        CategoryThreshold t = repo.findById(name).orElseThrow(
            () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "category not found"));
        if (req.idleThresholdSeconds() != null) t.setIdleThresholdSeconds(req.idleThresholdSeconds());
        if (req.focus() != null) t.setFocus(req.focus());
        if (req.workHours() != null) t.setWorkHours(req.workHours());
        if (req.idleDetection() != null) t.setIdleDetection(req.idleDetection());
        if (req.distractionBlocker() != null) t.setDistractionBlocker(req.distractionBlocker());
        if (req.dailyGoalSeconds() != null) t.setDailyGoalSeconds(Math.max(0, req.dailyGoalSeconds()));
        if (req.goalIsMax() != null) t.setGoalIsMax(req.goalIsMax());
        return toResponse(repo.save(t));
    }

    public void delete(String name) {
        if (!repo.existsById(name)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "category not found");
        }
        repo.deleteById(name);
    }

    private CategoryResponse toResponse(CategoryThreshold t) {
        return new CategoryResponse(
            t.getCategory(),
            t.getIdleThresholdSeconds(),
            t.isFocus(),
            t.isWorkHours(),
            t.isIdleDetection(),
            t.isDistractionBlocker(),
            t.getDailyGoalSeconds(),
            t.isGoalIsMax()
        );
    }
}
