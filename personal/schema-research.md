# Schema Research & Design — Phase 3

This document outlines the database schema design for **Personale**, transitioning from a flat structure to a normalized, production-ready architecture.

## 1. Design Philosophy
- ~~**Normalization over Flatness:** Decouple "What is the App" from "When was it used" to allow for future categorization and cleaner reporting.~~
  **Implementation Note:** We went with a **flat** `app_sessions` table for Phase 3. `app_name` and `bundle_id` live directly on each session row. This is the right call for now — one INSERT per event, no upsert-or-get-id dance, no JOINs needed for basic queries. The normalized `applications` table should be introduced in a later phase when we actually add categorization. At that point it's a straightforward migration: create the table, backfill from `SELECT DISTINCT bundle_id, app_name`, add the FK, drop the redundant columns.
- **Granularity:** Every window title change is a distinct session to provide high-fidelity tracking of deep-work vs. context-switching.
- **Integrity First:** Use database-level constraints to prevent "time travel" bugs or overlapping active sessions.
  **Implementation Note:** Adopted. The `CHECK (ended_at IS NULL OR ended_at >= started_at)` constraint is now in the live schema.

---

## 2. Proposed Schema (PostgreSQL)

### ~~Table: `applications`~~
~~Stores unique metadata for each tracked application. This acts as the "Parent" for all sessions.~~

| Column | Type | Constraints | Description |
|---|---|---|---|
| ~~`id`~~ | ~~`SERIAL`~~ | ~~`PRIMARY KEY`~~ | ~~Unique identifier.~~ |
| ~~`bundle_id`~~ | ~~`TEXT`~~ | ~~`UNIQUE NOT NULL`~~ | ~~macOS bundle identifier (e.g., `com.apple.Safari`).~~ |
| ~~`display_name`~~ | ~~`TEXT`~~ | ~~`NOT NULL`~~ | ~~Human-readable name (e.g., `Safari`).~~ |
| ~~`category`~~ | ~~`TEXT`~~ | ~~`DEFAULT 'Uncategorized'`~~ | ~~Future-use: Coding, Social, Productivity, etc.~~ |
| ~~`created_at`~~ | ~~`TIMESTAMPTZ`~~ | ~~`DEFAULT NOW()`~~ | ~~When this app was first seen by the system.~~ |

**Deferred to post-V1.** Not implemented. The flat schema (app_name + bundle_id on each session row) is sufficient until we need per-app metadata like `category`. When the time comes, this table design is still valid — just needs a migration script to extract existing data.

### Table: `app_sessions`
Stores the actual usage timeline. A new row is created whenever the app **or** the window title changes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | Session identifier. |
| ~~`app_id`~~ | ~~`INT`~~ | ~~`REFERENCES applications(id)`~~ | ~~Link to the parent application.~~ |
| `app_name` | `TEXT` | `NOT NULL` | **Implemented instead of `app_id`.** Display name stored directly on the session. |
| `bundle_id` | `TEXT` | | **Implemented instead of `app_id`.** Bundle identifier stored directly on the session. |
| `window_title` | `TEXT` | | The specific file, tab, or document title. |
| ~~`started_at`~~ | ~~`TIMESTAMPTZ`~~ | ~~`NOT NULL DEFAULT NOW()`~~ | ~~Start of the session.~~ |
| `started_at` | `TIMESTAMPTZ` | `NOT NULL` | Start of the session. **No `DEFAULT NOW()` — the client sends the timestamp.** This is correct because the event time is when the switch happened on the Mac, not when the server received it. If we add event buffering later, `DEFAULT NOW()` would produce wildly wrong timestamps. |
| `ended_at` | `TIMESTAMPTZ` | | End of the session (`NULL` if active). |
| ~~`duration_seconds`~~ | ~~`INT`~~ | ~~`GENERATED ALWAYS AS...`~~ | ~~Computed duration (PostgreSQL 12+).~~ |
| `duration_seconds` | `INT` | `GENERATED ALWAYS AS (EXTRACT(EPOCH FROM (ended_at - started_at))::INT) STORED` | Computed duration. **Added the `::INT` cast** that the original research omitted — without it, `EXTRACT(EPOCH ...)` returns `FLOAT8`, not `INT`. |

#### Constraints & Indices
- **Check Constraint:** `CHECK (ended_at IS NULL OR ended_at >= started_at)` ensures data integrity. **Implemented.**
- **Active Session Index:** `CREATE INDEX idx_sessions_active ON app_sessions (started_at) WHERE (ended_at IS NULL);` — optimized for finding the current session to close. **Implemented.**
- **Timeline Index:** `CREATE INDEX idx_sessions_range ON app_sessions (started_at, ended_at);` — optimized for "Today's Stats" queries. **Implemented.**

---

## 3. Key Logic Decisions

### 3.1 Handling "Idle" Time
- ~~**Decision:** Use a **System Entry** approach.~~
- ~~**Implementation:** When the Swift daemon detects idleness, it will send an event with `bundle_id: "com.apple.system.idle"`.~~
- ~~**Reasoning:** Easier to query than "gaps." To find productive time, we simply `SUM` sessions where `bundle_id != 'com.apple.system.idle'`.~~

**Deferred — out of scope for V1** (PRD Section 4 explicitly excludes idle detection). The synthetic-entry approach is sound in principle but has unresolved gaps:

1. **Who sends the idle event?** The Swift daemon would need to poll `CGEventSource.secondsSinceLastEventType` on a timer. This is fundamentally different from app-switch detection (which is event-driven). The research doesn't address the polling interval tradeoff — too frequent hurts battery, too infrequent misses short idle periods.
2. **What closes the idle session?** When the user returns, the daemon gets a `didActivateApplicationNotification`. The backend needs to close the idle session AND open the real app session atomically — that's two writes in one event. The research doesn't cover this two-step flow.
3. **Threshold ambiguity:** What counts as "idle"? 30 seconds? 5 minutes? This is a user preference, not a schema decision. The schema supports it fine either way.

