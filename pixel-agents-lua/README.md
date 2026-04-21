# Pixel Agents Lua

A Love2D + Lua pixel-art visualizer for running Claude Code CLI sessions. Windows 11 native.

**Status** (as of 2026-04-21): S4 complete. Ready for end-to-end manual testing against real Claude sessions.

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
}
```

## Development

- Main design: `../wiki/pixel-agents-lua/design.md`
- Backlog (deferred work): `../wiki/pixel-agents-lua/BACKLOG.md`
- Manual-test checklist: `../wiki/pixel-agents-lua/manual-test-checklist.md`
- Task tracking: `../Plans.md`

## Assets legal note

Character PNGs (`../webview-ui/public/assets/characters/char_*.png`) come from the [JIK-A-4 Metro City pack on itch.io](https://jik-a-4.itch.io/metrocity-free-topdown-character-pack) and are **not MIT**. Fine for local development; resolve `BACKLOG.md [LEGAL]` before any public distribution. Floor / wall / furniture PNGs are MIT (created by the `pixel-agents-native` author) and can be reused with attribution.
