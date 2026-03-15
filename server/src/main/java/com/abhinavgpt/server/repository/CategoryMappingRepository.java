package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.entity.CategoryMapping;
import org.springframework.data.repository.CrudRepository;

import java.util.Optional;

public interface CategoryMappingRepository extends CrudRepository<CategoryMapping, Long> {

    Optional<CategoryMapping> findByBundleId(String bundleId);
}
