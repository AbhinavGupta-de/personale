package com.abhinavgpt.server.controller;

import com.abhinavgpt.server.config.SecurityConfig;
import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SettingsController.class)
@Import(SecurityConfig.class)
class SettingsControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private CategoryMappingRepository categoryRepo;

    @Test
    void getCategories_returnsMappings() throws Exception {
        when(categoryRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.apple.Safari", "Browsing")
        ));

        mockMvc.perform(get("/api/settings/categories"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.mappings['com.apple.dt.Xcode']").value("Code"))
            .andExpect(jsonPath("$.mappings['com.apple.Safari']").value("Browsing"));
    }

    @Test
    void upsertMapping_insertsWhenNew() throws Exception {
        when(categoryRepo.findByBundleId("org.mozilla.firefox")).thenReturn(Optional.empty());
        when(categoryRepo.save(any(CategoryMapping.class)))
            .thenAnswer(inv -> inv.getArgument(0));

        mockMvc.perform(put("/api/settings/categories/mapping")
                .contentType("application/json")
                .content("{\"bundleId\":\"org.mozilla.firefox\",\"category\":\"Reading\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.bundleId").value("org.mozilla.firefox"))
            .andExpect(jsonPath("$.category").value("Reading"));

        verify(categoryRepo).save(any(CategoryMapping.class));
    }

    @Test
    void upsertMapping_updatesExisting() throws Exception {
        CategoryMapping existing = new CategoryMapping("com.apple.Safari", "Browsing");
        existing.setId(5L);
        when(categoryRepo.findByBundleId("com.apple.Safari")).thenReturn(Optional.of(existing));
        when(categoryRepo.save(any(CategoryMapping.class)))
            .thenAnswer(inv -> inv.getArgument(0));

        mockMvc.perform(put("/api/settings/categories/mapping")
                .contentType("application/json")
                .content("{\"bundleId\":\"com.apple.Safari\",\"category\":\"Reading\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.category").value("Reading"));
    }

    @Test
    void upsertMapping_rejectsBlankInput() throws Exception {
        mockMvc.perform(put("/api/settings/categories/mapping")
                .contentType("application/json")
                .content("{\"bundleId\":\"\",\"category\":\"Code\"}"))
            .andExpect(status().isBadRequest());
    }
}
