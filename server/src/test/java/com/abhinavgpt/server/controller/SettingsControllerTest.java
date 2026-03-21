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

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
}
