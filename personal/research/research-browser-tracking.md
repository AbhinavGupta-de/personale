# Research: Cross-Platform Tracking & Browser Extensions

~~If the ultimate goal is a cross-platform ecosystem (macOS, Windows, Linux, Android, iOS), the architectural strategy must avoid relying entirely on native OS hacks (like AppleScript on macOS, UIAutomation for Windows, X11/Wayland hooks for Linux) to extract deep data like browser URLs. Trying to do so is a maintenance nightmare.~~

**Implementation Note:** The long-term reasoning is fine, but this framing is too broad for the current product stage. The current dashboard and product loop are still macOS-first. Do not let cross-platform browser/url capture drive V1 architecture or UI decisions. The reference dashboard can be built first using app sessions, categories, timeline blocks, and a simple activity feed without exact browser URLs.

To keep this highly decoupled and scalable, the following ~~**"Hub and Spoke" Architecture**~~ is recommended:

**Implementation Note:** The hub-and-spoke idea is still good. But the spokes should be staged in this order:
- native app session tracking first
- optional window title support second
- browser extension later
- mobile last

## The Hub: Spring Boot Backend

The Java Spring Boot backend is the **Hub**. It is already platform-agnostic because it just receives generic JSON payloads over HTTP. It will remain the centralized ingestion engine for all events.

**Implementation Note:** This is correct. But for the dashboard design, the backend now needs richer read models than a single `GET /api/stats/today`. The next useful endpoints are:
- `GET /api/stats/timeline?date=YYYY-MM-DD`
- `GET /api/activity?date=YYYY-MM-DD`
- `GET /api/stats/categories?date=YYYY-MM-DD` or an expanded daily stats payload
- possibly `GET /api/stats/work-hours?date=YYYY-MM-DD`

## Spoke 1: Native OS Daemons (App Tracking)

We need a lightweight daemon for each desktop OS, but their job becomes much simpler: ~~**they only report the App Name and App ID.**~~ They do not attempt to read what is happening *inside* the apps (like reading browser tabs).

**Implementation Note:** For the current UI goals, "only app name and app id" is too restrictive. The native daemon should at minimum send:
- `appName`
- `bundleId`
- `timestamp`

Later it should optionally send:
- `windowTitle`
- `source` / `platform`
- idle / resume events

That is enough to power the timeline, activity feed, and workblocks without full browser URL capture.

*   **macOS:** The current Swift app (`NSWorkspace` notifications).
*   ~~**Windows:** A small C# or Rust background service using `SetWinEventHook` to get the active window.~~
*   ~~**Linux:** A Python or Go script querying X11/Wayland for the active window class.~~

**Implementation Note:** Windows and Linux are reasonable future directions, but both are post-V1. They should not influence the current schema or dashboard priorities.

## Spoke 2: One Cross-Platform Browser Extension (Web Tracking)

~~Instead of the native OS apps trying to read browser tabs via accessibility APIs or scripts, we build **One Cross-Platform Browser Extension** (using Javascript/TypeScript).~~

**Implementation Note:** This is a valid post-V1 enrichment path, not a prerequisite for the first dashboard implementation.

*   **Supported Browsers:** ~~Chrome, Edge, Brave, Arc, Firefox, etc.~~
    **Implementation Note:** Chromium-family browsers are the easiest shared path. Firefox usually needs extra work. Do not assume one codebase behaves identically across every browser.
*   **Cross-Platform:** ~~It works identically across macOS, Windows, and Linux.~~
    **Implementation Note:** Conceptually yes, but browser APIs, packaging, and permissions still differ enough that this should be treated as a later product track.
*   **Mechanism:** It listens to the browser's native `tabs.onActivated` and `tabs.onUpdated` events.
*   **Data Delivery:** ~~It sends its own payload directly to the Java backend (e.g., `POST /api/events/web { url: "github.com", title: "Repo", timestamp: ... }`).~~
    **Implementation Note:** Prefer a shared event envelope or a normalized event contract instead of hardcoding a separate web-only endpoint too early.

### How the Backend Handles This
~~When the backend sees you are using "Google Chrome" (reported from the native OS daemon), it can ignore the OS data for deep stats and instead look at the data stream coming from your Browser Extension to see exactly what URL you are on.~~

**Implementation Note:** The backend should merge these streams, not simply ignore one. The native app remains the source of focus state. A browser extension is just enrichment for browser sessions.

## Spoke 3: Mobile Tracking (The Hardest Part)

~~Mobile operating systems are aggressively sandboxed for privacy.~~

**Implementation Note:** True, but this entire section is out of scope for the current dashboard and V1 handoff.

*   ~~**Android:** Highly feasible. An Android app can request the `AccessibilityService` permission. This allows the app to see every time the user switches apps and send that event payload to the Java backend.~~
*   ~~**iOS (iPhone/iPad):** **Extremely restricted.** Apple does not allow background apps to see what other apps the user is using. You can use Apple's `FamilyControls` (Screen Time API) to build local charts within the app, but Apple explicitly blocks developers from extracting that granular app usage data and sending it to a remote server (like our Spring Boot backend) to protect user privacy. For iOS, tracking might be limited to manually inputting time or using custom Shortcuts automations.~~

**Implementation Note:** Leave mobile research documented, but do not let it shape the current schema or UI roadmap.

## Summary

~~1.  **Keep the Java Backend decoupled:** It's already the perfect ingestion engine.~~
~~2.  **Keep native OS apps simple:** Let them just track desktop apps. Do not add AppleScript or heavy Accessibility API hooks for browser tracking.~~
~~3.  **Build a Browser Extension:** For deep web tracking (URLs), build a simple Chrome/Web extension that POSTs directly to the backend. This gives deep tracking on Mac, Windows, and Linux immediately.~~

**Revised Priority Order For The Current Product**

1. Keep the Java backend as the single ingestion and query layer.
2. Finish the macOS dashboard using current session data first.
3. Add category mapping plus timeline/activity endpoints.
4. Add optional window title support next if needed.
5. Defer browser extension work until the rest of the dashboard proves useful.
6. Defer Windows/Linux/Android/iOS work entirely until after macOS V1 is stable.
