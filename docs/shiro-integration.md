# Personale × Shiro — Desktop Companion Integration

> Status: design doc / proposal. Shiro is a separate project at
> `~/Documents/Abhinav/Code/shiro` (public: github.com/AbhinavGupta-de/shiro).
> This doc lives in Personale because the integration is driven *from* Personale's
> activity signal.

## TL;DR

**Personale already knows exactly what you're doing all day. Shiro is a cute
desktop pet that has no idea what you're doing.** Wire them together and Shiro
stops being a random animation loop and becomes a living reflection of your work
day — heads-down while you code, restless when you're context-switching too much,
asleep when you walk away, celebrating when you hit your daily target.

Personale = the senses + brain. Shiro = the face.

---

## What each side is

### Shiro (the pet)
A native macOS desktop companion (AppKit `NSPanel`) that survives yabai, floats
over all spaces/fullscreen apps, and animates anime-style sprite packs (Shiro the
dog, Kazama, any converted Shimeji). It already has:

- A **life-cycle phase model**: `sleeping` / `idle` / `active`, currently chosen
  from raw macOS keyboard/mouse idle time + clock.
- An **event-reaction channel**: an MCP HTTP server on `127.0.0.1:47655` and a
  watched state file `/tmp/shiro-state.json`. Anything that writes a reaction there
  (currently `/notify-user`, Claude Code hooks) makes the pet react — Jump, Run,
  Sit, Sleep, etc.
- Pack-agnostic behavior: every pose pool is filtered against the loaded pack, so
  new characters inherit the whole life-cycle for free.

The reaction vocabulary today: `alert`, `celebrate`, `working`, `resting`,
`charging`, `low-energy`, `wake`, plus `play:<ActionName>` for a specific pose.

### Personale (the tracker)
Local-first Rize-style tracker. Backend on `:8696` already exposes (among others):

- `GET /api/stats/today` — time-per-app today
- `GET /api/stats/categories?date=` — time by category (Code, Design, Communication, Media, Browsing, Other)
- `GET /api/stats/timeline?date=` — merged session blocks
- `GET /api/stats/context-switches?date=` — how scattered the day is
- `GET /api/stats/workblocks?date=` — sustained focus blocks
- `GET /api/stats/interruptors?date=` — what keeps breaking your focus
- `POST /api/events` — fired by the macOS app on every app switch (the real-time pulse)

The macOS menu-bar app knows the **current foreground app + category in real
time** — that live signal is the gold the integration needs.

---

## Why they're a perfect match

Shiro's weakest input today is *knowing what you're actually doing*. It guesses
from "are keys being pressed." Personale already has the answer, categorized and
debounced. Feeding Personale's signal into Shiro turns a generic idle loop into a
genuine companion that behaves like it shares your day.

---

## Integration architecture

Three ways for Personale to drive Shiro, easiest first. All are local-only,
no cloud, matching both projects' local-first stance.

### Option A — Personale writes a status file (recommended, lowest effort)
The Personale macOS app already computes the current category. Have it also write:

```jsonc
// ~/.personale/status.json   (atomic, in-place write)
{
  "category": "Code",          // current foreground category
  "app": "Xcode",
  "state": "focused",          // focused | scattered | break | idle | away
  "focusMinutes": 47,          // length of current focus block
  "contextSwitchesLastHour": 4,
  "dailyTargetPct": 0.82,      // progress toward daily goal
  "updatedAt": 1748450000.0
}
```

Shiro already watches files the exact same way it watches `/tmp/shiro-state.json`
(a `DispatchSource` FSEvents watcher). Adding `~/.personale/status.json` is ~20
lines in `PetController`. **Personale owns the mapping of raw activity → state;
Shiro just reacts.**

### Option B — Personale POSTs to Shiro's MCP server
On every meaningful change, Personale fires:

```bash
curl -s --max-time 0.5 -X POST http://127.0.0.1:47655/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call",
       "params":{"name":"set_reaction","arguments":{"reaction":"working","ttlSeconds":300}}}' || true
```

No new contract — Shiro's MCP surface already accepts this. Good for event-style
nudges (target hit, too many context switches) rather than continuous state.

