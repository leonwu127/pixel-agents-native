# Pixel Agents — Plans.md

Created: 2026-04-21
Branch: pixel-agents-lua

> Vertical-slice plan (per `wiki/pixel-agents-lua/design.md` D11). Each slice ships a demoable prototype; later slices evolve the earlier prototype without rewrites.

**Platform** (per D10): Windows 11 native. LuaJIT + Love2D via `winget`. No WSL.
**Testing** (per D12): pure-Lua shim `spec/helper.lua`, run via `luajit.exe`.
**GitHub issues as of 2026-04-21**: 0 open.

---

## Slice S1 — Hello Office

**Demo at end of slice**: `love pixel-agents-lua` opens a 1280×720 window showing a small office (floor tiles + walls + a single hardcoded character sprite at a fixed tile). Character does not animate. Close window = clean exit.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S1.1 | Scaffold `pixel-agents-lua/` skeleton + pure-Lua test harness + first passing spec | Directory tree per design §5.1 exists; `luajit pixel-agents-lua/spec/assert_spec.lua` prints `OK` and exits 0; `pixel-agents-lua/scripts/test.bat` runs all specs | - | cc:TODO |
| S1.2 | `src/layout/loader.lua` + minimal `layouts/mvp_v0.lua` (hardcoded small office: 20×11 grid, 1 door, 4 seats, 4 desks) | `luajit spec/layout_loader_spec.lua` passes: valid file loads; missing required field throws via `assertf` | S1.1 | cc:TODO |
| S1.3 | `src/assets.lua` — mount `../webview-ui/public/assets/` via `love.filesystem.mountFullPath`; load characters/char_0.png, floors.png, walls.png into `love.graphics.Image` map | In `love .`, console prints `assets loaded: chars=1 floors=>=1 walls=>=1` with no error; `setDefaultFilter("nearest")` applied | S1.1 | cc:TODO |
| S1.4 | `conf.lua` + `main.lua` + `src/systems/renderer.lua` — window opens, renders floor → walls → 1 character sprite (hardcoded at seat 1) z-sorted by Y | `love pixel-agents-lua` opens 1280×720 window with visible floor tiles, walls, and 1 character sprite; no Lua errors in console; Alt+F4 exits cleanly | S1.2, S1.3 | cc:TODO |

**Manual demo** (marks S1 done): screenshot of the window at `wiki/pixel-agents-lua/demos/s1.png` (optional for MVP; skip if screen-capture is friction).

---

## Slice S2 — Walk on demand

**Demo at end of slice**: start from S1's static scene; pressing **Space** picks an empty seat and walks the character from the door to that seat with a 4-frame walk animation. On arrival, character idles (stands still). Press Space again → walks to next free seat.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S2.1 | `src/systems/pathfinder.lua` — BFS on grid; `findPath(blocked, from, to) → {tiles}` or nil [P] | `luajit spec/pathfinder_spec.lua` passes: start=end, blocked start/end, unreachable (returns nil), U-shape obstacle | S1.1 | cc:TODO |
| S2.2 | `src/world.lua` — central state: `characters{}`, `seats{}`, `layout`; API `addCharacter(id)`, `assignSeat(id)`, `findFreeSeat()` (no tool events yet) | `luajit spec/world_spec.lua` passes: add character gets seat 1; second gets seat 2; full seats → nil | S1.2 | cc:TODO |
| S2.3 | `src/entities/character.lua` — FSM (idle/walk); `update(dt, world)`; 4-frame walk anim at 200ms/frame; position interpolates along path tiles | `luajit spec/character_spec.lua` passes: setState walk advances x,y toward next path tile each update; reaches end → state flips to idle | S2.1, S2.2 | cc:TODO |
| S2.4 | Wire `main.lua` + `renderer.lua`: on boot add 1 character at door; Space key → `world.findFreeSeat()` + `pathfinder.findPath` + `character.walkTo(path)` | In `love .`, initial scene = S1 demo; press Space → character walks from door to a seat with visible animation; press Space again → walks to next free seat | S2.3 | cc:TODO |

---

## Slice S3 — Fake JSONL drives it

