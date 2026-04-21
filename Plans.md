# Pixel Agents — Plans.md

Created: 2026-04-21
Branch: pixel-agents-lua

> Central task list for the 3-stage harness workflow (`/plan` → `/work` → `/review`).
> Long-form design docs live in `wiki/pixel-agents-lua/plan.md`; this file tracks
> actionable, verifiable tasks only.

---

## Phase 1: placeholder

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| 1.1  | Populate this file from `wiki/pixel-agents-lua/plan.md` MVP scope | This file lists ≥1 concrete task with a verifiable DoD | - | cc:TODO |

<!--
Populate this file via `/plan create` (interactive) or `/plan add` (append).
Keep rows concise. One task = one commit, ideally. Use [P] to mark parallelizable tasks.

Example rows once populated:
| 1.2 | Wire Lua VM host into extension.ts | `server/__tests__/luaHost.test.ts` passes | 1.1 | cc:TODO |
| 1.3 | Sandbox Lua file IO [P] | No `io.*` call reaches host fs in `npm run test:server` | 1.2 | cc:TODO |
-->

---

## Marker legend

| Marker | Meaning |
|--------|---------|
| `cc:TODO` | Not started |
| `cc:WIP` | In progress (one at a time) |
| `cc:done [sha]` | Completed, commit hash recorded |
| `blocked: <reason>` | Cannot proceed; reason required |
| `[P]` (in Intent) | Parallelizable with other `[P]` tasks that don't share files |

## DoD writing rules

Every DoD must be verifiable by one of:
- A specific command exits 0 (`npm test`, `npm run check-types`, `npm run build`, `npm run e2e`)
- A specific file exists at a specific path
- A specific string appears in logged output
- A UI element is visible / interactive in the Extension Dev Host

Banned DoD phrasing: "works correctly", "looks good", "is better", "handles edge cases".
