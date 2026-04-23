#if os(macOS)
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device auto-classifier for previously-unseen app bundles.
/// Uses Apple Foundation Models (macOS 26+). Offline, free, private.
///
/// Flow:
///   1. `AppTracker` observes a new frontmost app with no bundle → category mapping.
///   2. Caller passes (appName, bundleId, allowed categories) here.
///   3. We prompt the on-device LLM to pick one of the allowed categories.
///   4. On success, caller PUTs `/api/settings/categories/mapping` so the
///      server's `CategoryResolver` picks it up on next cache cycle.
///
/// Gracefully no-ops on hardware/OS without FoundationModels support.
@MainActor
final class CategoryClassifier {
    static let shared = CategoryClassifier()

    /// Guard against classifying the same bundle twice in a session.
    private var inFlight: Set<String> = []
    private var done: Set<String> = []

    private let api = APIClient.shared

    enum Unavailable: Error {
        case osTooOld
        case modelUnavailable(String)
    }

    /// Classify + persist. Silently no-ops if FM unavailable or bundle already
    /// classified. Caller fire-and-forgets.
    func classifyIfNeeded(appName: String, bundleId: String, allowed: [String]) {
        guard !bundleId.isEmpty, !allowed.isEmpty else { return }
        guard !done.contains(bundleId), !inFlight.contains(bundleId) else { return }
        inFlight.insert(bundleId)

        Task { [weak self] in
            defer { self?.inFlight.remove(bundleId) }
            guard let self else { return }
            do {
                let category = try await self.askModel(appName: appName,
                                                        bundleId: bundleId,
                                                        allowed: allowed)
                guard allowed.contains(category) else {
                    print("[CategoryClassifier] Model returned unknown category '\(category)' for \(bundleId); skipping")
                    return
                }
                try await self.api.upsertCategoryMapping(bundleId: bundleId, category: category)
                self.done.insert(bundleId)
                print("[CategoryClassifier] \(bundleId) → \(category)")
            } catch Unavailable.osTooOld {
                // Quiet: older macOS, no FM. No point retrying.
                self.done.insert(bundleId)
            } catch {
                print("[CategoryClassifier] \(bundleId) failed: \(error)")
            }
        }
    }

    // MARK: - Foundation Models call

    private func askModel(appName: String, bundleId: String, allowed: [String]) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            guard case .available = availability else {
                throw Unavailable.modelUnavailable(String(describing: availability))
            }
            let session = LanguageModelSession()
            let joined = allowed.joined(separator: " | ")
            let prompt = """
                Classify this macOS app into exactly ONE of the allowed categories.
                Return only the category name, no punctuation, no explanation.

                App name: \(appName)
                Bundle id: \(bundleId)

                Allowed categories: \(joined)
                """
            let response = try await session.respond(to: prompt)
            return response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".\"'`"))
        } else {
            throw Unavailable.osTooOld
        }
        #else
        throw Unavailable.osTooOld
        #endif
    }
}
#endif
