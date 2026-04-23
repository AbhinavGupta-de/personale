#if os(macOS)
import CryptoKit
import Foundation

/// Stable key for a focus-session block, matching the server's formula:
///   sha256(date|startTime|endTime|category)[0..16]
/// Used to look up SessionReview rows for a given FocusSessionResponse.
enum ReviewKey {
    static func make(date: String, startTime: String, endTime: String, category: String) -> String {
        let input = "\(date)|\(startTime)|\(endTime)|\(category)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).lowercased()
    }
}

/// Best label for a session: user-entered title, AI-generated draft, or
/// category as fallback. Used by Activity + Dashboard session views.
func bestLabel(title: String?, aiTitle: String?, category: String) -> String {
    if let t = title, !t.isEmpty { return t }
    if let t = aiTitle, !t.isEmpty { return t }
    return category
}
#endif