### Option C — Shiro polls Personale's API
Shiro hits `GET /api/stats/today` + a small new `GET /api/activity/current` every
~30s and maps the result itself. Most decoupled, but puts the mapping logic in
Shiro and needs Personale to add a "current activity" endpoint (it has the data;
there's no single live GET yet — the app POSTs events instead).

**Recommendation:** Option A for continuous state (it's the cheapest and keeps the
"Personale decides, Shiro emotes" split clean), plus Option B for one-off
celebrations/alerts.

---

## The cool features this unlocks

### Mirror your focus (continuous)
| Personale signal | Shiro behaviour |
|---|---|
| Sustained `Code`/`Design` focus block (>15 min) | calm, heads-down — sits quietly, minimal movement, doesn't distract |
| `Communication`/`Browsing` | more awake/alert — looks up, watches cursor |
| `Media` (long) | relaxed — lies down, lazy idle |
| No foreground activity / idle > threshold | **sleeps** (real "away" signal, not a guess) |
| You're active at 3am | stays awake with you — all-nighter mode, maybe a tired/droopy pose |

### React to your patterns (events)
- **Hit your daily target** (`dailyTargetPct >= 1.0`) → Shiro celebrates (Jump/TailWag) once.
- **Context-switch storm** (`contextSwitchesLastHour` high) → Shiro looks restless/dizzy — a gentle visual nudge that you're scattered.
- **Long unbroken focus** (e.g. 90 min, no break) → Shiro does a stretch/yawn — a Pomodoro-ish "take a break" cue without a nagging notification.
- **Start of a workblock** → Shiro settles into "working alongside you" mode.
- **First activity after a long away** → Shiro wakes, stretches, greets (Wave).

### Pet life-cycle tied to *your* life-cycle
This is the "full lifecycle proper pet" idea: Shiro's energy mirrors yours.

- **Morning / start of work day** (Personale work-day start hour) → wakes, fresh.
- **Deep work** → focused/quiet.
- **Overwork** (focus block running for hours, no break) → tired/sick pose; a soft signal you're grinding too hard.
- **Evening wind-down / day target met** → relaxed, content.
- **You leave** → sleeps.

Because it's pack-agnostic, this applies to **any** entity you load — Shiro the
dog, Kazama, a future waifu pack — each just needs the relevant poses.

---

## Sprite poses this needs (generate per character)

Locomotion is already covered. The integration wants these *emotional/state*
poses (4–8 frames, 128×128, transparent, bottom-center anchor, named exactly):

| Pose | Driven by |
|---|---|
| `Sleep` (eyes closed, Zzz) | away / deep night |
| `Wake` / `Yawn` / `Stretch` | first activity after away; long-focus break cue |
| `Focused` (heads-down, still) | sustained Code/Design block |
| `Happy` / `TailWag` | daily target hit, celebrate |
| `Dizzy` / `Restless` | context-switch storm |
| `Tired` / `Droop` | overwork / all-nighter |
| `Curious` / `LookUp` | incoming notification, category change |
| `Eat` | (optional) future feed-interaction loop |

Shiro's converter + phase pools pick these up automatically once named.

---

## Proposed contract (if we go Option A)

Personale writes `~/.personale/status.json` on every state change (debounced to
~once per 10–30s). Field semantics are Personale's to define; Shiro maps them:

```
category            -> tunes idle calmness (Code=quiet, Comms=alert, Media=lazy)
state               -> focused|scattered|break|idle|away → pet phase
focusMinutes        -> overwork detection (stretch/tired cues)
contextSwitchesLastHour -> restless/dizzy reaction
dailyTargetPct      -> celebrate on crossing 1.0
updatedAt           -> dedupe / freshness
```

Shiro side: add a second FSEvents watcher in `PetController` for this file and a
`mapPersonaleState(_:) -> Phase/Reaction` function (~20 lines). Personale side:
one writer that serializes the current tracker state to the file.

---

## Open questions

1. **Who owns the activity→state mapping?** Proposal: Personale (it has the
   context). Shiro stays a dumb emoter.
2. **Push or pull?** Proposal: push via status file (Option A) for continuous
   state; MCP POST (Option B) for discrete celebrations.
3. **Does Personale's macOS app already have a single place where it knows the
   current category live?** If yes, the writer is trivial. If the category is only
   computed server-side, we either add a tiny live endpoint or compute it in the app.
4. **Privacy:** everything stays local (both apps are local-first). The status
   file holds only coarse category/state, never window titles or URLs.
