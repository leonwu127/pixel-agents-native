# Pixel Agents Lua — MVP Design

**Date**: 2026-04-20
**Status**: Approved (brainstorm complete, awaiting user sign-off before planning phase)
**Branch**: `pixel-agents-lua`
**Location**: `/pixel-agents-lua/` subdirectory in current repo (monorepo)

---

## 1. Context & Goals

### 1.1 What we're building

A Love2D + Lua desktop application that visualizes running AI agents as pixel-art characters in an office. Inspired by `pixel-agents-native` (the VS Code extension in this same repo), but **completely independent of VS Code** — runs as a standalone Love2D executable.

### 1.2 Why

- `pixel-agents-native` is tightly coupled to VS Code. The vision (per its README) is "agent-agnostic, platform-agnostic." A Lua/Love2D port is a step toward that, scoped to a single platform to stay small.
- User has prior Love2D + Lua experience, so tool choice is ergonomic.
- Decouples agent visualization from any specific IDE host.

### 1.3 What "MVP" means here

A version where, starting from an empty window, the user can open a PowerShell window, run `claude --session-id <uuid>`, and within ~1 second see a pixel character appear in the office and react to Claude's activity in real time.

### 1.4 Core experience (product positioning)

**Pure visualizer.** No game mechanics, no player actions that affect agents. One Claude Code session → one character on screen. Characters walk to desks, animate based on what the agent is doing (typing / reading), and show speech bubbles when waiting or asking for permission.

Explicitly not a game, not a Tamagotchi, not a sim. Those are deferred indefinitely.

---

## 2. Scope

### 2.1 In scope (MVP Must)

1. Multi-agent concurrency — one character per live Claude Code session
2. Basic animations — idle / walk / typing / reading, switched by tool type
3. Seats — each character walks to an assigned desk
4. Speech bubbles — waiting (green check) and permission (amber "...")
5. Static office layout loaded from a Lua config file
6. Camera — fixed view with mouse-drag pan

### 2.2 Explicitly deferred (in BACKLOG.md)

- Hooks-mode input (MVP uses file polling only)
- Layout editor (users hand-edit Lua config)
- Sub-agent (Task tool) visualization
- Sound notifications
- Selection / seat reassignment
- Diverse palettes (6 skins + hue shift)
- Matrix spawn/despawn effect
- External asset directories
- Cross-window sync
- Tool status tooltip overlay
- CI / automated visual regression

### 2.3 Non-goals

- Supporting Codex/OpenCode in MVP (architecturally possible via Provider interface, but not implemented)
- WSL2, macOS, or Linux-native support in MVP (**Windows 11 native only** — per D10)
- Packaging as `.love` / exe for distribution (dev-mode only — `love .`)

---

## 3. Decisions Log

| # | Decision | Rationale |
|---|---|---|
| D1 | Pure visualizer (option A of 4) | User confirmed minimal scope; any game mechanics out of scope |
| D2 | Claude Code only in MVP, Provider interface pre-built for future providers | Balance fastest MVP with clean extensibility |
| D3 | File polling only in MVP; hooks deferred | Love2D poor at HTTP servers; polling is zero-dep; latency acceptable for a visualizer |
| D4 | Borrow all PNG assets from `pixel-agents-native` | Fastest path to visual parity; character asset license review deferred to pre-distribution |
| D5 | MVP v0 uses a simplified Lua layout format, not the original's full `default-layout.json` schema | Original schema (rotation groups, state groups, wall bitmask, per-tile color, surface placement, background rows) is far too complex for MVP |
| D6 | Passive watcher model — user spawns Claude from their own terminals | Love2D cannot reliably spawn terminal emulators cross-platform; original had VS Code Terminal API as crutch |
| D7 | ~~WSL2 on Windows 11 only for MVP~~ **Superseded by D10 on 2026-04-21** | Original rationale (cross-filesystem avoidance) was cautious; user reversed to simplify integration with native Claude CLI |
| D8 | Subdirectory `/pixel-agents-lua/` in current repo (not sibling repo) | Faster iteration, easy asset reuse; `git subtree split` later if independent repo needed |
| D9 | Love2D-idiomatic architecture (route 2 of 3): scenes + systems + `love.thread` for IO | Leverages Love2D strengths, avoids TS-to-Lua transliteration pitfalls |
| D10 | **Windows native on Windows 11** (replaces D7) | User's actual dev environment; Claude CLI runs natively; no WSL mount friction; JSONL at `%USERPROFILE%\.claude\projects\`; path separators need awareness (LuaJIT accepts both `/` and `\`) |
| D11 | **Vertical slicing** (S1→S4): each slice produces a runnable demo, later slices evolve from earlier ones without rewrites | Replaces the original horizontal Phase 0→3 (scaffold → pure-logic → love2d-integrate → polish). Value shows up early; faster feedback; fewer dead-end refactors |
| D12 | **Pure-Lua test harness** (`spec/helper.lua`, ~60 lines, busted-compatible `describe`/`it`/`assert.are.equal` API) | LuaRocks' `busted` pulls in `luasystem` which needs MSVC/gcc to build on Windows; we have neither and installing MSVC Build Tools is disproportionate for an MVP visualizer. The harness uses zero C deps, runs on bare `luajit.exe`, and matches busted API 1:1 so we can swap in real busted later with no spec changes |

