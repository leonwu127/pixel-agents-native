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
| S1.1 | Scaffold `pixel-agents-lua/` skeleton + pure-Lua test harness + first passing spec | Directory tree per design §5.1 exists; `luajit pixel-agents-lua/spec/assert_spec.lua` prints `OK` and exits 0; `pixel-agents-lua/scripts/test.bat` runs all specs | - | cc:done [0c0b0dd] |
| S1.2 | `src/layout/loader.lua` + minimal `layouts/mvp_v0.lua` (hardcoded small office: 20×11 grid, 1 door, 4 seats, 4 desks) | `luajit spec/layout_loader_spec.lua` passes: valid file loads; missing required field throws via `assertf` | S1.1 | cc:done [cf8788e] |
| S1.3 | `src/assets.lua` — load characters/char_0.png, floor_0.png, wall_0.png via `io.open` + `love.image.newImageData` (Love2D 11.5 lacks `mountFullPath`; deferred swap-in when we upgrade to 12) | In `love .`, console prints `[assets] loaded 3 PNGs from ...`; `setDefaultFilter("nearest")` applied | S1.1 | cc:done [cf8788e] |
| S1.4 | `conf.lua` + `main.lua` + `src/systems/renderer.lua` — window opens, renders floor → walls → 1 character sprite (hardcoded at seat 1) z-sorted by Y | `love pixel-agents-lua` opens 1280×720 window with visible floor tiles, walls, and 1 character sprite; no Lua errors in console; Alt+F4 exits cleanly | S1.2, S1.3 | cc:done [cf8788e] |

**Manual demo** (marks S1 done): screenshot of the window at `wiki/pixel-agents-lua/demos/s1.png` (optional for MVP; skip if screen-capture is friction).

---

## Slice S2 — Walk on demand

**Demo at end of slice**: start from S1's static scene; pressing **Space** picks an empty seat and walks the character from the door to that seat with a 4-frame walk animation. On arrival, character idles (stands still). Press Space again → walks to next free seat.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S2.1 | `src/systems/pathfinder.lua` — BFS on grid; `findPath(blocked, from, to) → {tiles}` or nil [P] | `luajit spec/pathfinder_spec.lua` passes: start=end, blocked start/end, unreachable (returns nil), U-shape obstacle | S1.1 | cc:done [1ba864f] |
| S2.2 | `src/world.lua` — central state: `characters{}`, `seats{}`, `layout`; API `addCharacter(id)`, `assignSeat(id)`, `findFreeSeat()` (no tool events yet) | `luajit spec/world_spec.lua` passes: add character gets seat 1; second gets seat 2; full seats → nil | S1.2 | cc:done [1ba864f] |
| S2.3 | `src/entities/character.lua` — FSM (idle/walk); `update(dt, world)`; 4-frame walk anim at 200ms/frame; position interpolates along path tiles | `luajit spec/character_spec.lua` passes: setState walk advances x,y toward next path tile each update; reaches end → state flips to idle | S2.1, S2.2 | cc:done [1ba864f] |
| S2.4 | Wire `main.lua` + `renderer.lua`: on boot add 1 character at door; Space key → `world.findFreeSeat()` + `pathfinder.findPath` + `character.walkTo(path)` | In `love .`, initial scene = S1 demo; press Space → character walks from door to a seat with visible animation; press Space again → walks to next free seat | S2.3 | cc:done [1ba864f] |

---

## Slice S3 — Fake JSONL drives it

