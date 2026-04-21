---
name: work
description: "Work stage — execute tasks from Plans.md. Trigger on: implement, do the task, work on, 开始实现, 实现这个, 执行任务. Do NOT load for: planning, review, release."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[all] [task-id | range] [--parallel N] [--no-commit] [--no-tdd]"
effort: high
---

# Work Skill — Stage 2 of 3

Executes tasks declared in `Plans.md`. Owns: implementation, self-preflight, project-level validation, commit preparation. **Does not decide what to build (that's `plan`) or issue final verdicts (that's `review`).**

## Subcommands

| User input | Mode | Action |
|------------|------|--------|
| `/work` | prompt | Ask which task, then route |
| `/work <task-id>` | solo | Implement one task |
| `/work <a>-<b>` | sequential | Do tasks in range, one at a time |
| `/work all` | sequential | Do every `cc:TODO`/`cc:WIP` task in order |
| `/work <task-id> --parallel N` | parallel | Delegate to N `worker` subagents via Task tool (only tasks marked `[P]`) |

Default when ambiguous: ask which task.

## Flow per task

1. **Read Plans.md.** If it does not exist, stop and say: `No Plans.md. Run /plan first.`
2. **Lock the task.** Update status to `cc:WIP` *before* starting work. Only one task may be `cc:WIP` per run.
3. **Read context.**
   - The task's `Intent` and `DoD` columns.
   - Files likely in scope — use `Grep`/`Glob` from keywords in `Intent`.
   - Rules that apply: `.claude/rules/*.md` if present, plus CLAUDE.md.
4. **TDD check.** If a test file exists in the same area (e.g. `server/__tests__/`, `webview-ui/src/**/*.test.ts`), write a failing test first unless `--no-tdd`.
5. **Implement.** Edit only files within a plausible scope for this task. No opportunistic refactors.
6. **Self-preflight (6 checks, all must pass):**
   - Only changed files relevant to this task
   - No `test.skip` / `it.skip` / `eslint-disable` introduced
   - No `TODO`, `FIXME`, or empty function bodies left as the implementation
   - No unrelated refactor mixed in
   - Every hunk in the diff is explainable from the task's `Intent`
   - At least one validation command is applicable
7. **Run validation.** The minimum set is the task's DoD command. Add, as available and cheap:
   - `npm run check-types`
   - `npm run lint`
   - Relevant targeted tests (`npm run test:server` or `npm run test:webview`)
   - Full `npm test` only if changes span both sides
8. **Commit** (unless `--no-commit`):
   - Stage only the files you changed (no `git add .` / `git add -A`).
   - Message format: `<type>: <task-intent>` where type ∈ {feat, fix, refactor, docs, test, chore}.
   - Include the footer `Task: <task-id>` to cross-link to Plans.md.
9. **Update Plans.md.** Mark task `cc:done [<short-sha>]`. Use `git log --oneline -1` to get the hash.
10. **Print completion report** (see below).
11. **Hand off to review.** Print:
    ```
    Next: /review                 # code review of this diff
      or: /work <next-task-id>    # continue implementation
    ```

## Parallel mode (`--parallel N`)

Only tasks marked `[P]` (parallelizable) in Plans.md may be run in parallel. Each task is delegated to a fresh `worker` subagent via the Task tool, with these constraints:
- Each subagent gets exactly one task, the applicable rule files, and the DoD.
- Subagents **must not** edit `Plans.md`. The parent agent updates markers after each subagent completes.
- If two tasks touch the same file, they are **not parallelizable** — downgrade to sequential and print a warning.

## Failure handling

- **Test fails after implementation**: attempt one targeted fix. If it still fails, mark the task `blocked: <reason>` and stop. Do not silently rewrite the test to pass.
- **Build fails**: same — one fix attempt, then `blocked`.
- **Three consecutive failed work sessions on the same task**: escalate to the user. Propose either breaking the task down (`/plan add`) or reconsidering the approach.

## Completion report format

```
✅ Task <id>: <intent>
   Files: <list>
   Validation: <commands that ran + result>
   Commit: <short-sha>  <commit-title>
   Next: <suggestion>
```

## Guardrails

- **Scope lock.** The `files` you touch must be derivable from the task's `Intent`. If mid-task you realize a fix in another module is needed, stop and ask — it is probably a new task.
- **Do not widen tests.** If a pre-existing test fails, do not weaken it to make your change pass.
- **One commit per task** (default). Multiple commits only if the task is large and the user pre-agreed via `/plan`.
- **Don't bypass hooks.** Never pass `--no-verify`, `--no-gpg-sign`, or skip pre-commit without explicit permission.
- **Project commands are authoritative** (see `CLAUDE.md` Build & Dev section):
  - `npm run build` — full build (typecheck + lint + esbuild + vite)
  - `npm test` — webview + server unit/integration
  - `npm run test:server` / `npm run test:webview` — targeted
  - `npm run e2e` — Playwright against real VS Code
  - `npm run check-types` — typecheck only
  - `npm run lint` — eslint only
