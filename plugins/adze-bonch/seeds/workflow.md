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

`Documentation` and `TDD` are orthogonal flags applied on top of any workflow type. Both default to `yes`. `docs-only` implies `Documentation: yes` and `TDD: no`. See Step 0.5 for the exceptions that justify a `no`.

## Workflow phases

| Phase | Description | v0.2.0 status |
|-------|-------------|---------------|
| brainstorm | idea to draft project + tasks | not shipped (manual via projects_create) |
| refine | walk tasks, flesh out plan + acceptance | not shipped |
| tackle | dispatch implementer agent + review gate | shipped; see Steps 0-6 below |
| save | audit recent turns, capture decisions | shipped: `/adze-bonch:save` |
| status | read-only snapshot | shipped: `/adze-bonch:status` |
| verify | lint/typecheck/test loop | not shipped (run the target repo's own verification commands, as defined in its CLAUDE.md) |

---

## Project Pulse

The Project Pulse is the per-project session-resume trailhead: the first thing loaded when you enter a project, and the first thing updated when you save. It answers "where were we, and what is next?" in one glance, so a cold session (or a fresh agent) can pick up the thread without re-reading the whole design log.

**Shape.** One document per project, tagged `kind:pulse` and `provenance:user`, with `concurrency:strict`. It stays lean, three sections only:

- **Where we left off:** the last meaningful state (what just shipped, what is in flight).
- **Next move:** the single most likely next action.
- **Open for user:** questions or decisions waiting on the user.

**When it loads.** `/adze-bonch:main` and `/adze-bonch:status` lead with the Pulse. Before anything else, they resolve the `kind:pulse` doc for the active project, read it, and surface the "next move" so the user can confirm it or switch threads.

**When it is written.** `/adze-bonch:save` updates the Pulse synchronously, via a dedicated `pulse-writer` sub-agent (haiku). Save rewrites the three sections to reflect the state at the moment of the save.

**One per project.** There is exactly one Pulse per project. If a project ever shows two `kind:pulse` docs, halt and resolve the duplicate before writing; never fork the trailhead.

**Transient state only.** The Pulse holds resume state that turns over every session. Stable information (purpose, scope, architecture, locked decisions) lives in `project.context` and the design log, not here. The Pulse points at that stable material rather than duplicating it.

---

## Language detection and conventions-overlay injection

The implementer, the test-writer, and the language-sensitive reviewers (code-reviewer, code-smells-reviewer, test-reviewer, edge-case-qa) are language-neutral skeletons. Their language-specific rules come from a **conventions overlay**: a baseline file the orchestrator resolves by detecting the changed code's language, then names in each spawn prompt. The target repo's own committed `CLAUDE.md` stays authoritative over the overlay; the overlay is the baseline underneath it, never a replacement for it.

This section is the single source of truth for the detection rule. `commands/tackle.md` and `reference/agent-prompts.md` both point here rather than restating it; do not re-specify detection anywhere else.

**When to resolve `LANG`.** As early as the target repo is known, which is Step 3 (branch creation). Resolving there, rather than after implementation, is what gets the overlay to the test-writer at Step 3.5 and the implementer at Step 4a instead of only to the Step 4c reviewers. Revisit it only if the implementer's actual changed-file list later reveals a second language; in that case switch to `mixed` for the quality gate.

### Detect `LANG`

Work from the changed-file list (before one exists, use the plan's file surface), skipping test fixtures and binaries:

1. **By extension:** any `.ts` / `.tsx` / `.js` / `.jsx` means TypeScript; any `.py` means Python.
2. **Confirm or tiebreak on the target repo's own project markers:** `package.json` or `tsconfig.json` means TypeScript; `pyproject.toml`, `setup.py`, or `requirements.txt` means Python.
3. **Mixed:** if both a TypeScript-family extension and `.py` are present, `LANG = mixed`.
4. **Neither:** if the language is neither TypeScript nor Python, there is no overlay. Say so explicitly in the spawn prompt, and the agents fall back to the target repo's own `CLAUDE.md` plus general good practice for the detected stack. Never invent an overlay path that does not exist.

### Overlay path per `LANG`

| `LANG` | Overlay path to inject |
|--------|------------------------|
| TypeScript | `reference/typescript-conventions.md` |
| Python | `reference/python-conventions.md` |
| mixed | both of the above |
| anything else | none; state "no overlay" in the spawn prompt |

Paths are relative to the plugin root.

**Gets the overlay:** implementer, test-writer, code-reviewer, code-smells-reviewer, test-reviewer, edge-case-qa.

**Takes no overlay:** acceptance-qa, self-containment-reviewer, repro-verifier, researcher, scrum-master, pulse-writer. Each of these reasons about task criteria, private-context leaks, or runtime behavior rather than language conventions, so an overlay would add noise without changing its verdict.

**Adding a language later** means adding one `<lang>-conventions.md` file under `reference/` and one row to the table above. Zero agent edits, zero spawn-template edits.

The exact injection block, the wording pasted into each spawn prompt, lives in the Conventions-Overlay Contract in `reference/agent-prompts.md`. It is specified there once and is not duplicated here.

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
   Done when: {task-level Done-condition echoed from the task-log; the anchor for the rest of the run}
   Uncommitted changes: {yes/no}
   ```

   Echo the Done-condition verbatim from the task-log's Step 2 entry. It is what re-anchors a session that resumed after a `/clear`, so never paraphrase it from memory and never leave the line blank when a plan exists.
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

`Documentation` and `TDD` are orthogonal flags that apply on top of any workflow type. Both default to `yes`: `Documentation: yes` unless the task has zero doc surface, and `TDD: yes` (test-first) unless there is no meaningful logic to test first (docs-only, dependency bumps, pure config, mechanical refactors). `docs-only` implies `Documentation: yes` and `TDD: no`.

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

**Planning is interactive: the orchestrator does NOT decide substantive calls solo.** Step 2 is a conversation, not a finished plan you hand over. Surface every substantive judgment call to the user as you hit it, present the real options with a recommendation, and wait for their decision before folding it into the plan. This is the flag-and-wait contract (the one the sub-agents follow) pointed at the orchestrator itself.

MUST be surfaced, never silently resolved:
- Approach forks the research left open (two viable designs, a build-vs-reuse choice)
- Scope calls on anything the task implies but does not pin down (do-now vs defer-and-track vs cut; when you defer, write the requirement onto the owning adze task)
- Anything irreversible or costly (schema or migration shape, a new dependency, a public-contract or API change)
- Any place the acceptance criteria are ambiguous about expected behavior

Do NOT draft a plan with these resolved your way and raise them only if the user presses. If you catch yourself about to just pick one and move on when the user would have a preference, STOP and surface it. Routine mechanics (file naming, obvious test cases, which existing helper to reuse) need no checkpoint; use judgment, and the bar is whether the user would have a preference or be surprised.

### Interview format: one decision per turn

Run planning as an interview, not a briefing. Enumerate the open decisions up front ("4 calls I need from you"), then work them one at a time, in dependency order, easiest-to-unblock last. Do not dump all of them in one message and do not bundle a decision with the next question.

Each decision gets the same five parts, in this order:

1. **What the task asks for**, quoted or closely paraphrased.
2. **What is actually true**, with file:line or command evidence. This is where premise mismatches surface.
3. **The real options**, each with its concrete cost. Include the option you are about to argue against; if an option is not viable, say why rather than omitting it.
4. **A recommendation with an explicit confidence level** (low / medium / high) and the honest caveat that would change it.
5. **The specific thing you need from the user** to proceed.

Then STOP and wait. Do not proceed to the next decision, and do not start building, until that one is answered.

**Ground claims instead of asserting them.** When a recommendation rests on "best practice", fetch the authority (context7, the framework's own docs, the target repo's own committed conventions) and quote it before recommending. Do this proactively on any load-bearing call, not only when challenged. If the user asks "are we following best practices?" or "is that right?", that is a signal you asserted where you should have cited: go check, and report what you find even when it contradicts your recommendation.

**Let evidence move you.** When new information lands mid-interview, say plainly that the earlier recommendation is suspended or revised, and why. A recommendation that survives only because it was already stated is worthless. Re-scoring your own earlier answer stricter is a good sign, not a failure.

**Prefer defer-and-track over silent scope growth.** Adjacent problems found during planning get sorted into do-now / defer-to-a-named-task / cut, and the user makes that call. Write deferred items somewhere durable (a new adze task, or the owning task's body) so they are not lost.

Once every decision is answered, write the `kind:plan` doc and the Done-condition, and confirm both.

Once the plan and the Done-condition are locked, execution goes quiet: the user steps away, and only a genuine flag (a sub-agent flag, a failed verification, the commit gate) interrupts them again.

### Plan output

1. From the research summary, propose an approach and steps.
2. Each plan step should be self-contained enough for a sub-agent: exact file path(s), what to change, "done when" condition (per step).
3. **Derive the task-level Done-condition.** This is distinct from the per-step "done when" above. It is ONE short, explicit statement of what makes the WHOLE task done, read straight off the adze task's acceptance criteria. Keep it lightweight: a short bulleted "Done when:" block, not a spec. This is the single condition acceptance-qa evaluates at Step 4c and the commit gate checks.
4. User confirms the plan AND the Done-condition, or adjusts.
5. Write the approved plan and the "Done when:" block to a `kind:plan` adze doc bound to the task. Echo the same "Done when:" block into the task-log (Step 2 entry) so a post-`/clear` resume re-anchors on it. The `kind:plan` doc is canonical; the task-log copy is a pointer.

**Done-condition format** (top of the `kind:plan` doc, echoed to the task-log):

    ## Done when:
    - {criterion 1: observable and testable}
    - {criterion 2}
    - Verification green (lint + typecheck + tests)

**Scale-down for lightweight and docs-only:** collapse the Done-condition to ONE line. For example "Done when: dependency bumped to X.Y and verification green", or "Done when: README section Y documents the new flag and code-reviewer is clean". Do not manufacture a multi-bullet block when the task has a single observable outcome. Note that acceptance-qa does not run on these two workflows, so their Done-condition is evaluated by code-reviewer plus the commit gate rather than by acceptance-qa.

Append to task-log: `Plan approved. {N} steps. Approach: {1 sentence}. Done when: {1-line restatement or bulleted block}`

---

## Step 3: Create Branch (main context)

See [branch-naming.md](branch-naming.md) for the naming pattern.

- Branch from the repo's default branch. Confirm with the user if the repo uses a non-standard base branch.
- Create AND check out in the same step: `git switch -c {branch}`. The parent repo MUST be on the feature branch before Step 4a spawns the implementer, otherwise the implementer's commit lands on whatever was previously checked out (commonly the default branch).
- If the branch already exists locally (for example a fix cycle resuming from a prior session): `git switch {branch}` with no `-c`. Confirm with the user before reusing a branch that has commits not in `origin/main`.
- The implementer agent verifies it is on the expected branch before making any changes, and fails fast if this step was skipped. That check is a backstop, not a substitute: the orchestrator switches first, the implementer verifies.
- **Resolve `LANG` now.** The target repo is known here, so detect the language and pick the conventions-overlay path or paths per the Language detection and conventions-overlay injection section above, then carry them into the Step 3.5, Step 4a, and Step 4c spawns. Resolving here rather than after implementation is what gets the overlay to the test-writer and the implementer, not just the reviewers.

Append to task-log: `Branch created: {branch}` (or `Branch resumed: {branch}`)

---

## Step 3.5: Write Failing Tests (TDD mode only)

Runs only when the scrum-master returned `TDD: yes` (the default). Under `TDD: no` this step is skipped entirely and the test-writer runs later, at Step 4b, after implementation.

1. Spawn the test-writer agent in TDD mode with the relevant plan steps, the acceptance criteria, and any fixture list inlined. There is no implementation yet: the tests are written against the interface the plan defines, and they SHOULD fail.
   - **Inject the conventions overlay** resolved at Step 3. The test-writer is language-neutral: test framework, file naming, and per-layer testing conventions come from the overlay. Never spawn it without either an overlay path or an explicit "no overlay" statement.
2. Run the target repo's verification (lint, typecheck, tests as defined in its CLAUDE.md) to confirm the red baseline. The new tests are expected to fail here; only unrelated failures count against the fix-cycle budget. If the new tests unexpectedly pass, surface that to the user before proceeding.

Append to task-log: `TDD tests written. Files: {list}. Baseline: failing as expected.`

---

## Step 4: Execute (sub-agents)

**Default sequencing is test-first (TDD).** Unless the scrum-master returned `TDD: no`, the test-writer has already run at Step 3.5: failing tests against the planned interface, confirmed red. Step 4a is where the implementer makes them pass (green), and Step 4b then re-runs verification to confirm they do. Do NOT write implementation first and backfill tests; that code-first-then-backfill habit is exactly what this default prevents. The `4a` / `4b` labels name the two agents (implementer / test-writer), not their run order: under the default the test-writer's real slot is Step 3.5, and only `TDD: no` (docs-only, dependency bump, pure config, no meaningful logic) puts the test-writer at 4b, with tests backfilled after implementation. The loop diagram just below illustrates the generic verify-and-fix mechanic; read its node order as generic rather than as the TDD sequence.

### Verification loop

After every code change: run the target repo's verification (lint, typecheck, tests as defined in its CLAUDE.md). Max 3 fix cycles per failure category. If still failing after 3 cycles: STOP, ask the user.

```
Implement → Verify → Test → Verify → Review → Fix → Verify → Commit
            ▲ fail              ▲ fail           ▲ fail
            └─ fix ─┘           └─ fix ─┘        └─ fix ─┘
           (max 3x)            (max 3x)          (max 3x)
```

**Soft cross-loop budget.** The max-3 cap above is per failure category. Also watch the running total across 4a/4b/4d. If total fix cycles across those three steps exceeds roughly 8, STOP and reassess with the user even if no single failure hit the max-3 cap. A task that needs that many fix cycles usually has a plan or scope problem, not a code problem. Track the current total on the `**Run tally**` line in the task-log (see [progress-format.md](progress-format.md)). Live token and turn metering is intentionally left to the harness and is not estimated here.

### 4a. Implementation

- **By default the failing tests from Step 3.5 already exist** (TDD is the default): implement to make them pass (green). Only under `TDD: no` does 4a run first with no tests yet.
- Spawn the implementer agent with the relevant plan steps inlined into its prompt (paste the full step text; never pass the `kind:plan` doc id and tell the agent to fetch it, since sub-agents have no adze tools).
- **Inject the conventions overlay** resolved at Step 3. The implementer is a language-neutral skeleton; without the overlay it falls back to whatever defaults it happens to carry. Never spawn it without either an overlay path or an explicit "no overlay" statement.
- One agent per logical chunk, or one for the whole plan if small.
- Returns: files changed, descriptions, any [GOVERNANCE] items.
- If it has questions: orchestrator asks the user, then spawns a new agent with the answers.
- Run the target repo's verification (lint, typecheck, tests as defined in its CLAUDE.md). Fix failures (max 3 cycles).

**Parallel opportunity:** if the plan has independent chunks (different files or modules), launch implementation agents in parallel.

Append to task-log: `Implementation complete. Files: {list}. Verification: {pass/fail}`

### 4b. Tests

- **Default (TDD): the test-writer already ran at Step 3.5.** Do NOT spawn it again here. Run verification only, to confirm the failing tests from Step 3.5 now pass.
- Spawn the test-writer agent in standard (test-after) mode at this step ONLY when the scrum-master returned `TDD: no`. Inline the relevant plan steps, the implementation diff, and the conventions overlay resolved at Step 3 (never pass the plan doc id and tell the agent to fetch it; sub-agents have no adze tools).
- Returns (test-after mode): test files created, plus their pass/fail status.
- Run the target repo's verification (lint, typecheck, tests as defined in its CLAUDE.md). Fix failures (max 3 cycles).

Append to task-log: `Step 3.5 tests confirmed green. Verification: {pass/fail}` (TDD mode) or `Tests written. Files: {list}. Verification: {pass/fail}` (test-after mode)

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

**Conventions overlay (all variants):** inject the overlay resolved at Step 3 into the four language-sensitive reviewers only, code-reviewer, code-smells-reviewer, test-reviewer, and edge-case-qa. If the implementer's changed-file list turned out to span two languages, switch `LANG` to `mixed` here and inject both paths. acceptance-qa and self-containment-reviewer take no overlay: they judge task criteria and private-context leaks, neither of which is language-specific.

Consolidate all findings from all reviewers before proceeding. FIRST clear the completion barrier: every dispatched reviewer must have returned a REAL result, not a truncated or empty completion notification. Retrieve any thin result via SendMessage to that agent before consolidating. Do NOT consolidate a partial set; a reviewer whose findings were never read counts as a reviewer that never ran.

Append to task-log: `Quality gate complete. Code Review: {N}. Acceptance QA: {pass/fail or skipped}. Edge Case QA: {N or skipped}. Code Smells: {N}. Test Review: {N or skipped}. Self-Containment: {N}. Total: {N} findings.`

### 4c.5. Repro-Verify (MANDATORY, every workflow)

**Always run this step.** It is what separates a verified finding from a plausible guess, so it has no skip conditions and no severity threshold to clear. Run it on standard, lightweight, and docs-only alike: when the gate produced no correctness findings, it still runs the repo's own gate commands (lint, typecheck, tests as defined in its CLAUDE.md), and a red gate is itself a blocking finding.

An environment blocker (a held port, a missing container, an absent `.env`) is yours to clear, not a reason to skip. If the code genuinely cannot be run after you clear the blocker, STOP and tell the user what is blocking it, rather than passing unverified findings to Step 4d.

- Spawn the `adze-bonch:repro-verifier` agent, seeded with the consolidated correctness and edge-case findings and a scratch dir path.
- It writes and runs reproduction scripts in the scratch dir and grounds them by running the repo's own gate commands. It is read-only toward application code and never writes fixes.
- It returns a REPRO-VERIFIER REPORT with a verdict per finding: **Confirmed** (reproduced), **Proven-safe** (refuted), or **Inconclusive**.
- It takes no conventions overlay. It judges runtime behavior, not language conventions.
- The verdicts feed Step 4d: the implementer fixes **Confirmed** findings (and **Inconclusive** ones at the user's discretion) and drops **Proven-safe** false positives instead of chasing them.

Append to task-log: `Repro-verify complete. {N} confirmed, {N} proven-safe, {N} inconclusive. Gates: {result}.`

### 4d. Fix Findings

Only if the quality gate has actionable findings.

- Spawn the implementer agent in fix-cycle mode with the consolidated findings. Pass only **Confirmed** (and user-approved **Inconclusive**) findings from Step 4c.5; do NOT hand it **Proven-safe** false positives.
- Returns: fixes applied, any deferred.
- Run the target repo's verification (lint, typecheck, tests as defined in its CLAUDE.md). Fix failures (max 3 cycles).

Append to task-log: `Findings fixed. {N} applied, {N} deferred. Verification: {pass/fail}`

### 4e. Documentation (DEFERRED -- Phase 2, not built)

The dedicated documentation pass and its `documentarian` agent are Phase 2 and are not built in v0.2.0. Do NOT spawn a documentation agent from this pipeline; the agent does not exist yet.

In v0.2.0, documentation is handled inline: the implementer creates or updates nested CLAUDE.md files at module level as it works, and the orchestrator updates repo READMEs and public-surface doc comments during the plan steps when the change affects them. The scrum-master's `Documentation: yes|no` flag is recorded for routing, but it does not trigger a separate agent in this build.

When the documentarian ships (Phase 2), this step will spawn it for the priority order: nested CLAUDE.md files, then repo READMEs, then inline doc comments on new or modified public surfaces.

---

## Step 5: Commit (main context)

### Commit gate (ALL must be true):
- [ ] Quality gate ran (Step 4c), and all reviewers returned a REAL result (no truncated or empty completion notifications; any thin ones retrieved via SendMessage before consolidating)
- [ ] Repro-verify ran (Step 4c.5) and returned verdicts. No exceptions. If you are about to tick this from memory rather than from a report you actually received, it did not run.
- [ ] Findings fixed or deferred (Step 4d)
- [ ] Verification passed after the most recent code change
- [ ] All plan steps implemented
- [ ] Done-condition met (the "Done when:" block from the `kind:plan` doc; verified by acceptance-qa on standard, or by code-reviewer plus the orchestrator on lightweight and docs-only where acceptance-qa is skipped)
- [ ] No outstanding [GOVERNANCE] items unaddressed

Show checklist to user before committing:
```
## Commit Gate - {task title}

- [x] Quality gate: ran, {N} total findings -> {N} fixed, {N} deferred
- [x] Repro-verify: {N} confirmed, {N} proven-safe, {N} inconclusive
- [x] Verification: lint OK, typecheck OK, tests OK
- [x] Plan steps: {N}/{N} complete
- [x] Done-condition: MET ({1-line restatement})
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
Research → Plan → Branch → Test (Step 3.5, TDD red) → Implement → Verify → Review → Repro-Verify → Fix → Verify → Commit

Under `TDD: no` Step 3.5 is skipped and the Test step runs at 4b, after Implement; everything else keeps this order. Repro-Verify (4c.5) always sits between the quality gate and the fix step and is never parallelized with either.

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
- One task-level Done-condition is derived at Step 2, echoed into the task-log, re-surfaced at Step 0, and checked at the commit gate
- Planning is interactive: substantive calls go to the user one decision per turn, and execution goes quiet once the plan and Done-condition are locked
- TDD is the default: the test-writer runs at Step 3.5, before implementation, and `TDD: no` (which moves the test step to 4b) is the exception, not the norm
- Soft cross-loop budget: roughly 8 total fix cycles across 4a/4b/4d before stopping to reassess scope with the user
- Repro-Verify (Step 4c.5) is mandatory on every workflow, with no severity threshold and no skip conditions
- The quality gate consolidates only after every dispatched reviewer has returned a real result (completion barrier)
