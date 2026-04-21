# .claude/ — Agent Harness

Minimal 3-stage agent workflow, adapted from [claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) but stripped of its Go runtime and Japanese-first framework. What remains is pure Claude Code configuration — skills, subagents, permissions, and a task-tracking convention.

## The three stages

```
/plan       →       /work       →       /review
  │                   │                    │
decompose         implement            audit diff
to Plans.md       one task at          return verdict
                  a time               (no edits)
```

| Stage | Skill | Subagent | Owns |
|-------|-------|----------|------|
| 1. Plan  | [`skills/plan`](skills/plan/SKILL.md)  | — | Task decomposition, `Plans.md` maintenance, status markers |
| 2. Work  | [`skills/work`](skills/work/SKILL.md)  | [`worker`](agents/worker.md) | Implementation, project validation, commit preparation |
| 3. Review | [`skills/review`](skills/review/SKILL.md) | [`reviewer`](agents/reviewer.md) | Multi-angle diff audit, verdict by severity |

## Files

```
.claude/
├── README.md                   ← this file
├── settings.json               ← permission allow/ask/deny layers
├── skills/
│   ├── plan/SKILL.md           ← /plan create | add | update | sync
│   ├── work/SKILL.md           ← /work all | <id> | --parallel N
│   └── review/SKILL.md         ← /review [code|plan|scope] [--security]
├── agents/
│   ├── worker.md               ← single-task implementer, yellow
│   └── reviewer.md             ← read-only multi-angle auditor, blue
└── templates/
    └── Plans.md.template       ← scaffold used by /plan create

Plans.md                        ← repo root, tracked in git
```

## Typical loop

1. **Plan**: `/plan create` — you get interviewed, `Plans.md` is written.
2. **Work**: `/work 1.1` — one task, one commit, self-validated via `npm test` / `npm run check-types` / etc.
3. **Review**: `/review` — diff vs `origin/main`, verdict `APPROVE` or `REQUEST_CHANGES`.
4. If `REQUEST_CHANGES`: back to `/work <id>` with findings. If `APPROVE`: push and open PR.

## Severity tiers (review)

Only **critical** and **major** findings block approval. `minor` and `recommendation` never do.

| Tier | Example |
|------|---------|
| critical | Secret leaked, command injection, data loss |
| major | Breaks tests, violates declared DoD, banned `enum` usage, missing coverage on high-risk files (`agentManager.ts`, `fileWatcher.ts`, ...) |
| minor | Naming, style, small duplication |
| recommendation | Future refactor ideas |

## Permissions (`settings.json`)

- **deny**: `sudo`, `rm -rf`, reads of `.env*`, `*.pem`, `*.key`, `~/.ssh/*`, `~/.aws/*`.
- **ask**: destructive git (`reset --hard`, `push --force`, `rebase`, `merge`), package manager installs.
- **allow**: the project's safe read-only and validation commands (`npm run build`, `npm test`, `git status/diff/log/show`).

Edit `settings.json` to tighten or loosen per your comfort. `settings.local.json` (if you create one) is git-ignored and overrides.

## What we intentionally left out

The upstream harness ships ~30 skills, multi-IDE support (Cursor/Codex/OpenCode), a Go guardrail engine, sprint-contract JSON schemas, browser review runners, and more. We pulled only the 3-stage core. If you later want any of:

- **Release automation** (`/harness-release`)
- **Maintenance tasks** (`/harness-maintenance`)
- **Advisor protocol** (consultation subagent)
- **Sprint contracts** (machine-readable DoD JSON)

…they live in `/tmp/harness-ref/claude-code-harness/skills/` on your local reference clone, and can be ported in the same style.

## Extending

- **Add a skill**: create `.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `allowed-tools`). Description is what triggers it — write it for the model.
- **Add a subagent**: create `.claude/agents/<name>.md` with frontmatter (`name`, `description`, `tools`, `model`). Description governs routing from the Task tool.
- **Add a hook**: create `.claude/settings.json` → `hooks` section. See [Claude Code hooks guide](https://code.claude.com/docs/en/hooks-guide). We intentionally skipped hooks in this minimal adoption — re-add only when you have a concrete safety or automation need.
