---
name: review
description: "Review stage — multi-angle review of code diff, plan, or scope. Trigger on: review, code review, plan review, check my work, 代码审查, 审查, 帮我 review. Do NOT load for: implementation, new features, bugfix, setup."
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[code|plan|scope] [--base <ref>] [--security]"
effort: high
---

# Review Skill — Stage 3 of 3

Independent multi-angle review. Returns a verdict (`APPROVE` or `REQUEST_CHANGES`) plus findings grouped by severity. **Does not write code** — a reviewer that edits is a worker. If fixes are needed, the caller runs `/work` to apply them.

## Decision tree

Parse arguments:
- `--security` → Security-focused review path
- First positional arg matches `plan` → Plan review path
- First positional arg matches `scope` → Scope review path
- Otherwise → Code review path (default)

## Code review (default)

### Auto-start contract

If invoked with no arguments, **do not stop to ask what to review.** Resolve the review target automatically:

1. Determine `BASE_REF`:
   - If `--base <ref>` is given, use it.
   - Else if on a feature branch, use `git merge-base HEAD origin/main`.
   - Else use `HEAD~1`.
2. Print one handshake line: `REVIEW_AUTOSTART: base=<ref>, type=code`
3. Proceed to the review flow.

### Flow

1. Collect the diff: `git diff <base>...HEAD` (or `git diff --staged` if on `main` with staged changes only).
2. List changed files. Read each file at its current state.
3. For each file, check against the four severity tiers (see below).
4. Cross-file checks:
   - Are exports used? Are new symbols named consistently with local conventions?
   - Do test files cover the production changes? If not, is it justified by the task?
   - Are constants hoisted to `src/constants.ts` / `server/src/constants.ts` / `webview-ui/src/constants.ts` per CLAUDE.md?
5. If a Plans.md task is in `cc:WIP` or `cc:done` and mentioned in commit messages, verify its DoD holds against the current state.
6. Produce the verdict.

### Severity tiers (the **only** thing that drives verdict)

| Tier | Triggers REQUEST_CHANGES? | Examples |
|------|---------------------------|----------|
| **critical** | Yes, any 1 | Secret leaked, data loss, privilege escalation, command injection, arbitrary code execution, SSRF |
| **major** | Yes, any 1 | Breaks existing behavior, contract/type violation, fails documented DoD, crashes on obvious input, skipped-but-claimed-done task |
| **minor** | No | Naming, missing comment on non-obvious block, style, local duplication |
| **recommendation** | No | Future refactor idea, best-practice suggestion |

> **Rule**: If every finding is `minor` or `recommendation`, the verdict **must** be `APPROVE`. "It would be nicer if..." is not grounds for REQUEST_CHANGES.

### Project-specific review lenses

Based on `CLAUDE.md`:
- **Constants**: new magic numbers or strings in `src/` / `server/src/` / `webview-ui/src/` should live in the corresponding `constants.ts`, not inline.
- **TypeScript rules**: no `enum` (use `as const`); `import type` for types; no unused locals/parameters.
- **Webview ↔ extension boundary**: new `postMessage` payloads should be consistent with the message protocol in `PixelAgentsViewProvider.ts`.
- **Windows paths**: anything reading/writing paths must handle `\\` and `/`. Watch for `path.join` vs string concat.
- **Terminal/JSONL state**: changes to `agentManager.ts`, `fileWatcher.ts`, `transcriptParser.ts`, or `hookEventHandler.ts` are high-risk. Flag absence of test coverage as `major`.
- **Server hooks**: changes to `server/src/` require `npm run test:server` green.

## Plan review (`/review plan`)

Target: `Plans.md`.

Checks:
- Every task has a verifiable `DoD` (not "works correctly").
- Dependencies form a DAG (no cycles).
- `Intent` per task is ≤ 1 line and self-describing.
- No phantom files: each task references at least one plausible path (check with `Glob`).
- No over-decomposition: phases with >10 tasks or single tasks spanning >5 files are flagged as `minor`.

## Scope review (`/review scope`)

Target: current branch vs `main`.

Checks:
- Files changed match the declared Plans.md tasks.
- No unplanned rewrites of unrelated modules.
- New dependencies in `package.json` are tied to a declared task.
- Generated/build output (`dist/`, `*.vsix`) is not committed.

## Security review (`--security`)

Same as code review, but with elevated scrutiny for:
- Child process spawning (command injection)
- HTTP server endpoints (auth, CORS, input validation)
- File system reads/writes (path traversal)
- Hook scripts and settings.json modifications
- External asset loading (supply chain)
- Secrets in config files or logs

Any of the above with unverified input sources → **critical**.

## Output format

Print this structure at the end of every review:

```
REVIEW RESULT
=============
Verdict: APPROVE | REQUEST_CHANGES
Type: code | plan | scope
Base: <ref>

Findings:
  critical: <n>
  major: <n>
  minor: <n>
  recommendation: <n>

Details:
  [critical] <file>:<line> — <one-line issue> — <evidence>
  [major]    <file>:<line> — <one-line issue> — <evidence>
  [minor]    <file>:<line> — <one-line issue>
  [recommendation] <file> — <suggestion>

Next: /work <task-id>         # if REQUEST_CHANGES
  or: commit and open PR       # if APPROVE
```

## Guardrails

- **No editing.** If you find yourself wanting to run `Edit` or `Write`, stop. Return findings instead.
- **Evidence-driven.** Every `critical` or `major` finding must cite a file:line or a command whose output proves the issue. Unsupported "concerns" go into `recommendation`, not verdict-affecting tiers.
- **No new requirements.** Do not invent acceptance criteria the plan does not contain.
- **Respect the plan.** If the plan declared a trade-off (e.g. "skip tests for scratch script"), honor it.
