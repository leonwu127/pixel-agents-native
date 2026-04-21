---
name: plan
description: "Plan stage — interview, decompose, and produce/update Plans.md. Trigger on: make a plan, add a task, mark done, check progress, plan this feature, 给我做个计划, 计划, 任务清单. Do NOT load for: implementation, review, release."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch"]
argument-hint: "[create|add|update|sync] [task-id] [WIP|done|blocked]"
effort: medium
---

# Plan Skill — Stage 1 of 3

Turns intent into an actionable `Plans.md` at the repo root. Owns task decomposition, DoD writing, status markers, and progress sync. **Does not implement, review, or release.**

## Subcommands

| User input | Subcommand | Action |
|------------|------------|--------|
| `/plan` or `/plan create` | `create` | Interview user, generate `Plans.md` |
| `/plan add` | `add` | Append task to current phase |
| `/plan update <task-id> <status>` | `update` | Change status marker |
| `/plan sync` | `sync` | Diff Plans.md against code state, propose marker fixes |

Default subcommand when ambiguous: `create` if `Plans.md` does not exist, otherwise `sync`.

## `create` — generate Plans.md

**Flow:**
1. Check if `Plans.md` exists at repo root. If yes, ask before overwriting.
2. Extract context from conversation history (what has the user already described?).
3. Ask up to 3 focused questions: goal, scope, constraints. Skip questions if the answer is already in context.
4. Light technical recon via `Grep`/`Glob` to ground tasks in real files (e.g. `webview-ui/src/`, `server/src/`, `src/`).
5. List candidate features/changes.
6. Apply a priority filter: **Required** (MVP) / **Recommended** (nice-to-have) / **Optional** (future).
7. Decide TDD applicability per task: is there an existing test file pattern nearby?
8. Write `Plans.md` using the template at `.claude/templates/Plans.md.template`.
9. Print a **next-step handoff**:
   ```
   Next: /work <task-id>   # single task
     or: /work all         # sequential through Plans.md
   ```

**DoD writing rules** — never write "looks good" / "works correctly". Every DoD must be verifiable by one of:
- A specific command exits 0 (`npm test`, `npm run check-types`, `npm run build`, `npm run e2e`)
- A specific file exists at a specific path
- A specific string appears in logged output
- A UI element is visible / interactive in the Extension Dev Host

**File output rules** — Plans.md lives at the repo root (not in `.claude/`). Tracked in git.

## `add` — append a task

```
/plan add "<task title>" [--phase N]
```

- Parse the title and phase.
- Append a new row to the phase table with status `cc:TODO`.
- If phase doesn't exist, create it.
- Auto-assign task number `<phase>.<next-index>`.

## `update` — change status marker

```
/plan update <task-id> <WIP|done|blocked>
```

| Argument | Marker |
|----------|--------|
| `WIP` | `cc:WIP` |
| `done` | `cc:done [<short-sha>]` (hash from `git log --oneline -1`) |
| `blocked` | `blocked: <reason>` (prompt for reason if missing) |
| `TODO` | `cc:TODO` (revert) |

## `sync` — reconcile Plans.md with reality

**Flow:**
1. Read current `Plans.md`.
2. Run `git status --short` and `git log --oneline -20` to see what moved.
3. For each `cc:WIP` task: has any mentioned file changed in the last N commits? If yes, propose `cc:done`.
4. For each `cc:done` task: does the DoD command still pass? Only spot-check cheap ones (lint, typecheck).
5. Print a diff of proposed marker changes. Apply only with user confirmation.

## Plans.md format (v2)

```markdown
# Pixel Agents — Plans.md

Created: YYYY-MM-DD
Branch: <current-branch>

---

## Phase 1: <phase name>

| Task | Intent | DoD | Depends | Status |
|------|--------|-----|---------|--------|
| 1.1  | Short description | `npm test` passes | - | cc:TODO |
| 1.2  | Short description | File `src/foo.ts` exists with export `bar` | 1.1 | cc:WIP |
| 1.3  | Short description | `npm run build` exits 0 | 1.1, 1.2 | cc:done [a1b2c3d] |
```

**Marker legend:**

| Marker | Meaning |
|--------|---------|
| `cc:TODO` | Not started |
| `cc:WIP` | In progress (one agent at a time) |
| `cc:done [sha]` | Completed, commit hash recorded |
| `blocked: <reason>` | Cannot proceed; reason required |

## Guardrails

- **No scope creep.** If the user's request expands mid-plan, stop and ask before rewriting existing phases.
- **No phantom tasks.** Every task must reference a real file path or a concrete artifact to be produced.
- **Bias toward fewer phases.** Most features fit in 1-2 phases. If you're at phase 4, question whether you're over-decomposing.
- **Plans.md is authoritative.** Never duplicate task state into other files. Always refer back.
