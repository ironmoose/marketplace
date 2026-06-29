# adze-bonch Phase 1: Tackle Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `adze-bonch` a working `/adze-bonch:tackle` lifecycle (research, plan, implement, test, multi-agent quality gate, fix cycles, commit gate) ported from pt-doots, adze-native, with all state in adze.

**Architecture:** The existing `main` router gains a live `tackle` route into a new `commands/tackle.md` orchestrator. The orchestrator delegates to 11 ported sub-agents and reads spawn templates from `reference/agent-prompts.md`. Workflow conventions are seeded into adze as canonical docs; per-task state (research, plan, progress) is written as adze documents. Agents read the target project's own conventions at runtime rather than carrying a baked ruleset.

**Tech Stack:** Claude Code plugin (markdown agents + commands), the adze MCP server (`mcp__adze__*`), `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**Source of truth for the port:** the pt-doots plugin at `/Users/parker/workspaces/plextrac/pt-doots/` (agents, commands, reference). Each agent/command task names the exact source file to adapt.

## Global Constraints

These apply to every task. Each task's requirements implicitly include this section.

- **adze is the substrate.** Unit of work is an adze task inside an adze project. No local per-task files; state is adze documents bound to the task via frontmatter `task_id`.
- **State document kinds:** research = `kind:research`; plan = `kind:plan`; progress = `kind:task-log` (mirrors the existing `kind:session-log`); review findings = `kind:review-finding` / `kind:qa-finding`; verification failures = `kind:verification-failure`; governance = `kind:governance`. Tag docs `concurrency:strict` where appended to; obey the 60s re-read rule.
- **Standards model: read, do not bake.** Reviewer / implementer / researcher agents read the target repo's `CLAUDE.md` (and nested ones) plus the adze project context for conventions. No PlexTrac (or any fixed) ruleset baked into agent prompts.
- **Strip all company couplings:** no Jira / ticket-key `IO-XXXX` model, no Synqly, no Confluence MCP, no hardcoded repo lists, no `gh` binary paths, no `~/.jira*` creds, no PlexTrac voice signature. A passing file has zero hits for: `plextrac|jira|synqly|confluence|atlassian|product-core-|product-services-|IO-[0-9]|paul\.parker@`.
- **Self-contained + voice:** no em-dashes anywhere; no leaked internal labels or local-notes paths in any shipped file.
- **Link the adze repo:** every README / CLAUDE.md / seeded discipline doc links to `https://github.com/4lt7ab/adze`.
- **Model tiers:** keep pt-doots's `haiku` / `sonnet` / `opus` frontmatter aliases per agent (see the roster table in the spec).
- **No phantom agents:** only real agent definitions live under `agents/`. Any performance/review log goes under `reference/`, never `agents/`.
- **Named protocols already exist** as adze-bonch seeds. Agents emit the literal tokens `[GOVERNANCE]` / `[PLAN-TEST-CONFLICT]` / `[SCOPE-EXPANSION]`; the orchestrator scans output for them.
- **Commits:** repo-local identity is already pinned to `Parker <airete@gmail.com>`. Conventional-commit messages. Each task ends with a commit. Do NOT push (push is gated, see Pre-Push Gates).

## The genericization transformation (applied to every ported agent)

Each agent task = "adapt pt-doots source file X into `agents/<name>.md`" by applying this ruleset:

1. **Frontmatter:** keep `name`, `description`, `model` (tier per spec roster), `tools` from the source; rename any `PT_DOOTS_*` env var to `ADZE_BONCH_*`. Drop Confluence MCP tools from `tools`.
2. **Delete** every PlexTrac-specific block (the baked standards checklist, the 4-repo codebase guide, repo routing heuristics, Synqly/Kysely/BullMQ/CK-Editor/Pydantic specifics, the `parser-comparison-tool` path).
3. **Replace** the deleted standards block with the shared rule from `reference/conventions.md`: "Read the target repo's `CLAUDE.md` (root + nearest nested) and the adze project context; enforce THOSE conventions. If none exist, fall back to general good-practice for the detected language/stack."
4. **Remap** the unit of work: Jira ticket to adze task; the source plugin's local per-task files to the adze state documents named in Global Constraints.
5. **Keep verbatim** (these are project-agnostic): the agent's output sentinels (e.g. `REVIEW: clean`), the Verify-Before-Flag discipline, the read-only constraints, the worktree-isolation rules, the protocol-emission behavior, and (for reviewers) the "your context is already complete; do NOT use the Read tool" clause.
6. **Verification grep** (every ported file): `grep -ciE '<coupling regex above>'` is 0; `grep -cP '\x{2014}'` is 0.

