---
name: build
description: "Build pixel-agents-lua into a standalone Windows .exe. Trigger on: build, build the exe, package, ship, release, 打包, 构建, 出 exe, 打个包, build.bat, build it, make exe, make a release. Runs the spec suite first, then scripts\\build-exe.ps1. Do NOT load for: writing new features, planning, editing code."
allowed-tools: ["Bash", "Read"]
argument-hint: "[--zip] [--console] [--skip-tests]"
effort: low
---

# Build Skill — package pixel-agents-lua as a Windows .exe

Invokes `pixel-agents-lua\scripts\build-exe.ps1`, which fuses `love.exe + game.love` into `dist\pixel-agents-lua\pixel-agents-lua.exe` and stages Love2D's runtime DLLs + `assets/` + `layouts/` + `hooks/` beside it.

This skill is a thin wrapper with three responsibilities: **fail fast on red specs**, **forward build flags**, **summarize the output**. It never edits source.

## Flags (passed through to build-exe.ps1)

| Flag | Effect |
|------|--------|
| `--zip` | Also produce `dist\pixel-agents-lua.zip` for distribution |
| `--console` | Fuse `lovec.exe` instead of `love.exe` so `print()` attaches to the launching shell (debugging only — never ship this variant) |
| `--skip-tests` | Skip the spec suite prerun (use when you've just run specs and know they're green) |

No flags = fastest build: specs + silent exe only, no outer zip.

## Flow

1. **Preflight**
   - Verify `pixel-agents-lua/scripts/build-exe.ps1` exists. If not, abort with: *"build script missing — are we still in the right repo?"*
   - Verify `C:\Program Files\LOVE\love.exe` exists. If not, abort with: *"Love2D not installed — run `winget install Love2d.Love2d` first."*

2. **Specs** (unless `--skip-tests`)
   - Run every `pixel-agents-lua\spec\*_spec.lua` under `%LOCALAPPDATA%\Programs\LuaJIT\bin\luajit.exe`.
   - Pattern (from a bash shell, since test.bat assumes cmd PATH):
     ```sh
     cd pixel-agents-lua
     for f in spec/*_spec.lua; do
       OUT=$(/c/Users/leonw/AppData/Local/Programs/LuaJIT/bin/luajit.exe "$f" 2>&1 | tail -1)
       # sum "N passed" / "N failed" tokens
     done
     ```
   - If any spec fails: print the failing file's last 8 lines and abort. **Do not proceed to build with red tests.**

3. **Build**
   - Resolve flags: map `--zip` → `-Zip`, `--console` → `-Console`.
   - Run:
     ```sh
     powershell -NoProfile -ExecutionPolicy Bypass \
       -File pixel-agents-lua/scripts/build-exe.ps1 [-Zip] [-Console]
     ```
   - Stream stdout through; capture the `[build] done:` line for the summary.

4. **Summary**
   - Print a 3-line report:
     ```
     ✓ pixel-agents-lua.exe — <size MB>
       dist/pixel-agents-lua/   (standalone folder)
       dist/pixel-agents-lua.zip   (only when --zip)
     ```
   - Remind the user: *"Double-click `pixel-agents-lua.exe` to run; no Love2D install required on the target machine."*

## Guardrails

- **Never commit `dist/`.** It's already in `pixel-agents-lua/.gitignore`; if this changes, stop and ask.
- **Never modify `assets.lua` or `main.lua` from this skill.** Fused-mode support lives in source. If the build fails because of a missing fused-mode branch, route the user to `/work` — this skill doesn't fix source.
- **Never kill the user's running Claude session.** If a `Stop-Process -Name lovec` is tempting to clean up a locked `dist/` directory, first check whether it's a `pixel-agents-lua` process or the user's interactive Love2D window; prefer `CloseMainWindow()` for graceful shutdown.
- **One flag combination at a time.** Don't rebuild with multiple flag permutations "just to be thorough" — the user asked once.

## When to skip specs

`--skip-tests` is fine when:
- You ran `/work` or specs directly less than a minute ago and know they're green.
- You're iterating on packaging-only changes (`build-exe.ps1`, fused-mode guards) and trust the runtime unchanged.

Not fine:
- After editing any `src/**` or `layouts/**` or `conf.lua` / `main.lua`.
- After a `git pull` or `git checkout`.

## Failure modes (expected)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Remove-Item ... 无法访问` | Shell cwd is inside `dist/`, locking the folder | `cd` out of the repo first, then retry |
| Spec fails in `layout_loader_spec` | Layout file edit broke a hardcoded coordinate assertion | Route to `/work` — this skill doesn't patch tests |
| `love.exe not found` | Love2D installed to non-default path | Pass `-LovePath "C:\path\to\LOVE"` to `build-exe.ps1` directly, or install to the default location |
| `.love 不是支持的存档文件格式` | PowerShell's `Compress-Archive` rejects non-`.zip` extension | Already handled in the script (zip → rename); if resurfaces, the script was reverted |

## Output locations (for reference)

```
pixel-agents-lua/
  dist/                          ← gitignored
    pixel-agents-lua/            ← end-user folder (copy anywhere)
      pixel-agents-lua.exe       (414 KB, fused)
      *.dll                      (Love2D runtime, ~8 MB total)
      assets/                    (PNGs)
      layouts/                   (Lua layouts)
      hooks/claude-hook.ps1      (PowerShell hook template)
      license-love2d.txt
      README-dist.txt
    pixel-agents-lua.zip         (only when --zip; ~4.5 MB)
```
