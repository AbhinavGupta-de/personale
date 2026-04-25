#if os(macOS)
import AppKit
import ApplicationServices
import Foundation

/// Per-app extractors that turn a frontmost NSRunningApplication into a
/// human-readable "enrichedContext" string we attach to each AppSession.
/// Everything is best-effort — returns nil on any AX failure — so the
/// fallback path (plain window_title) still works.
///
/// Strings here are consumed by SessionInsightService.buildActivitySummary
/// and shown verbatim to Claude Haiku. Keep them compact and information-dense.
enum WindowContextExtractor {

    /// Route by bundle id. Returns nil for apps with no enricher defined.
    static func extract(app: NSRunningApplication) -> String? {
        guard AXIsProcessTrusted(), let bundleId = app.bundleIdentifier else { return nil }
        switch bundleId {
        case "com.mitchellh.ghostty":
            return ghosttyContext(app: app)
        case "com.apple.dt.Xcode":
            return xcodeContext(app: app)
        case "com.tinyspeck.slackmacgap":
            return slackContext(app: app)
        default:
            return nil
        }
    }

    // MARK: - Slack
    //
    // Slack's frontmost-window AX title follows "#channel – Workspace – Slack"
    // (em dash) or "Channel-name (Channel) – Workspace – Slack". Parse the
    // first segment as the active channel/DM and pass workspace alongside.

    private static func slackContext(app: NSRunningApplication) -> String? {
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var winValue: AnyObject?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &winValue) == .success,
              let win = winValue as! AXUIElement? else { return nil }
        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String, !title.isEmpty else { return nil }

        // Split on em-dash variants. Slack uses U+2013 EN DASH between segments.
        let parts = title.components(separatedBy: CharacterSet(charactersIn: "–—-"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return "Slack · \(title)" }
        let channel = parts[0]
        let workspace = parts.count >= 3 ? parts[1] : ""
        return workspace.isEmpty
            ? "Slack · \(channel)"
            : "Slack · \(channel) (workspace: \(workspace))"
    }

    // MARK: - Ghostty
    //
    // Ghostty doesn't expose scrollback, cwd, or OSC-7 externally. The tab-title
    // attribute on the selected AXRadioButton inside the AXTabGroup is the richest
    // signal we can read via AX. Users often configure `window-title "%d • %n"` in
    // their config so the tab title contains cwd basename + running command.

    private static func ghosttyContext(app: NSRunningApplication) -> String? {
        let ax = AXUIElementCreateApplication(app.processIdentifier)

        // Focused window
        var winValue: AnyObject?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &winValue) == .success,
              let win = winValue as! AXUIElement? else { return nil }

        // Walk children for a tab group
        if let tabTitle = findSelectedTabTitle(in: win) {
            return "Ghostty · \(tabTitle)"
        }
        // Fallback to window title
        var titleValue: AnyObject?
        if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleValue) == .success,
           let t = titleValue as? String, !t.isEmpty {
            return "Ghostty · \(t)"
        }
        return nil
    }

    private static func findSelectedTabTitle(in element: AXUIElement) -> String? {
        // Depth-first walk, capped to keep AX calls bounded.
        var stack: [(AXUIElement, Int)] = [(element, 0)]
        var visited = 0
        while let (node, depth) = stack.popLast(), visited < 200 {
            visited += 1
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &roleValue)
            if let role = roleValue as? String, role == "AXTabGroup" {
                var selectedValue: AnyObject?
                if AXUIElementCopyAttributeValue(node, kAXValueAttribute as CFString, &selectedValue) == .success,
                   let tab = selectedValue as! AXUIElement? {
                    var titleValue: AnyObject?
                    if AXUIElementCopyAttributeValue(tab, kAXTitleAttribute as CFString, &titleValue) == .success,
                       let t = titleValue as? String, !t.isEmpty {
                        return t
                    }
                }
            }
            if depth < 6 {
                var childrenValue: AnyObject?
                if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                   let children = childrenValue as? [AXUIElement] {
                    for c in children.prefix(30) { stack.append((c, depth + 1)) }
                }
            }
        }
        return nil
    }

    // MARK: - Xcode
    //
    // Xcode exposes AXDocument on the frontmost window — a file:// URL for the
    // currently-open source file. From the path we can walk up to find the
    // enclosing .git and resolve HEAD for the branch name, zero-plugin.

    private static func xcodeContext(app: NSRunningApplication) -> String? {
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var winValue: AnyObject?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &winValue) == .success,
              let win = winValue as! AXUIElement? else { return nil }

        var docValue: AnyObject?
        guard AXUIElementCopyAttributeValue(win, kAXDocumentAttribute as CFString, &docValue) == .success,
              let docString = docValue as? String,
              let fileURL = URL(string: docString), fileURL.isFileURL
        else { return nil }

        let filePath = fileURL.path
        let fileName = fileURL.lastPathComponent
        if let (repo, branch) = gitRepoAndBranch(forFilePath: filePath) {
            return "Xcode · \(fileName) · repo \(repo) @ \(branch)"
        }
        return "Xcode · \(fileName)"
    }

    // MARK: - git resolver

    /// Walks up from a file path to find .git; returns (repo-name, branch).
    /// Reads .git/HEAD directly — no shell-out, no permission prompts.
    private static func gitRepoAndBranch(forFilePath path: String) -> (String, String)? {
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        for _ in 0..<20 {
            let gitPath = dir.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: gitPath.path, isDirectory: &isDir), isDir.boolValue {
                let headURL = gitPath.appendingPathComponent("HEAD")
                if let head = try? String(contentsOf: headURL, encoding: .utf8) {
                    let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
                    let branch: String
                    if trimmed.hasPrefix("ref: refs/heads/") {
                        branch = String(trimmed.dropFirst("ref: refs/heads/".count))
                    } else {
                        branch = String(trimmed.prefix(7))  // detached HEAD sha
                    }
                    return (dir.lastPathComponent, branch)
                }
            }
            let parent = dir.deletingLastPathComponent()
            if parent == dir { break }  // reached /
            dir = parent
        }
        return nil
    }
}
#endif
