# Pixel Agents Lua — Manual Test Checklist

For running locally on Windows 11 after each significant change. No CI yet.

## One-time setup

- [ ] `winget install --exact --id Love2d.Love2d`
- [ ] `winget install --exact --id DEVCOM.LuaJIT`
- [ ] (Optional) Add `%LOCALAPPDATA%\Programs\LuaJIT\bin` to user PATH so `luajit` resolves without a full path.

## Unit + integration tests

- [ ] `pixel-agents-lua\scripts\test.bat` exits 0; reports ≥ 124 passing specs (as of S4).

## Boot smoke (no Claude session running)

- [ ] `love pixel-agents-lua` from the repo root.
- [ ] Window opens at 1280×720 titled "Pixel Agents".
- [ ] An office is visible: floor tiles, border walls, 4 brown desk squares.
- [ ] Console / `%APPDATA%\LOVE\pixel-agents-lua\last-boot.log` shows `[boot] OK` with `workspace=` and `projectHash=` lines.
- [ ] Log shows `primed N existing files` where N is the count of pre-existing `*.jsonl` files in the Claude project dir. None of them spawn a character.

## Camera

- [ ] Middle-mouse drag pans the view.
- [ ] Mouse wheel up/down snaps zoom to integer multiples (range 1×–6×).
- [ ] Floor tiles and sprites stay pixel-sharp at every zoom level (no blur).

## Single session — cold start

In PowerShell:

```powershell
cd C:\Users\leonw\Workspace\pixel-agents-native
claude --session-id test-1
```

- [ ] Within ~2 seconds, a character appears at the door and walks toward seat s1.
- [ ] Character finishes walking at s1 and faces down (idle stand frame).

## Tool activity animations

With the Claude session active:

- [ ] `Read path/to/file` (or ask Claude to read something) → character plays the read-frames cycle at the desk.
- [ ] `Write ...` / `Edit ...` / `Bash ...` → character plays the type-frames cycle.
- [ ] Tool completion returns the character to standing.

## Turn-end waiting bubble

- [ ] After Claude stops emitting tool calls, a green check bubble appears above the head.
- [ ] Bubble fades after 2 seconds.

## Permission bubble

- [ ] Ask Claude to run a non-read-only tool (e.g. `Bash ls`) and don't approve in Claude Code for ≥ 7 seconds.
- [ ] An amber "..." bubble appears above the character.
- [ ] Approving the tool in Claude Code clears the bubble.

## Multi-agent

In a second PowerShell:

```powershell
cd C:\Users\leonw\Workspace\pixel-agents-native
claude --session-id test-2
```

- [ ] Second character appears; walks to seat s2 (first unoccupied seat in declaration order).
- [ ] First character is unaffected.

## Waitlist → promotion

- [ ] Start 5 sessions in 5 separate PowerShell windows. 4 take seats; 5th idles at the door.
- [ ] Leave one session silent for > 60 seconds (close its PowerShell or just don't type anything).
- [ ] That character fades/disappears; the door-idle character walks to the freed seat.

## `/clear` behavior

- [ ] In Claude, type `/clear`. Old JSONL stops receiving lines; a new JSONL appears for the new session.
- [ ] Original character goes silent and is removed after 60 seconds of no activity.
- [ ] A new character spawns for the new session and walks to the next free seat.

## Clean shutdown

- [ ] Press Esc OR click the window close button.
- [ ] Process exits within ~1 second (watcher thread joins cleanly).
- [ ] No stray `lovec.exe` or watcher thread lingers (check with `tasklist`).