**Demo at end of slice**: start from S2's scene; instead of Space triggering walks, a background thread polls a fake `.jsonl` file at a fixed dev path (`pixel-agents-lua/dev/fake-session.jsonl`). Appending a `tool_use` record → character walks to seat and plays type/read animation. Appending a `turn_duration` record → character shows green-check waiting bubble for 2s.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S3.1 | `src/systems/parser.lua` — JSONL line → `{kind, sessionId, toolId, toolName, input}` event; handles `assistant.tool_use`, `user.tool_result`, `system.turn_duration`, mixed content arrays, malformed JSON (returns nil) [P] | `luajit spec/parser_spec.lua` passes all cases in plan.md Task 6; ≥80% line coverage on `parser.lua` | S1.1 | cc:TODO |
| S3.2 | `src/provider.lua` contract + factory + `src/providers/claude.lua` (tool→state map, `formatToolStatus`, permission-exempt set) | `luajit spec/provider_spec.lua` + `spec/claude_provider_spec.lua` pass; unknown id throws | S3.1 | cc:TODO |
| S3.3 | `src/systems/watcher.lua` — pure `scanOnce(dirs, state) → {newLines, newState}` with per-file offset + partial-line buffer [P] | `luajit spec/watcher_spec.lua` passes: new file detected, append delivers new lines, partial line held in buffer, stable state after re-scan | S1.1 | cc:TODO |
| S3.4 | `src/systems/watcher_thread.lua` — Love2D thread entry looping `watcher.scanOnce` every 500ms; pushes lines via `love.thread.getChannel("agent_events")` | In `love .`, touching the fake JSONL appends a line and main thread receives it within 700ms (log via `print`) | S3.3 | cc:TODO |
| S3.5 | Extend `world.lua` — `apply(event)` FSM for all S3 event kinds (`session_discovered`, `tool_start`, `tool_end`, `turn_end`); `character.bubble` field (nil | "waiting"); 2s bubble fade | `luajit spec/world_spec.lua` passes: `tool_start Read` → character.state="read"; `turn_end` → bubble="waiting"; after 2.1s update → bubble=nil | S2.2, S3.1, S3.2 | cc:TODO |
| S3.6 | `src/scenes/office.lua` — wires watcher-thread → parser → provider → world → renderer; point at dev fake path; renderer adds bubble draw | End-to-end: `echo <tool_use JSON>` appended to `dev/fake-session.jsonl` → character appears, walks to seat, animates read; `echo <turn_duration JSON>` → green bubble appears and fades; no errors | S2.4, S3.4, S3.5, `character.lua` animation frames (read/type) | cc:TODO |

---

## Slice S4 — Real Claude + polish

**Demo at end of slice**: run `claude --session-id test-1` in a PowerShell window (cwd = this repo) → pixel character appears in the Love2D window within 2s, walks to a seat, animates per tool usage. Open a second PowerShell with a second session → second character. `/clear` in Claude → character fades. No activity for 60s → character fades. Middle-mouse drag pans camera; wheel zooms 1x/2x/3x.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S4.1 | `src/config.lua` — read `%USERPROFILE%\.pixel-agents-lua\config.lua` (fields: `layoutFile`); fallback to `layouts/mvp_v0.lua` [P] | `luajit spec/config_spec.lua` passes: missing file → defaults; malformed → loud error via `assertf` | S3.1 | cc:TODO |
| S4.2 | Real Claude path: compute project-hash from cwd (`:`,`\`,`/` → `-`); watcher points at `%USERPROFILE%\.claude\projects\<hash>\`; cold-boot prime (startup mtime → ignore pre-existing sessions) | In `love .`, launching with 3 pre-existing `.jsonl` files under the target dir → 0 initial characters; running `claude --session-id fresh-$(date +%s)` → character appears within 2s | S3.6 | cc:TODO |
| S4.3 | Multi-character seat assignment: on `session_discovered`, pick first free seat (deterministic order); on `removeCharacter`, reassign freed seat to idle-at-door characters in FIFO order | `luajit spec/world_spec.lua` extended: 2 sessions get seats 1, 2; remove char 1 → its seat is free; new session gets seat 1; 5-seat layout + 6 sessions → 6th idles at door; remove any → 6th takes seat | S3.5 | cc:TODO |
| S4.4 | `src/camera.lua` — middle-mouse drag pans; wheel scrolls zoom 1x↔2x↔3x (integer multiples, pixel-perfect) [P] | In `love .`, middle-drag visibly moves view; wheel up/down snaps zoom; no subpixel blur (floor tiles stay sharp); sprite scale matches zoom | S1.4 | cc:TODO |
| S4.5 | Permission timer (7s) + stale-session cleanup (60s fadeout) + waiting-bubble polish | `luajit spec/world_spec.lua` extended: non-exempt tool with no `tool_result` in 7s → bubble="permission"; 60s silence → character state transitions to fadeout; fadeout completes → `removeCharacter`. In `love .`, Bash without approve → amber "..." after 7s; Read stays clean | S3.5 | cc:TODO |
| S4.6 | `wiki/pixel-agents-lua/manual-test-checklist.md` + finalize `pixel-agents-lua/README.md` (Windows prereqs, run, test, troubleshooting) | Checklist file exists with all 9 items from design.md §8.4 (adapted for Windows); README covers `winget` install, `love .`, `scripts\test.bat`, known gotchas | S4.2, S4.3, S4.4, S4.5 | cc:TODO |

---

## Marker legend

| Marker | Meaning |
|--------|---------|
| `cc:TODO` | Not started |
| `cc:WIP` | In progress (one at a time) |
| `cc:done [sha]` | Completed, commit hash recorded |
| `blocked: <reason>` | Cannot proceed; reason required |
| `[P]` (in Intent) | Parallelizable with other `[P]` tasks that don't share files |

## Scope notes

- **Platform** (D10): Windows 11 native. JSONL at `%USERPROFILE%\.claude\projects\`. LuaJIT paths accept `/` and `\`.
- **No symlinks**: assets loaded via `love.filesystem.mountFullPath`, not `mklink` (avoids admin/dev-mode requirement).
- **Assets legal**: character PNGs **not** MIT; `BACKLOG.md [LEGAL]` must be resolved before any public distribution. MVP is local-only.
- **Deferred** (BACKLOG): hooks mode, sub-agent viz, sound, palette diversity, matrix effect, layout editor, sound notifications.
- **Testing**: `scripts\test.bat` at repo top of `pixel-agents-lua/` runs every `spec\*_spec.lua`. No Love2D, no C deps, no luarocks.