**Demo at end of slice**: start from S2's scene; instead of Space triggering walks, a background thread polls a fake `.jsonl` file at a fixed dev path (`pixel-agents-lua/dev/fake-session.jsonl`). Appending a `tool_use` record → character walks to seat and plays type/read animation. Appending a `turn_duration` record → character shows green-check waiting bubble for 2s.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S3.1 | `src/systems/parser.lua` — JSONL line → `{kind, sessionId, toolId, toolName, input}` event; handles `assistant.tool_use`, `user.tool_result`, `system.turn_duration`, mixed content arrays, malformed JSON (returns nil) [P] | `luajit spec/parser_spec.lua` passes all cases in plan.md Task 6; ≥80% line coverage on `parser.lua` | S1.1 | cc:done [4342759] |
| S3.2 | `src/provider.lua` contract + factory + `src/providers/claude.lua` (tool→state map, `formatToolStatus`, permission-exempt set) | `luajit spec/provider_spec.lua` passes; unknown id throws | S3.1 | cc:done [4342759] |
| S3.3 | `src/systems/watcher.lua` — pure `scanOnce(dirs, state) → {newLines, newState}` with per-file offset + partial-line buffer [P] | `luajit spec/watcher_spec.lua` passes: new file detected, append delivers new lines, partial line held in buffer, stable state after re-scan | S1.1 | cc:done [4342759] |
| S3.4 | `src/systems/watcher_thread.lua` — Love2D thread entry looping `watcher.scanOnce` every 500ms; pushes lines via `love.thread.getChannel("agent_events")` | In `love .`, touching the fake JSONL appends a line and main thread receives it within 700ms (log via `print`) | S3.3 | cc:done [4342759] |
| S3.5 | Extend `world.lua` — `apply(event)` FSM for all S3 event kinds (`tool_start`, `tool_end`, `turn_end`); `character.bubble` field (nil | "waiting"); 2s bubble fade. (`session_discovered` is handled in the scene, not world, to keep world pure.) | `luajit spec/world_spec.lua` passes: `tool_start Read` → character.activity="read"; `turn_end` → bubble="waiting"; after 2.1s tick → bubble=nil | S2.2, S3.1, S3.2 | cc:done [4342759] |
| S3.6 | `src/scenes/office.lua` — wires watcher-thread → parser → provider → world → renderer; point at dev fake path; renderer adds bubble draw | End-to-end: JSONL line appended to `dev/fake-session.jsonl` → character appears, walks to seat; turn_duration → green bubble; no errors (verified 2026-04-21: `[scene] spawned fake-session -> seat s1`) | S2.4, S3.4, S3.5 | cc:done [4342759] |

---

## Slice S4 — Real Claude + polish

