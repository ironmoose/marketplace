# Adze Workflow (v0.2.0)

*Authoritative as of 2026-06-30. Supersedes v0.1.0 stub (preserve the old doc in adze for its D-series decision trail). Built on the [adze](https://github.com/4lt7ab/adze) substrate.*

This is the canonical "how to work in adze" doc. v0.2.0 fills in the tackle pipeline (Steps 0-6), the workflow types, the verification loop, and the commit gate. The v0.1.0 stub shipped deliberately per D2.

## TL;DR

- Synchronous decision persistence (Rule 1 of the discipline doc).
- Concept-aligned projects, not repo-aligned (D7).
- `kind:` tags carry task type (D8).
- Lookup chain: session override > project workflow_overrides > user profile > canonical (D6).
- Two adze projects exist for plugin infra: "adze-bonch reference" and "adze-bonch user profiles" (D9).

## Project shape

v0.1.0 treats every project as a flat work-stream. No `shape:` tag, no `repo:` tag, no project-level typed metadata. Adze projects can't carry tags in the current schema, so the plugin works with what FTS over project title gives us.

The earlier design proposed `shape:work-stream` / `shape:ticket` for project type and `repo:<name>` (multi-tag) for cross-repo provenance. Both were parked per D17 until adze supports project tagging or another encoding lands. Two research docs in adze hold the unshipped design:

- `01KRANRSBMCPZHQ31K2VQ78KTW` (upstream C-path pitch for project tags)
- `01KRANSF16K4VHFTMB5ZPNDN1G` (hybrid encoding via doc-tag oracle)

v0.3.0 may revive structured metadata once one of those lands.

## Task kinds

The `kind:` namespace replaces the earlier "classifier" idea (D8). A task can carry multiple kinds. Common values:

- `kind:research`
- `kind:plan`: approved implementation plan bound to a task; consumed by the implementer and test-writer
- `kind:bug`
- `kind:feature`
- `kind:chore`
- `kind:docs`
- `kind:test`
- `kind:spike`
- `kind:design`
- `kind:task-log`: progress log bound to a task; see [progress-format.md](progress-format.md)
- `kind:review-finding`
- `kind:verification-failure`
- `kind:qa-finding`
- `kind:governance`: flagged via the [GOVERNANCE] protocol

`group_key` stays reserved for phase or area (e.g. `group_key:auth`, `group_key:open-questions`, `group_key:bootstrap`). Don't double-purpose it for kind.

## Workflow types

Four types. The scrum-master returns one at Step 0.5:

| Type | When to use | Quality gate |
|------|-------------|-------------|
| standard | New feature, bug fix, or anything with tests | 6 reviewers in parallel |
| lightweight | Small chore, config tweak, or low-risk refactor | 4 reviewers |
| docs-only | Documentation update only | code-reviewer + self-containment-reviewer |
| custom | Scrum-master specifies the reviewer set | Per scrum-master plan |

`Documentation` and `TDD` are orthogonal flags applied on top of any workflow type. `docs-only` implies `Documentation: yes`.

## Workflow phases

| Phase | Description | v0.2.0 status |
|-------|-------------|---------------|
| brainstorm | idea to draft project + tasks | not shipped (manual via projects_create) |
| refine | walk tasks, flesh out plan + acceptance | not shipped |
| tackle | dispatch implementer agent + review gate | shipped; see Steps 0-6 below |
| save | audit recent turns, capture decisions | shipped: `/adze-bonch:save` |
| status | read-only snapshot | shipped: `/adze-bonch:status` |
| verify | lint/typecheck/test loop | shipped: `/adze-bonch:verify` |

---

## Step 0: Load Context (main context)

Run at the start of every tackle session:

1. Read the adze task (title, body, state, acceptance criteria).
2. Check git state (branch, uncommitted changes, commits ahead of default).
3. Query for a `kind:task-log` adze doc linked to this task. If one exists, read it to find the last session state.
4. Show status summary to user:
   ```
   ## {task title} - Session Restore

   Branch: `{branch}` ({N} commits ahead of default)
   Last session: {date from task-log doc}
   Completed: {list completed steps}
   Next: {what comes next}
   Uncommitted changes: {yes/no}
   ```
5. Append a session-start entry to the task-log doc (see [progress-format.md](progress-format.md)).

If no task-log exists, this is the first session for this task. Proceed to Step 0.5.

---

## Step 0.5: Route Workflow (main context)

Spawn the scrum-master agent with the task's title, description, and acceptance criteria.

It returns a structured WORKFLOW PLAN:
```
WORKFLOW PLAN

Workflow: standard | lightweight | docs-only | custom
Documentation: yes | no
TDD: yes | no
Rationale: {why this workflow}
```

Show the recommendation to the user. They can override.

Append to task-log: `Workflow: {type} ({rationale})`

---

## Step 1: Research (sub-agent)

Check first: if the project already has a `kind:research` adze doc tagged to this task, read it and skip to Step 2.

Otherwise:
1. Spawn the researcher agent with the task content (title, body, acceptance criteria, repo context).
2. The researcher explores the codebase, writes a `kind:research` adze doc bound to the task, and returns a 2-3 paragraph summary.
3. Main context receives only the summary.

Append to task-log: `Research complete. Summary: {1-2 sentences}`

---

## Step 2: Plan with user (main context)

Stays in main because it requires user interaction.

1. From the research summary, propose an approach and steps.
2. Each plan step should be self-contained enough for a sub-agent: exact file path(s), what to change, "done when" condition.
3. User confirms or adjusts.
4. Write the approved plan to a `kind:plan` adze doc bound to the task.

Append to task-log: `Plan approved. {N} steps. Approach: {1 sentence}`

---

## Step 3: Create Branch (main context)

See [branch-naming.md](branch-naming.md) for the naming pattern.

- Branch from the repo's default branch. Confirm with the user if the repo uses a non-standard base branch.
- Create AND check out in one step: `git switch -c {branch}`.
- If the branch already exists (resuming a prior session): `git switch {branch}` (no `-c`). Confirm with the user before reusing a branch that has commits not in origin.
- The implementer agent verifies it is on the expected branch before making any changes.

Append to task-log: `Branch created: {branch}` (or `Branch resumed: {branch}`)

---

## Step 4: Execute (sub-agents)

### Verification loop

After every code change: run `/adze-bonch:verify`. Max 3 fix cycles per failure category. If still failing after 3 cycles: STOP, ask the user.

```
Implement → Verify → Test → Verify → Review → Fix → Verify → Commit
            ▲ fail              ▲ fail           ▲ fail
            └─ fix ─┘           └─ fix ─┘        └─ fix ─┘
           (max 3x)            (max 3x)          (max 3x)
```

### 4a. Implementation

- Spawn the implementer agent with the relevant plan steps inlined into its prompt (paste the full step text; never pass the `kind:plan` doc id and tell the agent to fetch it, since sub-agents have no adze tools).
- One agent per logical chunk, or one for the whole plan if small.
- Returns: files changed, descriptions, any [GOVERNANCE] items.
- If it has questions: orchestrator asks the user, then spawns a new agent with the answers.
- Run `/adze-bonch:verify`. Fix failures (max 3 cycles).

**Parallel opportunity:** if the plan has independent chunks (different files or modules), launch implementation agents in parallel.

Append to task-log: `Implementation complete. Files: {list}. Verification: {pass/fail}`

### 4b. Tests

- Spawn the test-writer agent with the relevant plan steps and the implementation diff inlined into its prompt (never pass the plan doc id and tell the agent to fetch it; sub-agents have no adze tools).
- Returns: test files created, pass/fail status.
- Run `/adze-bonch:verify`. Fix failures (max 3 cycles).

Append to task-log: `Tests written. Files: {list}. Verification: {pass/fail}`

### 4c. Quality Gate (MANDATORY)

**Never skip this step, even for small changes or when resuming a session.**

**Standard workflow** (spawn all six in parallel):
- code-reviewer: reads the repo's CLAUDE.md and enforces its standards
- acceptance-qa: verifies acceptance criteria from the adze task
- edge-case-qa: boundary conditions, failure modes
- code-smells-reviewer: design quality, coupling, duplication
- test-reviewer: test quality (hollow assertions, over-mocking, bloat)
- self-containment-reviewer: committed artifacts leak no private or local-only context

**Lightweight workflow** (spawn only):
- code-reviewer
- code-smells-reviewer
- test-reviewer (only if the changeset includes test files)
- self-containment-reviewer

**Docs-only workflow** (spawn only):
- code-reviewer (verifies doc changes for accuracy and consistency)
- self-containment-reviewer

**Custom workflow:** follow the reviewer set the scrum-master included in its WORKFLOW PLAN.

Consolidate all findings from all reviewers before proceeding.

Append to task-log: `Quality gate complete. Code Review: {N}. Acceptance QA: {pass/fail or skipped}. Edge Case QA: {N or skipped}. Code Smells: {N}. Test Review: {N or skipped}. Self-Containment: {N}.`

### 4d. Fix Findings

Only if the quality gate has actionable findings.

- Spawn the implementer agent in fix-cycle mode with the consolidated findings.
- Returns: fixes applied, any deferred.
- Run `/adze-bonch:verify`. Fix failures (max 3 cycles).

Append to task-log: `Findings fixed. {N} applied, {N} deferred. Verification: {pass/fail}`

### 4e. Documentation (DEFERRED -- Phase 2, not built)

The dedicated documentation pass and its `documentarian` agent are Phase 2 and are not built in v0.2.0. Do NOT spawn a documentation agent from this pipeline; the agent does not exist yet.

In v0.2.0, documentation is handled inline: the implementer creates or updates nested CLAUDE.md files at module level as it works, and the orchestrator updates repo READMEs and public-surface doc comments during the plan steps when the change affects them. The scrum-master's `Documentation: yes|no` flag is recorded for routing, but it does not trigger a separate agent in this build.

When the documentarian ships (Phase 2), this step will spawn it for the priority order: nested CLAUDE.md files, then repo READMEs, then inline doc comments on new or modified public surfaces.

---

## Step 5: Commit (main context)

### Commit gate (ALL must be true):
- [ ] Quality gate ran (Step 4c)
- [ ] Findings fixed or deferred (Step 4d)
- [ ] Verification passed after the most recent code change
- [ ] All plan steps implemented
- [ ] No outstanding [GOVERNANCE] items unaddressed

Show checklist to user before committing:
```
## Commit Gate - {task title}

- [x] Quality gate: ran, {N} total findings -> {N} fixed, {N} deferred
- [x] Verification: lint OK, typecheck OK, tests OK
- [x] Plan steps: {N}/{N} complete
- [x] Governance: clear

Ready to commit: `{short description}`
```

Stage relevant files, commit with a conventional-commit message. Never push. Remind the user to push when ready.

Append to task-log: `Committed: {hash} - {description}`

---

## Step 6: Handoff (main context)

Present summary:
```
## {task title} - Complete

Branch: `{branch-name}`
Commit: `{hash}` - {message}
Files changed: {count}
{brief list}

Tests: {count} added/modified
Quality gate: {summary}
Verification: all passing
```

Ask: **"Ready to create a PR? I can use `/create-pr` to push and open a PR with the repo's template."**

Append to task-log: `Handoff complete.` (or `PR created: {url}`)

---

## Sub-agent sequencing

**Can parallelize:**
- Independent plan-step implementations (different files or modules)
- Quality gate reviewers (all six in standard workflow)

**Must be sequential:**
Research → Plan → Branch → Implement → Verify → Test → Verify → Review → Fix → Verify → Commit

---

## References

- Branch naming: [branch-naming.md](branch-naming.md)
- Progress log format: [progress-format.md](progress-format.md)
- Named protocols: [named-protocols.md](named-protocols.md)
- Discipline rules: [discipline.md](discipline.md)

---

## Open Questions

- [ ] Concrete trigger list for the brainstorm flow's "draft project" cutover (when does an idea become a real project?)
- [ ] How tackle handles cross-repo work (worktree per repo vs. single navigation session)
- [ ] Whether refine should spawn research agents automatically for unknowns
- [ ] What "done" means at the project level (status field, or task-completion-derived)
- [ ] Telemetry: per-agent and per-workflow metrics pattern for adze-bonch

## Decisions Locked

- Reference docs LIVE IN adze (D1)
- Two-project bootstrap: adze-bonch reference + adze-bonch user profiles (D9, renamed per D16)
- Concurrency: strict for reference, lax for tasks, with 60s read-cache (D4)
- Discipline rule lives in adze, no `~/.claude/rules/` install (D11)
- Discoverability via safe-path CLAUDE.md trampolines only (D12)
- Single canonical voice ships; others are templates (D13)
- In-flight task state lives in a `kind:task-log` adze doc, not in local per-task files (v0.2.0)
- Max 3 fix cycles per failure category before escalating to the user (v0.2.0)