---

### Task 1: Reference docs (conventions + spawn templates)

**Files:**
- Create: `plugins/adze-bonch/reference/conventions.md`
- Create: `plugins/adze-bonch/reference/agent-prompts.md`
- Source to adapt: `/Users/parker/workspaces/plextrac/pt-doots/reference/agent-prompts.md`

**Interfaces:**
- Produces: `reference/conventions.md` (the read-target-standards rule, referenced by all builder/reviewer agents) and `reference/agent-prompts.md` (spawn templates with `{INLINED_DIFF}` and `{INLINED_FUNCTION_BODIES}` placeholders and the inline-diff substitution contract). The tackle command (Task 8) reads `agent-prompts.md`.

- [ ] **Step 1:** Create `reference/conventions.md` stating the standards model: how an agent locates and reads the target repo's `CLAUDE.md` (root + nearest nested to the changed files) and the adze project context, the precedence (session override > project workflow_overrides > target-repo CLAUDE.md > general good-practice), and the instruction to enforce those rules rather than any baked set. Link the adze repo.
- [ ] **Step 2:** Create `reference/agent-prompts.md` by adapting the pt-doots source: keep every spawn template and the full inline-diff substitution contract (diff + partial-function bodies + MANDATORY caller bodies on signature/rename changes; test-reviewer gets test + production files; >30k-token diffs split into parallel chunks). Replace ticket / local-notes / PlexTrac references per the transformation ruleset.
- [ ] **Step 3:** Verify couplings + em-dashes. Run: `grep -ciE 'plextrac|jira|synqly|confluence|atlassian|product-(core|services)-|IO-[0-9]' plugins/adze-bonch/reference/*.md; grep -cP '\x{2014}' plugins/adze-bonch/reference/*.md`. Expected: all 0.
- [ ] **Step 4:** Confirm the inline-diff contract survived. Run: `grep -c 'INLINED_DIFF\|INLINED_FUNCTION_BODIES' plugins/adze-bonch/reference/agent-prompts.md`. Expected: >= 2.
- [ ] **Step 5:** Commit. `git add plugins/adze-bonch/reference && git commit -m "feat(adze-bonch): add port reference docs (conventions + spawn templates)"`

### Task 2: Seed the lifecycle discipline docs

**Files:**
- Create: `plugins/adze-bonch/seeds/workflow.md` (REPLACE the existing v0.1.0 stub workflow seed with the lifecycle version; preserve its lookup-chain + conventions content, add the tackle pipeline)
- Create: `plugins/adze-bonch/seeds/progress-format.md`
- Create: `plugins/adze-bonch/seeds/branch-naming.md`
- Sources: `/Users/parker/workspaces/plextrac/pt-doots/reference/{workflow,progress-format,branch-naming}.md`

**Interfaces:**
- Produces: three canonical seed docs in authoritative-doc shape (versioned title, dated header, TL;DR, Open Questions, Decisions Locked). `workflow.md` defines the tackle pipeline steps, the workflow types (standard / lightweight / docs-only / custom), the verification loop (max 3 fix cycles), and the commit gate. `progress-format.md` defines the `kind:task-log` document shape. `branch-naming.md` defines `<short-kebab-desc>` branch names derived from the adze task title.

