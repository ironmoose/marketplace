# adze-bonch Lifecycle Port Design v1 (2026-06-29)

*Authoritative as of 2026-06-29. Design spec for porting the full pt-doots workflow discipline into the adze-bonch plugin. Supersedes nothing.*

## TL;DR

- Rebuild pt-doots's full orchestrated agent team inside `adze-bonch`, wired to **adze** instead of Jira/PlexTrac, so an adze task can be taken end to end (research, plan, implement, test, multi-agent review gate, commit) under the same discipline.
- The discipline is project-agnostic and ports cleanly; the company specifics get stripped. The single biggest change: agents read **each target project's own `CLAUDE.md`** instead of carrying a hardcoded PlexTrac ruleset.
- All workflow state lives **in adze** (research, plan, progress, findings, metrics as adze documents), honoring adze-bonch's locked rule that state and discipline live in adze. The escalation vocabulary (`[GOVERNANCE]` / `[PLAN-TEST-CONFLICT]` / `[SCOPE-EXPANSION]`) is already shared, because adze-bonch and pt-doots both inherit it.

## Goal (one sentence)

Give adze-bonch the lifecycle/execution layer it deliberately deferred at v0.1.0, ported from pt-doots, adze-native, dogfood-grade.

## Decisions Locked

1. **Approach: full port.** Recreate the complete pt-doots roster and pipeline, not a distillation.
2. **tab-workflow is deprecated.** Reference only, no updates. It informed the "port onto a @4lt7ab MCP store" pattern; we do not keep adze-bonch consistent with its lighter shape.
3. **Standards model: read the target project's conventions at runtime.** Reviewer/implementer/researcher agents read the target repo's `CLAUDE.md` (and nested ones) plus project conventions from the adze project context. No baked-in ruleset.
4. **PR review stays in the existing `pr-review` plugin.** adze-bonch owns the build-the-change lifecycle; `tackle` hands off to `pr-review` for PR review. Therefore `re-reviewer` is NOT ported into adze-bonch (it belongs to the PR-review flow).
5. **Telemetry/metrics persist as adze documents**, mirroring the existing `kind:session-log` "Session Progress Log" pattern. No loose `.local/` files for the lifecycle state.
6. **team-manager + team-audit land in a later phase** (Phase 3), after the tackle lifecycle works.
7. **State lives in adze.** pt-doots's local per-task working files (research, plan, progress) become adze documents. The unit of work is an adze task, not a Jira key.
8. **All shipped docs link to the adze repo** (`https://github.com/4lt7ab/adze`): README, CLAUDE.md, setup wizard output, and the discipline docs seeded into adze.
9. **No phantom agents.** Agent performance/review logs do NOT live under `agents/` (Claude Code registers every `.md` there as an agent; pt-doots accidentally exposes `pt-doots:reviews:*`). Logs go under `reference/` or `.local/`.
10. **Optional SessionStart hook in the setup wizard** (opt-in, default off), offering both this-project (`<project>/.claude/settings.json`) and all-projects (`~/.claude/settings.json`) scopes. The all-projects scope is the one sanctioned, explicit exception to the no-writes-under-`~/.claude/` rule: surgical merge, delimited, removable, never silent.

## The 4 central remaps

| pt-doots | adze-bonch |
|---|---|
| Unit of work = Jira ticket `IO-XXXX` | Unit of work = adze task (inside an adze project), resolved via the existing lookup chain / FTS-on-cwd + ask-user fallback |
| State = local per-task files (research / plan / progress) | State = adze documents (supersede pattern + authoritative-doc convention), bound to the task by frontmatter `task_id` |
| Standards baked into agent prompts (PlexTrac) | Standards read at runtime from the target repo's `CLAUDE.md` + adze project context |
| Escalation tokens defined per-agent | Same three tokens, already adze-bonch's named protocols; orchestrator already specified to scan output for them |

## Agent roster (the port target)

Model tiers keep pt-doots's alias scheme (`haiku` / `sonnet` / `opus`) for portability. "Genericize" = strip the PlexTrac-specific blocks and read target-project conventions instead.