---

## 4. Architecture

### 4.1 Layering

```
Love2D runtime (main.lua)
   └─ love.load / love.update(dt) / love.draw
         │
         ▼
   Scene: Office (scenes/office.lua)
         │
         ├───────────┬────────────┬────────────┬───────────┐
         ▼           ▼            ▼            ▼           ▼
      World       Entities     Systems      Provider   Renderer
      (state)    (Character)   (watcher,    (claude    (sprites,
                               parser,      impls      z-sort,
                               pathfind)    contract)  overlay)
                                  │            │
                                  │  love.thread
                                  └── for poll ┘
```

### 4.2 Core principles

1. **Single main scene** for MVP (`scenes/office.lua`). Scene manager added only if more scenes appear.
2. **Central World state** (`src/world.lua`) — plain Lua table, not OOP class. Holds characters, seats, layout, event queue.
3. **Provider interface decouples agent specifics** — `providers/claude.lua` implements a contract defined in `src/provider.lua`. Adding Codex/OpenCode later = new file.
4. **Systems as pure functions** — `watcher.update(world, dt)`, `pathfinder.findPath(world, from, to)`. Testable without Love2D.
5. **File IO on a background thread** — `love.thread` runs the polling loop, pushes raw events through a channel. Main loop never blocks on disk.

### 4.3 Tick loop

```
love.update(dt):
  1. Drain love.thread.channel → list of raw JSONL lines
  2. For each line: provider.normalize(line) → AgentEvent | nil
  3. world.apply(AgentEvent) for each event
  4. For each character: character.update(dt, world)
  5. camera.update(dt)

love.draw():
  renderer.render(world, camera)
```

### 4.4 Runtime dependencies