- [ ] **Step 1:** Write `seeds/workflow.md` adapting the pt-doots workflow into the adze pipeline; remap notes-files to the adze state docs and the Jira key to the adze task. Keep the existing seed's lookup-chain and five-conventions content so the upgrade path is additive.
- [ ] **Step 2:** Write `seeds/progress-format.md` describing the `kind:task-log` doc: dated append entries, `task_id` frontmatter, `concurrency:strict`, synchronous appends, the "what changed / next / decisions" entry shape.
- [ ] **Step 3:** Write `seeds/branch-naming.md`: derive `<kebab-summary>` from the adze task title; branch from the repo default; no ticket prefix unless the project's `workflow_overrides` sets one.
- [ ] **Step 4:** Verify shape + couplings. Run the coupling/em-dash greps from Task 1 step 3 against `seeds/*.md` (expect 0), and confirm each new seed has a `TL;DR` and `Decisions Locked` line (`grep -l 'Decisions Locked' seeds/workflow.md seeds/progress-format.md seeds/branch-naming.md`).
- [ ] **Step 5:** Commit. `git commit -m "feat(adze-bonch): seed lifecycle discipline docs (workflow, progress-format, branch-naming)"`

### Task 3: Routing agents (scrum-master, researcher)

**Files:**
- Create: `plugins/adze-bonch/agents/scrum-master.md`, `plugins/adze-bonch/agents/researcher.md`
- Sources: pt-doots `agents/scrum-master.md`, `agents/researcher.md`

**Interfaces:**
- Produces: `scrum-master` (haiku, no tools) returns a `WORKFLOW PLAN` (type + ordered agent steps + flags) on its first turn from generic complexity/risk signals and the task's `kind:` tags. `researcher` (sonnet, Read/Write/Grep/Glob, NO Confluence MCP) explores the target repo, reads its `CLAUDE.md`, and returns a `RESEARCH SUMMARY`; the orchestrator persists it as a `kind:research` adze doc.

- [ ] **Step 1:** Port `scrum-master.md` per the transformation ruleset; replace repo-routing heuristics with generic complexity/risk classification; keep the 1-turn / first-turn-output behavior and the four workflow types.
- [ ] **Step 2:** Port `researcher.md`; drop the PlexTrac codebase guide and Confluence tools; add the read-target-conventions rule from `reference/conventions.md`; keep the structured `RESEARCH SUMMARY` output and read-only stance.
- [ ] **Step 3:** Validate frontmatter. Run: `for f in scrum-master researcher; do head -8 plugins/adze-bonch/agents/$f.md; done` and confirm `name`, `description`, `model` present and `tools` excludes any `confluence`.
- [ ] **Step 4:** Coupling + em-dash grep (expect 0) over the two files.
- [ ] **Step 5:** Commit. `git commit -m "feat(adze-bonch): port scrum-master + researcher agents"`

### Task 4: Builder agents (implementer, developer)

**Files:**
- Create: `plugins/adze-bonch/agents/implementer.md`, `plugins/adze-bonch/agents/developer.md`
- Sources: pt-doots `agents/implementer.md`, `agents/developer.md`

**Interfaces:**
- Produces: `implementer` (sonnet) with the Plan-Surface lock and the three protocols, worktree-isolated, returns `IMPLEMENTATION COMPLETE` + Plan Surface / Deviations / Forbidden-Pattern Audit. `developer` (sonnet) the looser opt-in variant. Both read the target repo conventions. Env override renamed to `ADZE_BONCH_DEV_MODE`.

- [ ] **Step 1:** Port `implementer.md`; keep the Plan-Surface lock, `[SCOPE-EXPANSION]` / `[PLAN-TEST-CONFLICT]` / `[GOVERNANCE]` emission, no-removing-exports rule, worktree TARGET-vs-WORKTREE branch split; swap baked standards for the conventions rule; remap the local-notes and ticket model.
- [ ] **Step 2:** Port `developer.md` similarly (no Plan-Surface lock by design); rename `PT_DOOTS_DEV_MODE` to `ADZE_BONCH_DEV_MODE`.
- [ ] **Step 3:** Validate frontmatter (`model`, `tools` include Read/Write/Edit/Bash/Glob/Grep) for both.
- [ ] **Step 4:** Coupling + em-dash grep (expect 0); confirm the three protocol tokens appear in `implementer.md` (`grep -c '\[SCOPE-EXPANSION\]\|\[PLAN-TEST-CONFLICT\]\|\[GOVERNANCE\]' plugins/adze-bonch/agents/implementer.md` >= 3).
- [ ] **Step 5:** Commit. `git commit -m "feat(adze-bonch): port implementer + developer agents"`

