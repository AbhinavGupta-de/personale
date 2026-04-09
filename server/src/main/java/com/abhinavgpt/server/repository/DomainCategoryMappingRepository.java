package com.abhinavgpt.server.repository;

import com.abhinavgpt.server.entity.DomainCategoryMapping;
import org.springframework.data.repository.CrudRepository;

import java.util.Optional;

public interface DomainCategoryMappingRepository extends CrudRepository<DomainCategoryMapping, Long> {

    Optional<DomainCategoryMapping> findByDomain(String domain);
}
