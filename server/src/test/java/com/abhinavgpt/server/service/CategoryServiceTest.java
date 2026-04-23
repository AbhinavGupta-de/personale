package com.abhinavgpt.server.service;

import com.abhinavgpt.server.dto.CategoryCreateRequest;
import com.abhinavgpt.server.dto.CategoryResponse;
import com.abhinavgpt.server.dto.CategoryUpdateRequest;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CategoryServiceTest {

    @Mock
    private CategoryThresholdRepository repo;

    private CategoryService service;

    @BeforeEach
    void setUp() {
        service = new CategoryService(repo);
    }

    @Test
    void list_returnsAlphabeticallySorted() {
        when(repo.findAll()).thenReturn(List.of(
            new CategoryThreshold("Zulu", 300),
            new CategoryThreshold("Alpha", 300),
            new CategoryThreshold("middle", 300)
        ));

        List<CategoryResponse> result = service.list();

        assertThat(result).extracting(CategoryResponse::name)
            .containsExactly("Alpha", "middle", "Zulu");
    }

    @Test
    void create_rejectsBlankName() {
        assertThatThrownBy(() -> service.create(new CategoryCreateRequest(
                "  ", null, null, null, null, null, null, null)))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void create_rejectsDuplicate() {
        when(repo.existsById("Code")).thenReturn(true);

        assertThatThrownBy(() -> service.create(new CategoryCreateRequest(
                "Code", null, null, null, null, null, null, null)))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void create_appliesDefaultsForMissingFields() {
        when(repo.existsById("NewCat")).thenReturn(false);
        when(repo.save(any(CategoryThreshold.class)))
            .thenAnswer(inv -> inv.getArgument(0));

        CategoryResponse result = service.create(
            new CategoryCreateRequest("NewCat", null, null, null, null, null, null, null));

        assertThat(result.name()).isEqualTo("NewCat");
        assertThat(result.idleThresholdSeconds()).isEqualTo(300);
        assertThat(result.focus()).isTrue();
        assertThat(result.workHours()).isTrue();
        assertThat(result.idleDetection()).isTrue();
        assertThat(result.distractionBlocker()).isFalse();
    }

    @Test
    void update_onlyChangesProvidedFields() {
        CategoryThreshold existing = new CategoryThreshold("Code", 600, true, true, true, false);
        when(repo.findById("Code")).thenReturn(Optional.of(existing));
        when(repo.save(any(CategoryThreshold.class)))
            .thenAnswer(inv -> inv.getArgument(0));

        CategoryResponse result = service.update("Code", new CategoryUpdateRequest(
            null, null, null, null, true, null, null));

        assertThat(result.idleThresholdSeconds()).isEqualTo(600);
        assertThat(result.focus()).isTrue();
        assertThat(result.distractionBlocker()).isTrue();
    }

    @Test
    void update_unknownCategory_throwsNotFound() {
        when(repo.findById("Nope")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update("Nope", new CategoryUpdateRequest(
                null, null, null, null, null, null, null)))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void delete_unknownCategory_throwsNotFound() {
        when(repo.existsById("Nope")).thenReturn(false);

        assertThatThrownBy(() -> service.delete("Nope"))
            .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void delete_callsRepoDelete() {
        when(repo.existsById("Code")).thenReturn(true);

        service.delete("Code");

        verify(repo).deleteById("Code");
    }
}