- **Love2D 11.5** (bundles LuaJIT 2.1, which is Lua 5.1 compatible) — installed via `winget install Love2d.Love2d`
- **LuaJIT 2.1** + **LuaRocks 3.11** — installed via `winget install DEVCOM.LuaJIT` at `%LOCALAPPDATA%\Programs\LuaJIT\bin\`. Used for running tests (and any `luajit` scripting) outside Love2D.
- `json.lua` (rxi/json.lua, vendored at `src/vendor/json.lua`) — pure Lua, no C ext
- **Directory scanning**: `love.filesystem.mountFullPath` + `getDirectoryItems` (Love2D 11.0+ API). Avoids the `luafilesystem` C extension, which would require MSVC/gcc to build.
- **Tests**: pure-Lua `spec/helper.lua` shim (`describe`/`it`/`assert.are.equal`) — per D12. Runner: `luajit spec\<name>_spec.lua`.

---

## 5. Components

### 5.1 Module map

| Module | Does | Does NOT |
|---|---|---|
| `main.lua` | Thin Love2D callback shell | Any business logic |
| `conf.lua` | Love2D window + module config | Runtime logic |
| `src/scenes/office.lua` | The single MVP scene; owns world; dispatches events to systems | Own state beyond scene lifecycle |
| `src/world.lua` | Holds `characters[]`, `seats[]`, `layout`, `events[]`. API: `apply(event)`, `addCharacter(sessionId, meta)`, `getCharacter(sessionId)` | Render, IO, path calc |
| `src/entities/character.lua` | Per-character state + FSM + animation frame. API: `update(dt, world)`, `setState(s)`, `setBubble(type)`, `walkTo(seatId)` | Know about JSONL / providers |
| `src/systems/watcher.lua` | Pure polling logic: `scanOnce(dirs, state) → { newLines, updatedState }`. Testable without Love2D. Maintains per-file offset + `lineBuffer` | JSON parsing, event shaping, threading |
| `src/systems/watcher_thread.lua` | Love2D thread entry point. Loops `watcher.scanOnce` every 500ms, pushes raw lines via `love.thread.Channel` | Polling algorithm itself (delegates to `watcher.lua`) |
| `src/systems/parser.lua` | `parseLine(rawLine) → { kind, payload }`. Handles `assistant`/`user`/`system`/`progress` records | Character state, IO |
| `src/provider.lua` | Defines Provider contract; factory `provider.create(id)` | Any agent-specific logic |
| `src/providers/claude.lua` | Implements Provider for Claude Code. Ports `transcriptParser.ts` logic | Hooks-mode (deferred) |
| `src/systems/pathfinder.lua` | BFS on layout grid. API: `findPath(blocked, from, to) → {tiles} \| nil` | Animation |
| `src/systems/renderer.lua` | `render(world, camera)`. Floor → walls → furniture → characters (z-sort by y) → bubbles. Uses `love.graphics.setDefaultFilter("nearest")` | Mutate world |
| `src/layout/loader.lua` | Load MVP v0 Lua layout files. Required fields: `size`, `door` (single tile coord), `seats[]`, `furniture[]`. Produces `world.layout` with `tileMap`, `blocked[]`, `seats[]`, `door` | Parse original `default-layout.json` (deferred) |
| `src/layout/types.lua` | Layout Lua type shapes (documentation-style) | Runtime behavior |
| `src/assets.lua` | One-shot load of all PNG → `love.graphics.Image` map keyed by `[id][direction][frame]` | Lazy/dynamic loading |
| `src/camera.lua` | `update(dt)`, `apply(world) → transform`, drag-pan, wheel-zoom (integer multiples) | Follow characters (deferred) |
| `src/config.lua` | Read `~/.pixel-agents-lua/config.lua` (MVP field: `layoutFile`). Falls back to default | Watch config for changes |
| `src/assert.lua` | `assertf(cond, fmt, ...)` helper | — |

### 5.2 Provider contract

```lua
-- src/provider.lua declares
local Provider = {
  id = "string — unique identifier, e.g. 'claude'",
  displayName = "string — human name, e.g. 'Claude Code'",
  sessionDirs = function() end,         -- returns { path1, path2, ... }
  sessionFilePattern = "string glob",   -- e.g. "*.jsonl"
  normalize = function(rawLine) end,    -- returns AgentEvent | nil
  formatToolStatus = function(name, input) end,  -- returns display string
  permissionExemptTools = {Read=true, ...},      -- set as a table of booleans
}
```

### 5.3 AgentEvent shape (normalized across providers)

```lua
{
  kind        = "session_discovered" | "tool_start" | "tool_end" | "turn_end" | "permission_timeout" | "session_cleared",
  sessionId   = "string",
  toolId      = "string | nil",
  toolName    = "string | nil",   -- normalized: "Read", "Write", etc.
  toolStatus  = "string | nil",   -- human-readable like "Reading foo.ts"
  payload     = { ... },          -- provider-specific extras if needed
}
```

---

## 6. Data Flow

### 6.1 Cold boot

```
love.load()
  ├─ assets.loadAll()
  ├─ layout = layout.loader.load("layouts/mvp_v0.lua")
  ├─ world = World.new(layout)
  ├─ provider = provider.create("claude")
  ├─ thread = love.thread.newThread("src/systems/watcher_thread.lua")
  │     thread:start(provider.sessionDirs(), provider.sessionFilePattern, startMtime)
  │     channel = love.thread.getChannel("agent_events")
  └─ scene = Office.new(world, provider, channel)
```

**No history replay.** Watcher records start-time mtime and only reports files newer than that, or new lines in pre-existing files. Pre-boot completed sessions are not rendered — avoids boot-time character flood.

### 6.2 New agent appears

```
User (PowerShell): claude --session-id abc-123
  → Claude creates ~/.claude/projects/<hash>/abc-123.jsonl
  → watcher thread (500ms poll) notices new file
  → push { kind = "session_discovered", sessionId = "abc-123", filePath = "..." }
Main thread scene:update picks it up:
  → world.addCharacter("abc-123", meta)
  → character spawns at the `door` tile (declared in layout file)
  → seat = first element of layout.seats[] with no occupant (deterministic order)
  → if seat found: pathfinder.findPath → character.state = "walk"
  → if no seat found: character.state = "idle" at door
```

**Seat freed recheck**: whenever `world.removeCharacter(sessionId)` runs (on stale-session despawn or `/clear`), iterate idle-at-door characters in FIFO order and try to assign the newly-freed seat. This is the only way an idle-at-door character gets a seat; there's no periodic poll.

### 6.3 Tool invocation → animation

```
Claude runs Read → JSONL appends `assistant` record with tool_use block
  → watcher emits raw line
  → parser.parseLine → { kind = "tool_start", sessionId, toolId, toolName = "Read" }
  → provider.formatToolStatus("Read", input) → "Reading main.lua"
  → world.apply(event)
      character.state = "read"
      character.toolName = "Reading main.lua"
  → next frame: renderer picks read-animation frames
