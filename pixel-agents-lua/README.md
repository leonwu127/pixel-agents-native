# Pixel Agents Lua

A Love2D + Lua pixel-art visualizer for running Claude Code CLI sessions. Windows 11 native.

**Status** (as of 2026-04-21): S5 complete. Hooks mode available (opt-in) for <100ms latency; polling mode still works as default/fallback.

## What it does

Run `love .` from this directory, then open a PowerShell and start `claude --session-id <uuid>`. Within ~2 seconds a pixel character walks into the office, sits at a desk, and animates based on what Claude is doing (Read / Write / Bash / etc.). Multiple concurrent sessions = multiple characters. Green check bubble on turn-end; amber "..." bubble on pending permission. Silent for > 60 s → fades and a waiting character takes the freed seat.

## Prereqs (one-time)

```powershell
winget install --exact --id Love2d.Love2d      # 11.5
winget install --exact --id DEVCOM.LuaJIT      # 2.1 + LuaRocks
```

Add `%LOCALAPPDATA%\Programs\LuaJIT\bin` to your user PATH if you want `luajit` on the command line without a full path.

## Run

```powershell
cd C:\Users\leonw\Workspace\pixel-agents-native
love pixel-agents-lua
```

…or from inside this folder: `love .`

### Controls

| Input | Effect |
|-------|--------|
| Middle-mouse drag | Pan camera |
| Mouse wheel | Zoom 1× … 6× (integer, pixel-perfect) |
| `Esc` | Quit |

### Spawning agents

In any separate PowerShell window (same cwd as where you launched Love2D):

```powershell
claude --session-id test-1
```

A character appears within ~2 s and walks to the first free seat. Ask Claude to do anything — you should see animation change per tool.

## Test

```powershell
scripts\test.bat
```

Runs every `spec\*_spec.lua` under LuaJIT. 124 specs as of S4. No Love2D required; no C deps (per `design.md` D12 — a pure-Lua busted-compatible shim lives in `spec/helper.lua`).

## Troubleshooting

- **"luajit.exe not found"** — Open a fresh PowerShell (PATH from winget takes effect in new shells) or add `%LOCALAPPDATA%\Programs\LuaJIT\bin` to PATH.
- **"failed to open ...char_0.png"** — assets are read from `../webview-ui/public/assets/` relative to this folder. Don't move `pixel-agents-lua/` out of the monorepo without first symlinking or copying the assets.
- **Character doesn't appear when running `claude`** — verify the cwd when invoking `claude` matches the workspace path logged at boot (`last-boot.log`). Claude hashes the cwd path to locate its JSONL project folder (`:/\/` → `-`). If you `cd` to a different dir before invoking `claude`, the project hash differs and we won't see the JSONL.
- **Windows `taskkill` / stray processes** — `taskkill /F /IM lovec.exe` and `tasklist | findstr love` to audit.

## Config (optional)

Create `%USERPROFILE%\.pixel-agents-lua\config.lua` to override defaults:

```lua
return {
  workspacePath = "C:\\Users\\me\\Projects\\some-repo",  -- overrides auto-detect
  layoutFile    = "layouts/mvp_v0.lua",
  pollMs        = 500,
  hooksEnabled  = false,  -- opt-in; see "Hooks mode" below
}
```

## Hooks mode (optional, faster)

Default mode polls the Claude transcript at 500ms intervals. For <100ms latency, set `hooksEnabled = true` in `config.lua` and restart.

**What it does**: on boot, Love2D starts a local HTTP server on `127.0.0.1:<random>`, writes `~/.pixel-agents-lua/server.json` (port + auth token), and installs entries in `~/.claude/settings.json` pointing every hook event at `~/.pixel-agents-lua/hooks/claude-hook.ps1`. Claude then POSTs each event to Love2D the moment it fires.

**Opt-in because it modifies your Claude config.** On graceful quit (Esc / close window) the hook entries are removed and `~/.claude/settings.json` is restored byte-for-byte to its pre-boot state. Hard-kill leaves entries behind, but the next clean boot dedupes + overwrites them — never duplicates.

**Polling still runs** alongside hooks. Hooks drive lifecycle (spawn, idle, permission); polling continues to parse tool content. The character's `hookDelivered` flag suppresses polling's 7s permission fallback once hooks are confirmed live.

## Build a standalone .exe

To produce a distributable Windows binary that doesn't require end users to install Love2D:

```powershell
pwsh pixel-agents-lua\scripts\build-exe.ps1 [-Zip] [-Console]
```

Output: `pixel-agents-lua\dist\pixel-agents-lua\` contains `pixel-agents-lua.exe` + Love2D DLLs + `assets/` + `layouts/` + `hooks/`. The whole folder is self-contained — copy it anywhere and double-click the `.exe`. With `-Zip`, also writes `dist\pixel-agents-lua.zip` (~4.5 MB). With `-Console`, fuses `lovec.exe` so `print()` output attaches to the launching shell (for debugging).

What the script does: zips the runtime Lua into a `.love`, fuses it onto `love.exe` (`copy /b`), stages Love2D's DLLs + license, and copies `webview-ui/public/assets/`, `layouts/`, and `hooks/` beside the exe. `assets.lua` detects fused mode via `love.filesystem.isFused()` and reads from the sibling `assets/` dir; dev mode still reads from the monorepo path.

## Development

- Main design: `../wiki/pixel-agents-lua/design.md`
- Backlog (deferred work): `../wiki/pixel-agents-lua/BACKLOG.md`
- Manual-test checklist: `../wiki/pixel-agents-lua/manual-test-checklist.md`
- Task tracking: `../Plans.md`

## Assets legal note

Character PNGs (`../webview-ui/public/assets/characters/char_*.png`) come from the [JIK-A-4 Metro City pack on itch.io](https://jik-a-4.itch.io/metrocity-free-topdown-character-pack) and are **not MIT**. Fine for local development; resolve `BACKLOG.md [LEGAL]` before any public distribution. Floor / wall / furniture PNGs are MIT (created by the `pixel-agents-native` author) and can be reused with attribution.