### Task 5: test-writer agent

**Files:**
- Create: `plugins/adze-bonch/agents/test-writer.md`
- Source: pt-doots `agents/test-writer.md`

**Interfaces:**
- Produces: `test-writer` (sonnet) writes co-located tests in the target repo's framework (detected from the repo, not baked), runs targeted tests, returns `TEST WRITER REPORT`. Never touches production code.

- [ ] **Step 1:** Port `test-writer.md`; replace the baked framework list with "detect the target repo's test framework + patterns from its config and neighboring tests"; keep the standard-vs-TDD modes and the report shape.
- [ ] **Step 2:** Validate frontmatter; coupling + em-dash grep (expect 0).
- [ ] **Step 3:** Commit. `git commit -m "feat(adze-bonch): port test-writer agent"`

### Task 6: Quality-gate reviewers A (code-reviewer, code-smells-reviewer, test-reviewer)

**Files:**
- Create: `plugins/adze-bonch/agents/{code-reviewer,code-smells-reviewer,test-reviewer}.md`
- Sources: same-named pt-doots `agents/*.md`

**Interfaces:**
- Produces: three read-only reviewers (sonnet, Read/Grep/Glob) that consume `{INLINED_DIFF}` + `{INLINED_FUNCTION_BODIES}` and emit their sentinels (`REVIEW: clean`, `SMELLS: clean`, `TESTS: clean`). `code-reviewer` enforces the target repo's `CLAUDE.md`; `test-reviewer` requires test + production code inlined together.

- [ ] **Step 1:** Port `code-reviewer.md`; replace the PlexTrac standards checklist with "enforce the target repo's CLAUDE.md conventions (read them); every finding cites the specific rule"; keep Verify-Before-Flag and the do-NOT-Read clause.
- [ ] **Step 2:** Port `code-smells-reviewer.md` (Fowler catalog is generic; remove language-locked asides or make them stack-aware) and `test-reviewer.md` (keep the "would this test fail if prod broke?" core and the need-prod-code rule).
- [ ] **Step 3:** Validate frontmatter (all `Read, Grep, Glob`, read-only); coupling + em-dash grep (expect 0).
- [ ] **Step 4:** Confirm each retains its do-NOT-Read clause (`grep -il 'do NOT use the Read tool\|context is already complete' agents/code-reviewer.md agents/code-smells-reviewer.md agents/test-reviewer.md`).
- [ ] **Step 5:** Commit. `git commit -m "feat(adze-bonch): port quality-gate reviewers (code, smells, tests)"`

### Task 7: Quality-gate reviewers B (acceptance-qa, edge-case-qa, self-containment-reviewer)

**Files:**
- Create: `plugins/adze-bonch/agents/{acceptance-qa,edge-case-qa,self-containment-reviewer}.md`
- Sources: same-named pt-doots `agents/*.md`

**Interfaces:**
- Produces: `acceptance-qa` (haiku) verifies each criterion from the adze task description (PASS/PARTIAL/FAIL + evidence); `edge-case-qa` (sonnet) checks generic boundary/null/race/async dimensions reading the target stack; `self-containment-reviewer` (sonnet) flags leaked adze doc ids, internal labels, and private-notes refs in committed text.

- [ ] **Step 1:** Port `acceptance-qa.md`; source criteria from the adze task description instead of a Jira AC field; keep PASS/PARTIAL/FAIL + Verify-Before-Flag.
- [ ] **Step 2:** Port `edge-case-qa.md`; drop the PlexTrac-specific edge list, keep the generic dimensions, add "read the target stack to know what is risky."
- [ ] **Step 3:** Port `self-containment-reviewer.md`; retarget its leak patterns to this world (adze doc ids, internal `[A-Z][0-9]` design labels, local-notes paths, person names); keep it read-only and the rewrite-suggestion output.
- [ ] **Step 4:** Validate frontmatter; coupling + em-dash grep (expect 0).
- [ ] **Step 5:** Commit. `git commit -m "feat(adze-bonch): port quality-gate reviewers (acceptance, edge-case, self-containment)"`