### 3.2 Window Title Tracking
- **Decision:** Each window title change creates a **new session**.
- **Implementation:**
    1. Close current session (`ended_at = NOW`).
    2. Insert new session with same ~~`app_id`~~ `app_name`/`bundle_id` but updated `window_title`.
- **Benefit:** Allows for "Deep Work" analysis (e.g., "How long was I actually in `MainController.java` vs just having IntelliJ open?").

**Implementation Note:** The design is correct but the research is missing a critical concern: **debouncing**. Window titles change at very high frequency — a browser fires title changes as tabs load, autocomplete populates, page titles update. Without a minimum-duration threshold (e.g., ignore sessions < 2 seconds) or coalescing rapid changes, the database will bloat with sub-second noise rows. This must be addressed when window title tracking is actually implemented (requires Accessibility API permissions, deferred to post-V1).

### 3.3 The "Singleton" Focus
- **Decision:** Only **one** session can be active at a time.
- **Logic:** Even with multiple monitors, macOS only assigns "Key Focus" to one window. The Java backend will enforce that only one row has `ended_at IS NULL` at any given time.

**Implementation Note:** Correct, but the research is missing three edge cases that Phase 5 must handle:

1. **Crash recovery:** If the server crashes, there's an orphaned session with `ended_at IS NULL`. On restart, the backend should detect and close stale sessions (e.g., any active session older than a configurable threshold).
2. **Duplicate events / idempotency:** If the Swift daemon retries a failed HTTP POST, the backend shouldn't create a duplicate session. Consider deduplicating on `(bundle_id, started_at)` or using a client-generated event ID.
3. **Rapid switches / concurrency:** Two app switches in quick succession could produce near-simultaneous requests. The `@Transactional` annotation handles this via row-level locking, but this should be tested explicitly under load.

---

## 4. SQL Implementation Script

~~```sql~~
~~-- Step 1: Create Applications Table~~
~~CREATE TABLE applications (~~
~~    id SERIAL PRIMARY KEY,~~
~~    bundle_id TEXT UNIQUE NOT NULL,~~
~~    display_name TEXT NOT NULL,~~
~~    category TEXT DEFAULT 'Uncategorized',~~
~~    created_at TIMESTAMPTZ DEFAULT NOW()~~
~~);~~
~~```~~

**`applications` table deferred to post-V1.**

### Implemented Schema (Current)

```sql
CREATE TABLE IF NOT EXISTS app_sessions (
    id              BIGSERIAL PRIMARY KEY,
    app_name        TEXT NOT NULL,
    bundle_id       TEXT,
    window_title    TEXT,
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    duration_seconds INT GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (ended_at - started_at))::INT
    ) STORED,

    CONSTRAINT check_dates CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE INDEX IF NOT EXISTS idx_sessions_active ON app_sessions (started_at) WHERE (ended_at IS NULL);
CREATE INDEX IF NOT EXISTS idx_sessions_range ON app_sessions (started_at, ended_at);
```

### Key Differences from Original Proposal

| Aspect | Research Proposed | Implemented | Reason |
|---|---|---|---|
| `applications` table | Normalized FK | Flat (app_name + bundle_id on session) | Simpler writes, no JOINs needed yet. Migrate when categorization is added. |
| `id` type | `BIGSERIAL` | `BIGSERIAL` | Adopted as-is. Best practice for high-write tables. |
| `started_at` default | `DEFAULT NOW()` | No default | Client timestamp is authoritative. Server-side `NOW()` would drift with network delay or buffered events. |
| `duration_seconds` cast | `EXTRACT(EPOCH ...)` (returns FLOAT8) | `EXTRACT(...)::INT` | Explicit cast to INT. Research omitted this, which would store a float. |
| Check constraint | Proposed | Implemented | Direct adoption. |
| Indices | Proposed | Implemented | Direct adoption (both active-session partial index and range index). |
| ORM layer | Assumed JPA/Hibernate | Spring Data JDBC | Project uses `spring-boot-starter-data-jdbc`, not JPA. Annotations are `@Table`/`@Id` from `org.springframework.data`, not `javax.persistence`. |

---

## 5. Missing Considerations (Not Addressed in Original Research)

These items were absent from the research and should be addressed in future phases:

1. **Timezone handling:** The schema uses `TIMESTAMPTZ` (good), but the end-to-end chain should be documented: Swift daemon sends ISO 8601 UTC strings, Java parses with `Instant.parse()`, PostgreSQL stores with timezone. Everything stays in UTC. Display-layer conversion is a frontend concern.

2. **Retention / archival:** At ~1,200 rows/day (switching every 30 seconds for 10 hours), that's ~438K rows/year. After a few years, queries will slow. Consider table partitioning by month (`PARTITION BY RANGE (started_at)`) or an archival job that moves old data to a summary table.

3. **Migration strategy:** The research proposes a target schema but doesn't discuss how to evolve from the current flat table to the normalized version. Flyway or Liquibase should be introduced before the next schema change to make migrations repeatable and versioned.

4. **Event buffering (PRD Open Question):** If the Swift daemon buffers events when the server is down, events arrive out of order with past timestamps. The session-close logic must handle `started_at` values that are older than the current active session's `started_at`. The schema supports this (no ordering constraints), but the application logic needs to be designed for it.

5. **Multi-user support (PRD Open Question):** The current schema is implicitly single-user. Adding a `user_id` column later is trivial at the schema level, but the singleton-focus invariant ("one active session") becomes "one active session per user," which changes the close-session query.
