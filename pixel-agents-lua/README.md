# Pixel Agents Lua

A Love2D + Lua pixel-art visualizer for running Claude Code CLI sessions. Windows 11 native.

**Status**: building toward MVP via 4 vertical slices (see `../Plans.md`). Currently: S1 (Hello Office).

## Prereqs (one-time)

```powershell
winget install --exact --id Love2d.Love2d
winget install --exact --id DEVCOM.LuaJIT
```

Optional: add `%LOCALAPPDATA%\Programs\LuaJIT\bin` to your PATH so `luajit` is reachable without a full path.

## Run

From this directory:

```powershell
love .
```

Or drag the `pixel-agents-lua` folder onto `C:\Program Files\LOVE\love.exe`.

## Test

```powershell
scripts\test.bat
```

Runs every `spec\*_spec.lua` under `luajit.exe`. No Love2D required for tests — spec code is pure Lua.

## Assets

Character / floor / wall PNGs are borrowed at runtime from `../webview-ui/public/assets/` via `love.filesystem.mountFullPath`. No symlink, no copy. See `src/assets.lua`.

> **Legal note**: Character PNGs are not MIT. Fine for local development; see `../wiki/pixel-agents-lua/BACKLOG.md` `[LEGAL]` before any distribution.

## Design & backlog

- Design: `../wiki/pixel-agents-lua/design.md`
- Backlog: `../wiki/pixel-agents-lua/BACKLOG.md`
- Task list: `../Plans.md`