### Task 8: tackle command + main routing

**Files:**
- Create: `plugins/adze-bonch/commands/tackle.md`
- Modify: `plugins/adze-bonch/commands/main.md` (Step 5 routing table: replace the `tackle` placeholder row with a live route)
- Source: pt-doots `commands/pt-doots.md` + `reference/workflow.md`

**Interfaces:**
- Consumes: the seeds (Task 2), the reference docs (Task 1), and all 11 agents (Tasks 3-7).
- Produces: `/adze-bonch:tackle` running the pipeline: load discipline + resolve project (reuse "Same as `/adze-bonch:main` Steps 0-2"), scrum-master route, researcher (persist `kind:research` doc), plan with the user (persist `kind:plan` doc), create branch, implement, test-writer, the parallel quality gate using the inline-diff contract from `reference/agent-prompts.md`, fix cycles (max 3), the commit gate, handoff. Progress persists synchronously to a `kind:task-log` doc.

- [ ] **Step 1:** Write `commands/tackle.md` opening with "Same as `/adze-bonch:main` Steps 0-2", then the ported pipeline. The orchestrator (not the reviewers) reads files and inlines diffs + caller bodies into reviewer prompts per the contract. State writes use the adze `documents_create` + `documents_attach` pair with the kinds from Global Constraints.
- [ ] **Step 2:** Edit `main.md` Step 5: change the `tackle X / work on X / implement` row from the NOT-SHIPPED placeholder to "route to `/adze-bonch:tackle`, passing the user's message as args."
- [ ] **Step 3:** Coupling + em-dash grep over both files (expect 0); confirm `tackle.md` references the quality gate and the commit gate (`grep -c 'commit gate\|quality gate' commands/tackle.md` >= 2).
- [ ] **Step 4:** Routing read-check: confirm `main.md` Step 5 now points `tackle` at the command and no longer says "NOT SHIPPED" for that row.
- [ ] **Step 5:** Commit. `git commit -m "feat(adze-bonch): add tackle orchestrator and wire main routing"`

### Task 9: setup wizard seeds the new discipline docs

**Files:**
- Modify: `plugins/adze-bonch/commands/setup.md` (Step 2 seed loop: filename-to-`kind:` mapping + `canonical_seeds` entries)
- Modify: `plugins/adze-bonch/seeds/bootstrap-state-template.md` (add the new seeds to the `canonical_seeds` array)

**Interfaces:**
- Consumes: the seed files from Task 2.
- Produces: a fresh `/adze-bonch:setup` that bootstraps `workflow.md` (`kind:workflow`), `progress-format.md` (`kind:progress-format`), `branch-naming.md` (`kind:branch-naming`) into adze with `provenance:canonical` + `seed_hash`; the upgrade branch re-seeds them on drift automatically.

- [ ] **Step 1:** Add the three filename-to-`kind:` rows to setup Step 2's mapping table; add their `canonical_seeds` entries to both setup and the bootstrap-state template.
- [ ] **Step 2:** Coupling + em-dash grep over `setup.md` (expect 0); confirm the three new kinds appear (`grep -c 'kind:workflow\|kind:progress-format\|kind:branch-naming' commands/setup.md` >= 3).
- [ ] **Step 3:** Commit. `git commit -m "feat(adze-bonch): seed lifecycle docs in setup wizard"`

### Task 10: setup wizard optional SessionStart hook step

**Files:**
- Modify: `plugins/adze-bonch/commands/setup.md` (new optional step after Discoverability)

**Interfaces:**
- Produces: an opt-in wizard step offering: (a) no hook (default), (b) this-project (`<project>/.claude/settings.json`), (c) all-projects (`~/.claude/settings.json`). Writes are surgical merges into a delimited `adze-bonch` block, idempotent, removable. The hook runs the discipline load + status (the SessionStart analog of `main` Step 0).

