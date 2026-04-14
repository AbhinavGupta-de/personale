package com.abhinavgpt.server.service;

import com.abhinavgpt.server.domain.MergedBlock;
import com.abhinavgpt.server.entity.AppSession;
import com.abhinavgpt.server.entity.BrowserEvent;
import com.abhinavgpt.server.entity.CategoryMapping;
import com.abhinavgpt.server.entity.CategoryThreshold;
import com.abhinavgpt.server.repository.CategoryMappingRepository;
import com.abhinavgpt.server.repository.CategoryThresholdRepository;
import com.abhinavgpt.server.repository.DomainCategoryMappingRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;

@ExtendWith(MockitoExtension.class)
class SessionMergeServiceTest {

    @Mock private CategoryMappingRepository bundleRepo;
    @Mock private DomainCategoryMappingRepository domainRepo;
    @Mock private CategoryThresholdRepository thresholdRepo;

    private SessionMergeService mergeService;

    private static final Instant DAY_START = Instant.parse("2026-04-10T00:00:00Z");
    private static final Instant DAY_END = Instant.parse("2026-04-11T00:00:00Z");

    @BeforeEach
    void setUp() {
        lenient().when(bundleRepo.findAll()).thenReturn(List.of(
            new CategoryMapping("com.apple.dt.Xcode", "Code"),
            new CategoryMapping("com.mitchellh.ghostty", "Code"),
            new CategoryMapping("com.tinyspeck.slackmacgap", "Communication"),
            new CategoryMapping("com.apple.iBooksX", "Reading")));
        lenient().when(thresholdRepo.findAll()).thenReturn(List.of(
            new CategoryThreshold("Code", 600),
            new CategoryThreshold("Reading", 900),
            new CategoryThreshold("Communication", 180)));
        CategoryResolver resolver = new CategoryResolver(bundleRepo, domainRepo, thresholdRepo);
        DomainTimeService domainTimeService = new DomainTimeService(resolver);
        mergeService = new SessionMergeService(resolver, domainTimeService);
    }

    private AppSession session(String appName, String bundleId, String startIso, String endIso) {
        AppSession s = new AppSession(appName, bundleId, null, Instant.parse(startIso));
        s.setEndedAt(Instant.parse(endIso));
        return s;
    }

    @Test
    void mergesAdjacentSameCategoryWithinThreshold() {
        // Two Code blocks, 5 min apart. Code threshold is 10 min → merge.
        List<AppSession> sessions = List.of(
            session("Xcode", "com.apple.dt.Xcode", "2026-04-10T10:00:00Z", "2026-04-10T10:30:00Z"),
            session("Ghostty", "com.mitchellh.ghostty", "2026-04-10T10:35:00Z", "2026-04-10T11:00:00Z"));

        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            sessions, DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());

        assertThat(blocks).hasSize(1);
        assertThat(blocks.getFirst().category()).isEqualTo("Code");
    }

    @Test
    void doesNotMerge_gapExceedsThreshold() {
        // Two Code blocks, 15 min apart. Code threshold is 10 min → stay split.
        List<AppSession> sessions = List.of(
            session("Xcode", "com.apple.dt.Xcode", "2026-04-10T10:00:00Z", "2026-04-10T10:30:00Z"),
            session("Ghostty", "com.mitchellh.ghostty", "2026-04-10T10:45:00Z", "2026-04-10T11:00:00Z"));

        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            sessions, DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());

        assertThat(blocks).hasSize(2);
    }

    @Test
    void readingMergesAcrossLongGap() {
        // Two Reading blocks 13 min apart. Reading threshold is 15 min → merge.
        List<AppSession> sessions = List.of(
            session("Books", "com.apple.iBooksX", "2026-04-10T10:00:00Z", "2026-04-10T10:30:00Z"),
            session("Books", "com.apple.iBooksX", "2026-04-10T10:43:00Z", "2026-04-10T11:00:00Z"));

        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            sessions, DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());

        assertThat(blocks).hasSize(1);
        assertThat(blocks.getFirst().category()).isEqualTo("Reading");
    }

    @Test
    void communicationSplitsOnShortGap() {
        // Two Communication blocks 4 min apart. Communication threshold is 3 min → split.
        List<AppSession> sessions = List.of(
            session("Slack", "com.tinyspeck.slackmacgap", "2026-04-10T10:00:00Z", "2026-04-10T10:20:00Z"),
            session("Slack", "com.tinyspeck.slackmacgap", "2026-04-10T10:24:00Z", "2026-04-10T10:40:00Z"));

        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            sessions, DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());

        assertThat(blocks).hasSize(2);
    }

    @Test
    void briefInterruption_absorbedIntoLongerNeighbor() {
        // 30 min Code → 1 min Communication → 30 min Code.
        // Communication is < 5 min MERGE_THRESHOLD → absorbed. Then both
        // Code blocks re-merge into one.
        List<AppSession> sessions = List.of(
            session("Xcode", "com.apple.dt.Xcode", "2026-04-10T10:00:00Z", "2026-04-10T10:30:00Z"),
            session("Slack", "com.tinyspeck.slackmacgap", "2026-04-10T10:30:00Z", "2026-04-10T10:31:00Z"),
            session("Xcode", "com.apple.dt.Xcode", "2026-04-10T10:31:00Z", "2026-04-10T11:00:00Z"));

        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            sessions, DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());

        assertThat(blocks).hasSize(1);
        assertThat(blocks.getFirst().category()).isEqualTo("Code");
    }

    @Test
    void briefCommunicationAbsorbed_usingMaxOfNeighborThresholds() {
        // A 1-min Communication block sits 8 min before a 30-min Reading block.
        // Communication threshold (180s) is too small for the 480s gap, but
        // findAbsorbTarget uses max(comm, reading) = Reading's 900s → absorb.
        // The brief block is relabeled via dominantCategory, so the resulting
        // block is Reading (the much larger neighbor wins).
        List<AppSession> sessions = List.of(
            session("Slack", "com.tinyspeck.slackmacgap", "2026-04-10T10:00:00Z", "2026-04-10T10:01:00Z"),
            session("Books", "com.apple.iBooksX", "2026-04-10T10:09:00Z", "2026-04-10T10:39:00Z"));

        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            sessions, DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());

        assertThat(blocks).hasSize(1);
        assertThat(blocks.getFirst().category()).isEqualTo("Reading");
        assertThat(blocks.getFirst().seconds()).isEqualTo(60 + 30 * 60);
    }

    @Test
    void emptySessions_returnsEmpty() {
        List<MergedBlock> blocks = mergeService.buildMergedBlocks(
            List.of(), DAY_START, DAY_END,
            Instant.parse("2026-04-10T12:00:00Z"), List.of());
        assertThat(blocks).isEmpty();
    }
}