**Demo at end of slice**: run `claude --session-id test-1` in a PowerShell window (cwd = this repo) → pixel character appears in the Love2D window within 2s, walks to a seat, animates per tool usage. Open a second PowerShell with a second session → second character. `/clear` in Claude → character fades. No activity for 60s → character fades. Middle-mouse drag pans camera; wheel zooms 1x/2x/3x.

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S4.1 | `src/config.lua` — read `%USERPROFILE%\.pixel-agents-lua\config.lua` (fields: `layoutFile`, `workspacePath`, `pollMs`); fallback to `layouts/mvp_v0.lua` [P] | `luajit spec/config_spec.lua` passes: missing file → defaults; path hash correct on Windows | S3.1 | cc:done [8041288] |
| S4.2 | Real Claude path: compute project-hash from cwd (`:`,`\`,`/` → `-`); watcher points at `%USERPROFILE%\.claude\projects\<hash>\`; cold-boot prime (startup sizes → ignore pre-existing sessions) | Booted with 4 pre-existing `.jsonl` files under the real Claude dir → 0 initial characters, log `primed 4 existing files` (verified 2026-04-21) | S3.6 | cc:done [8041288] |
| S4.3 | Multi-character waitlist: on `removeCharacter`, FIFO-promote idle-at-door characters to freed seat | `world.charactersWaitingForSeat(w)` returns char-ids without seats; scene `_promote_waiting()` reassigns after any removal | S3.5 | cc:done [8041288] |
| S4.4 | `src/camera.lua` — middle-mouse drag pans; wheel snaps zoom 1x-6x (integer multiples, pixel-perfect) [P] | `luajit spec/camera_spec.lua` passes 10 cases (drag start/move/release, zoom clamping); in `love .` middle-drag pans, wheel snaps, no subpixel blur | S1.4 | cc:done [0fbfd53] |
| S4.5 | Permission timer (7s) + stale-session cleanup (60s) | `world_spec.lua` extended: non-exempt tool running >7s → bubble="permission"; exempt (Read) never triggers; tool_end clears bubble; >60s idle → `tick` returns session id for removal | S3.5 | cc:done [0fbfd53] |
| S4.6 | `wiki/pixel-agents-lua/manual-test-checklist.md` + finalize `pixel-agents-lua/README.md` (Windows prereqs, run, test, troubleshooting) | Checklist has 10 sections; README covers `winget` install, `love .`, `scripts\test.bat`, controls, troubleshooting, config.lua, legal | S4.2, S4.3, S4.4, S4.5 | cc:done [c2b4941] |

---

## Slice S5 — Hooks mode (dual-mode with polling fallback)

**Motivation** (per `wiki/pixel-agents-lua/BACKLOG.md` [UPGRADE]): replace 200–500ms polling latency with <100ms hook-driven events. Keep polling as fallback + for tool-content tracking.

**Architecture decision**: In-Love2D HTTP server via bundled `luasocket` (no sidecar). Hook script is a PowerShell `.ps1` (Win11 native, no Node dependency). Dual-mode switch via per-character `hookDelivered` flag — hooks suppress polling's idle/permission timers, polling still drives tool content display.

**Safety**: writing `~/.claude/settings.json` is opt-in via `config.lua` `hooksEnabled = true`. Settings.json is backed up before modification. Uninstalled on clean shutdown.

**Demo at end of slice**: set `hooksEnabled = true` in config.lua. Run `claude --session-id test-1`. Character appears and reacts to tool calls with visibly lower latency than polling mode (verify both modes still work by toggling the flag).

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| S5.1 | `src/systems/http.lua` pure HTTP parser + JSON encoder + `src/systems/server_thread.lua` Love2D thread (luasocket bind/accept loop, writes `~/.pixel-agents-lua/server.json`, pushes hook events to `hook_events` channel) | `luajit spec/http_spec.lua` passes (parse request, auth check, build response); in `love .` with `hooksEnabled = true`, server.json appears at `%USERPROFILE%\.pixel-agents-lua\server.json` with port + token; `curl -H "Authorization: Bearer <token>" -X POST -d '{"session_id":"x","hook_event_name":"Stop"}' http://127.0.0.1:<port>/api/hooks/claude` returns 200; main thread prints received event | S4 done | cc:done |
| S5.2 | `src/systems/installer.lua` — read/merge/write `~/.claude/settings.json` (atomic tmp+rename, idempotent dedup by marker), copy `claude-hook.ps1` template to `~/.pixel-agents-lua/hooks/`; uninstall on shutdown | `luajit spec/installer_spec.lua` passes (install idempotent, uninstall restores, dedup on rerun); running `love .` twice leaves exactly one hook entry per event | S5.1 | cc:done |
| S5.3 | `src/systems/hook_events.lua` — map 11 Claude hook event types to world actions (SessionStart→spawn, Stop→turn_end, PreToolUse→tool_start, PermissionRequest→permission bubble, etc.); extend `src/providers/claude.lua` with `hookEventHandler(event) → world_event` | `luajit spec/hook_events_spec.lua` passes: 11 event kinds each map to expected world event; unknown events return nil; malformed events return nil | S5.1 | cc:TODO |
| S5.4 | Wire `scenes/office.lua` — drain `hook_events` channel, set per-character `hookDelivered=true`, suppress polling timers for that session; extend `config.lua` with `hooksEnabled`; `main.lua` lifecycle: install on boot (opt-in), uninstall on quit; update manual-test checklist | With `hooksEnabled=true`, character reacts to Stop within 100ms (vs 500ms+ polling); with `hooksEnabled=false`, existing polling behavior unchanged; clean shutdown removes hooks from settings.json | S5.2, S5.3 | cc:TODO |

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