```

Tool → state map (ported from original):
- `Write | Edit | Bash | Task` → `type`
- `Read | Grep | Glob | WebFetch` → `read`
- otherwise → keep current state

Animation frames step on `ANIM_INTERVAL_MS` = 200ms, driven by `character:update(dt)`.

### 6.4 Turn end → waiting bubble

Claude emits `system` record with `subtype = "turn_duration"`:
```
parser recognizes → world.apply({ kind = "turn_end", sessionId })
  → character.state = "idle"
  → character.bubble = "waiting"  -- green check
  → 2-second fade countdown in character:update
```

**Text-only turns don't emit `turn_duration`** (inherited pitfall). Fallback: `TEXT_IDLE_DELAY_MS = 5s`. Any new JSONL line resets the countdown. If 5s elapse with no new line and no tool was used this turn, manually synthesize `turn_end`.

### 6.5 Permission waiting bubble

For non-exempt tools (Bash, Edit, etc. — anything outside `permissionExemptTools`):
- Start `PERMISSION_TIMER_MS = 7s` bound to `toolId`
- Any `tool_result` / `progress` matching `toolId` cancels it
- Timeout → `character.bubble = "permission"` (amber "...")
- On `tool_result` arrival → clear bubble

### 6.6 `/clear` detection

Claude's `/clear` command creates a **new JSONL file**; old file stops getting writes. MVP detection:
- Watcher notices silence (≥ 3s no new lines) on a known session while a new `.jsonl` appears under same project hash → treat as cleared
- Old character remains seated until `STALE_SESSION_TIMEOUT_MS = 60s` of zero activity → fades out
- New JSONL triggers flow 6.2 (new agent)

Original project has content-scanning + multiple dismissal systems. MVP relies on timeouts only; false positives go to BACKLOG.

### 6.7 Shutdown

```
love.quit()
  ├─ scene:close()     -- clean up coroutines / animations
  ├─ thread:release()  -- graceful watcher termination
  └─ return false      -- allow close