| # | Agent | Tier | Ported? | Key change from pt-doots |
|---|---|---|---|---|
| 1 | scrum-master | haiku | Phase 1 | Classify the adze task into a workflow type from generic complexity/risk signals + task `kind:` tags; drop the 4-repo routing heuristics |
| 2 | researcher | sonnet | Phase 1 | Explore the target repo, write research as an adze doc (`kind:research`); read the repo's own `CLAUDE.md`; drop the PlexTrac codebase guide + Confluence MCP |
| 3 | implementer | sonnet | Phase 1 | Keep plan-surface lock + the 3 protocols (already adze-bonch's); read target conventions; worktree isolation; drop PlexTrac quick-ref |
| 4 | developer | sonnet | Phase 1 | Looser opt-in implementer; same genericization |
| 5 | test-writer | sonnet | Phase 1 | Detect the target repo's test framework from its config/conventions; drop the baked PlexTrac frameworks list |
| 6 | code-reviewer | sonnet | Phase 1 | Enforce the target repo's `CLAUDE.md` rules, not a PlexTrac checklist; keep the inline-diff contract |
| 7 | acceptance-qa | haiku | Phase 1 | Criteria sourced from the adze task description; keep verify-before-flag |
| 8 | edge-case-qa | sonnet | Phase 1 | Keep generic edge dimensions; read the target stack instead of the baked Kysely/BullMQ/CK-Editor checks |
| 9 | code-smells-reviewer | sonnet | Phase 1 | Fowler catalog is already generic; drop language-specific asides or make them stack-aware |
| 10 | test-reviewer | sonnet | Phase 1 | Generic; still requires test + production code inlined together |
| 11 | self-containment-reviewer | sonnet | Phase 1 | Flag leaked adze doc ids, internal labels, private-notes refs in committed text |
| 12 | documentarian | haiku | Phase 2 | Update repo docs + propose adze doc updates; drop Confluence MCP; enforce the adze-repo link requirement |
| 13 | voice-stylist | sonnet | Phase 2 | Read the active voice via the lookup chain (session / project / profile `## Voice` / `voice-default` seed); drop the hardcoded profile path + PlexTrac signature |
| 14 | team-manager | opus | Phase 3 | Roster architect; adapt paths + telemetry to adze-bonch |
| (x) | re-reviewer | sonnet | NOT ported | Lives with the PR-review flow in the `pr-review` plugin, not adze-bonch |

## Command + router structure

The existing `main` router already ships stubbed rows for `tackle` / `brainstorm` / `refine` (marked NOT SHIPPED). The port fills these seams.

- **`/adze-bonch:main`** gains live routes. New phase commands open with "Same as `/adze-bonch:main` Steps 0-2" (load discipline + resolve project), then the phase-specific pipeline. Add a `verify` routing row (it has none today).
- **New command files:**
  - `commands/tackle.md` (Phase 1): the orchestrator pipeline (Step 0 load context, scrum-master route, researcher, plan with user, branch, implement, test, quality gate, fix cycles, documentation, commit gate, handoff).
  - `commands/brainstorm.md`, `commands/refine.md`, `commands/verify.md` (Phase 2).
- **`/adze-bonch:setup`** extends Step 2's seed loop to bootstrap the new discipline docs into adze (the filename to `kind:` mapping is the seam; upgrades re-seed via `seed_hash` drift detection automatically).
- **`/adze-bonch:setup`** gains an **optional SessionStart hook step** (opt-in, default off). The wizard offers three choices: no hook (current behavior), this-project-only (writes `<project>/.claude/settings.json`), or all-projects (writes `~/.claude/settings.json`). Every write is explicit, surgical (merge into existing settings, never clobber), delimited, idempotent, and removable, matching the existing trampoline approach. The hook loads the discipline and surfaces project status at session start (the SessionStart analog of `main` Step 0).
- **`/adze-bonch:save`** and **`/adze-bonch:status`** stay as-is. `save` already is the "save progress" mode; the lifecycle writes through the same synchronous-persistence path.

## Seeds and reference docs

- **New seeds** (bootstrapped into adze, version + hash managed): the lifecycle `workflow` doc, `agent-prompts` (the spawn templates including the inline-diff contract), `progress-format` (the `kind:task-log` doc shape), `branch-naming`. Each gets a `kind:` mapping row in setup.
- **New `plugins/adze-bonch/reference/`** dir for plugin-internal docs that are not seeded into adze (for example `swarm-coordination`, and any agent review/perf logs, kept OUT of `agents/`).
- **Dropped from the port:** `new-integration` (Synqly/EM), `architecture-snapshot`, `v2-design`, `v2-plan`, Confluence MCP wiring, hardcoded repo lists, `gh` binary paths, Jira creds.

## State model in adze

| pt-doots file | adze form | tag(s) |
|---|---|---|
| `research.md` | document, authoritative-doc shape, frontmatter `task_id` | `kind:research`, `provenance:user` |
| `plan.md` | document | `kind:plan` (new) or reuse `kind:design`, `provenance:user` |
| `progress.md` | document, append synchronously, mirrors `session-log` | `kind:task-log` (new), `concurrency:strict` |
| reviewer findings | documents or task notes | `kind:review-finding`, `kind:qa-finding` (both exist) |
| verification failures | document/task | `kind:verification-failure` (exists) |
| governance items | task | `kind:governance` (exists) |
| telemetry/metrics | document, mirrors session-log | `kind:session-log` or `kind:metrics` (new) |

The adze tag namespace already includes `review-finding`, `qa-finding`, `verification-failure`, `governance`, `research`, `spike`, `design`. The substrate was pre-designed for this lifecycle. Documents are bound to a task by frontmatter `task_id` (adze has doc-to-project attach, not doc-to-task).

## The quality gate (ports verbatim, project-agnostic)

Six read-only reviewers spawned in parallel (agents 6 to 11). The **inline-diff substitution contract** is the load-bearing mechanism and ports unchanged: the orchestrator inlines the diff and the relevant function + caller bodies into each reviewer prompt, because read-only reviewers that try to Read files burn their turn budget and emit nothing. Reviewer set varies by workflow type (standard = all six; lightweight = code-reviewer + code-smells + test-reviewer + self-containment; docs-only = code-reviewer + self-containment). Findings consolidate (dedup by file:line, keep higher severity) and feed the fix cycle (max 3 cycles, then stop and ask). No outstanding `[GOVERNANCE]` before the commit gate passes.

## Build phasing

**Phase 1: core tackle lifecycle end to end.**
- Agents 1 to 11; `commands/tackle.md`; `main` routing for `tackle`; the four new seeds; the adze state model; the quality gate with the inline-diff contract.
- Done when: a real adze task can be tackled to a commit, with the gate running and all state persisted in adze.

**Phase 2: full lifecycle parity.**
- documentarian (agent 12) + voice-stylist (agent 13); `brainstorm` / `refine` / `verify` phase commands; telemetry as adze docs; the adze-repo link enforced across docs.
- Done when: the other intents work and output is voiced + documented.

**Phase 3: meta-tooling.**
- team-manager (agent 14) + a `team-audit` command; `swarm-coordination` reference.
- Done when: roster tuning + audit work against adze-stored telemetry.

## Open Questions (verify at build time)

- [ ] Confirm the real adze MCP schema for **task tagging** (`kind:` on tasks, `group_key`) before relying on it; the internals digest flagged a docs-vs-usage ambiguity.
- [ ] Confirm the **adze MCP server is available** in the build/dev session so the lifecycle can be tested end to end.
- [ ] Confirm **push auth** to `ironmoose/marketplace` (clone worked via the `github-personal` SSH alias).
- [ ] Decide whether to add new `kind:` tags (`plan`, `task-log`, `metrics`) or reuse existing ones.
- [ ] Pin the exact voice-stylist read path (user-profile `## Voice` section vs the `voice-default` seed).

## Out of scope

- PR review (owned by `pr-review`).
- Synqly / external-integration scaffolding.
- Silent or default writes under `~/.claude/`. The wizard's optional SessionStart hook is the one path that may write there, and only when the user explicitly picks the all-projects install; the default is no hook.
- Reviving tab-workflow.

## Decisions Locked (recap)

Full port; tab deprecated; read-target-conventions; PR review stays in pr-review (no re-reviewer here); telemetry in adze; team-manager Phase 3; state in adze; docs link to adze; no phantom agents under `agents/`; optional opt-in SessionStart hook (this-project + all-projects scopes).