- [ ] **Step 1:** Write the step: prompt the three choices; on (b)/(c), read any existing settings.json, merge a `hooks.SessionStart` entry inside delimited markers, never clobber; record the chosen path in bootstrap-state; on (a), do nothing. State the all-projects choice is the only sanctioned `~/.claude/` write.
- [ ] **Step 2:** Idempotency + safety read-check: confirm the step re-reads before writing and uses delimited markers (`grep -c 'BEGIN adze-bonch\|END adze-bonch' commands/setup.md` >= 2); coupling + em-dash grep (expect 0).
- [ ] **Step 3:** Commit. `git commit -m "feat(adze-bonch): optional SessionStart hook step in setup"`

### Task 11: plugin metadata, docs, phantom-agent guard

**Files:**
- Modify: `plugins/adze-bonch/.claude-plugin/plugin.json` (version bump), `plugins/adze-bonch/README.md`, `plugins/adze-bonch/CLAUDE.md`, root `README.md`, `.claude-plugin/marketplace.json` (adze-bonch description + version)

**Interfaces:**
- Produces: docs that describe the new `tackle` lifecycle + the 11 agents, link the adze repo, and a clean `agents/` dir with no stray non-agent `.md`.

- [ ] **Step 1:** Bump `plugin.json` and the marketplace.json adze-bonch entry version; update descriptions to mention the lifecycle.
- [ ] **Step 2:** Update adze-bonch `README.md` + `CLAUDE.md`: new commands/agents, the read-target-conventions standards model, the adze state kinds, the optional hook; ensure the adze repo link is present. Update root `README.md`'s adze-bonch row.
- [ ] **Step 3:** Phantom-agent guard: confirm `agents/` contains only the 11 real agent files plus nothing else (`ls plugins/adze-bonch/agents` shows no `reviews/` dir, no logs, no `.gitkeep` once populated).
- [ ] **Step 4:** Adze-link check: `grep -rl 'github.com/4lt7ab/adze' plugins/adze-bonch/README.md plugins/adze-bonch/CLAUDE.md README.md` returns all three; coupling + em-dash grep over changed docs (expect 0).
- [ ] **Step 5:** Commit. `git commit -m "docs(adze-bonch): document tackle lifecycle, bump version, link adze"`

### Task 12: End-to-end dogfood + Phase 1 done-check

**Files:** none (integration verification)

**Interfaces:**
- Consumes: everything above. This is the Phase 1 acceptance gate.

- [ ] **Step 1:** Reload the plugin (`claude plugin marketplace update ironmoose-marketplace` against the local checkout, or restart) and confirm the agent list shows exactly the 11 new `adze-bonch:*` agents and NO phantom `adze-bonch:reviews:*`.
- [ ] **Step 2:** Confirm the adze MCP server is reachable in the session (`mcp__adze__projects_list`); if not, document the `~/.claude.json` stanza and stop here with a note.
- [ ] **Step 3:** Create a scratch adze task in a throwaway project, run `/adze-bonch:tackle` on it against a small target repo, and walk the full pipeline.
- [ ] **Step 4:** Verify state landed in adze: a `kind:research` doc, a `kind:plan` doc, and a `kind:task-log` doc exist for the task; the quality gate ran (reviewer findings captured); the commit gate blocked until findings were resolved.
- [ ] **Step 5:** Record the dogfood result as a `kind:task-log` entry. Done when: a real adze task can be tackled end to end to a commit, with the gate running and state persisted in adze.

---

## Pre-Push Gates (run before any `git push`)

1. **Documentation sweep.** Every `CLAUDE.md` and `README.md` touched or implied by this work is updated and accurate: root `README.md`, `plugins/adze-bonch/README.md`, `plugins/adze-bonch/CLAUDE.md`, `.claude-plugin/marketplace.json`. Each links `https://github.com/4lt7ab/adze`. No stale "v0.1.0 / lifecycle not shipped" language remains.
2. **Identity.** `git log` on the branch shows every commit authored by `Parker <airete@gmail.com>`, never the work identity. Push via the `github-personal` remote to the ironmoose account.

## Out of scope (later phases)

- Phase 2: documentarian + voice-stylist agents; `brainstorm` / `refine` / `verify` phase commands; telemetry as adze docs.
- Phase 3: team-manager agent + `team-audit` command; swarm-coordination.
- PR review stays in the existing `pr-review` plugin (`re-reviewer` is not ported here).