```

No persistence. MVP does not remember which session sat at which seat across runs.

---

## 7. Error Handling

Principle: **recoverable errors are logged and swallowed; structural errors crash early.**

| Scenario | Strategy | Reason |
|---|---|---|
| JSONL line parse fails | `pcall`, `print` warning with file+line, continue | One bad line shouldn't kill the watcher |
| JSONL read mid-write (truncated line) | Hold in `lineBuffer`, retry next tick | Expected path, not an error |
| Provider id not found | Crash at `love.load` with clear error | Config mistake; fail loud |
| Layout file missing / malformed | Crash at load with clear error | Can't run without layout |
| Missing asset PNG | Crash at load, name the missing file | Early and visible |
| Watcher thread crashes | Main checks `thread:getError()` per tick, shows error overlay and halts IO | Silent failure would look like a hang |
| Character pathfinding fails | Character stays put, log warning | Layout mistake, not fatal |
| `~/.claude/projects/` doesn't exist | No crash; UI shows "Waiting for Claude sessions..." | Normal for a new user |
| Love2D internal error | Default `love.errorhandler` | Standard Love2D behavior |

### 7.1 Logging

- `print()` only; Love2D console captures it
- Format: `[level] [module] message` (e.g. `[warn] [parser] bad json at projects/xyz/abc.jsonl:152`)
- No log file. Use `love . 2>&1 | tee out.log` if needed.

### 7.2 Assertions

`src/assert.lua::assertf(cond, fmt, ...)` for developer-facing invariants: non-empty session IDs, valid seat IDs, registered providers. Active in MVP (no strip flag).

---

## 8. Testing

Love2D testing splits cleanly because most modules are pure Lua.

### 8.1 Covered by unit tests (MVP required)

Framework: **pure-Lua busted-compatible shim** in `spec/helper.lua` (per D12). Each spec is self-executing:
`luajit spec\parser_spec.lua`. Batch: `scripts\test.bat` runs every `spec\*_spec.lua`. No Love2D required.

| Module | What to test | Coverage target |
|---|---|---|
| `src/systems/parser.lua` | All JSONL record shapes: `tool_use`, `tool_result`, `turn_duration`, `agent_progress`; string vs array `content` | ≥ 80% lines |
| `src/providers/claude.lua` | `normalize` mapping, `formatToolStatus` strings, exempt-tools set | ≥ 70% lines |
| `src/systems/pathfinder.lua` | BFS edge cases: start=end, blocked start, blocked end, unreachable, U-shaped obstacle | — |
| `src/world.lua` | `addCharacter`, `apply(event)` state transitions for all event kinds, permission timeout | — |
| `src/layout/loader.lua` | Valid layout loads; bad field → raises | — |

### 8.2 Not tested in MVP

- `src/entities/character.lua` animation stepping — pure but low-value; visual check is faster
- `src/camera.lua` — ditto
- `src/systems/renderer.lua` — canvas output, no visual-diff infra
- `src/assets.lua` — thin wrapper
- `main.lua` — thin shell

### 8.3 Integration smoke test

`spec/integration/e2e_smoke_spec.lua` — pure Lua (no Love2D):
1. Set up a fake JSONL directory with pre-baked records
2. Call `watcher.scanOnce(dir, state)` once (polling logic extracted as pure function)
3. Feed emitted raw lines through `parser.parseLine` and `world.apply`
4. Assert `world` has the expected character with `state = "idle"` and `bubble = "waiting"`

### 8.4 Manual test checklist

`wiki/pixel-agents-lua/manual-test-checklist.md` (written during implementation):
- [ ] Cold boot → empty office
- [ ] `claude --session-id test-1` → character walks door → seat
- [ ] Read → read animation
- [ ] Write → type animation
- [ ] Turn end → green check bubble, fades in 2s
- [ ] Bash (non-exempt) → amber "..." after 7s
- [ ] Permission granted → bubble clears
- [ ] Second session → second character
- [ ] `/clear` → old character fades, new spawns
- [ ] Ctrl+C → clean exit (no hanging thread)

### 8.5 Not doing

- Visual regression (pixel diff) — maintenance > value during MVP churn
- Performance benchmarks — Love2D's FPS overlay is enough
- CI — local `luajit spec\*_spec.lua` sufficient; deferred to BACKLOG

---

## 9. Open Questions

None blocking. Items deferred to implementation:

- Exact tuning of `ANIM_INTERVAL_MS` (200ms), `PERMISSION_TIMER_MS` (7s), `TEXT_IDLE_DELAY_MS` (5s), `BUBBLE_FADE_MS` (2s), `STALE_SESSION_TIMEOUT_MS` (60s) — starting values anchored at original project; tune during manual testing
- Seat-assignment policy beyond "first in layout declaration order with no occupant" — YAGNI for MVP
- MVP v0 layout's specific furniture / seat / door-tile coordinates — authored during implementation, not design
- `project-hash` computation: original uses workspace path with `:`, `\`, `/` → `-`. Port directly; confirm matches Claude CLI's actual hashing during first integration test

---

## 10. Related Files

- `wiki/pixel-agents-lua/BACKLOG.md` — deferred work items (hooks upgrade, legal review of character assets, cross-platform support, P2/P3 features)
- Original reference: `CLAUDE.md` — compressed reference for `pixel-agents-native` (VS Code extension), used as source for JSONL parsing conventions, tool→animation mapping, and timing constants

---

## 11. Implementation structure

**Approved 2026-04-21**: vertical slicing (D11) — each slice ships a demoable prototype and later slices evolve from earlier ones.

| Slice | Deliverable (demo) | Introduces |
|-------|--------------------|-----------|
| **S1 — Hello Office** | `love pixel-agents-lua` opens a window and renders a static office with one hardcoded character at a fixed tile. No input, no animation. | `conf.lua`, `main.lua`, `assets.lua`, `renderer.lua`, minimal `layout/loader.lua`, `layouts/mvp_v0.lua`, pure-Lua test harness |
| **S2 — Walk on demand** | Press Space → character walks from door to an empty seat with walk animation. | `pathfinder.lua`, `character.lua` FSM (idle/walk), minimal `world.lua` |
| **S3 — Fake JSONL drives it** | Manually appending to a local fake `.jsonl` file triggers character to walk/animate and show a waiting bubble. | `parser.lua`, `provider.lua`, `providers/claude.lua`, `watcher.lua`, `watcher_thread.lua`, full `world.lua` FSM |
| **S4 — Real Claude + polish** | `claude --session-id xxx` in PowerShell → character appears; multi-agent; stale cleanup; permission bubbles; camera drag+zoom; `config.lua`; cold-boot prime. | Real JSONL path (`%USERPROFILE%\.claude\projects\`), `camera.lua`, `config.lua`, permission timer, stale-session cleanup, multi-character seat assignment |

Plans.md at repo root owns task-level breakdown per slice.
