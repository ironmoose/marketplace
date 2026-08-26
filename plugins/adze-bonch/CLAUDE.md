# adze-bonch: plugin development context

This file is loaded by Claude Code on session start in `~/workspaces/marketplace/plugins/adze-bonch/`. It is for *developing the plugin itself*. It does not affect end users of the installed plugin (D12 covers that via the wizard's CLAUDE.md trampolines).

## What this plugin is (one paragraph)

`adze-bonch` is a Claude Code plugin that adds workflow discipline to projects tracked in [adze](https://github.com/4lt7ab/adze). Ships a setup wizard, a discipline loader, a project router, a status snapshot, a synchronous decision-capture command (`/adze-bonch:save`), a Project Pulse session-resume trailhead (loaded by main/status, written by /adze-bonch:save), and a full tackle lifecycle orchestrator (`/adze-bonch:tackle`) with 11 specialized agents and TypeScript/Python conventions overlays. v0.4.0. brainstorm, refine, and verify remain future work.

## Where things live (load-bearing pointers)

| Thing | Location |
|-------|----------|
| Plugin source-of-truth | `~/workspaces/marketplace/plugins/adze-bonch/` (this directory) |
| Standards model (read, do not bake: project rules only) | `reference/conventions.md` |
| Language conventions overlays | `reference/typescript-conventions.md`, `reference/python-conventions.md` |
| Skills | `skills/<name>/SKILL.md` |
| Deployed cache (do NOT edit) | `~/.claude/plugins/cache/ironmoose-marketplace/adze-bonch/<version>/` |
| Marketplace remote | `git@github.com:ironmoose/marketplace.git` |
| Adze repo (maintainer: Jacob @4lt7ab) | `~/workspaces/adze` |
| Design Decisions Log (D1..D18) | adze doc `01KR883C2A54R2MNX720MF34DN` |
| Meta-project ("Adze Workflow") | adze project `01KR7FQQCM37MFDTDG9N8N4JHR` |
| Dogfooding findings (2026-05-10) | adze doc `01KRAFJK0H7TV1AQARH8SNCWYT` |
| Parked: C-path upstream pitch | adze doc `01KRANRSBMCPZHQ31K2VQ78KTW` |
| Parked: hybrid encoding (v0.2.0+) | adze doc `01KRANSF16K4VHFTMB5ZPNDN1G` |

## Hard rules for this plugin's source

1. **Edit `~/workspaces/marketplace/plugins/adze-bonch/` only.** Never edit the deployed cache under `~/.claude/plugins/cache/`. After source edits, `git push`, then `claude plugin marketplace update ironmoose-marketplace` to refresh deploys.
2. **No em-dashes in new prose.** Parker considers them an AI tell. Use commas, semicolons, parentheses, or simple periods.
3. **Adze upstream commits use the captain's-log voice.** "I [verb] ..." with nautical imagery; Jacob's house style. Plugin-internal commits use conventional plain English.
4. **Tags only attach to documents in adze.** Projects and tasks cannot be tagged. Do not write code that depends on `projects_add_tag` or `tasks_add_tag` (they do not exist). See D16, D17 for the full implications.
5. **Adze MCP `documents_update` and `projects_update` fully replace `context`.** No patching, no merging. Always re-read before writing if the last read is >60s old (D4 concurrency rule).

## Setup wizard shape (per D14 + D17)

The setup wizard is **7 steps** (D17 dropped the original Step 5; SessionStart hook added in v0.2.0):

1. Welcome + pre-flight (probe adze MCP)
2. Bootstrap infrastructure (creates "adze-bonch reference" + "adze-bonch user profiles" projects, seeds canonical docs, writes the bootstrap-state doc)
3. Create user profile
4. Voice (OPTIONAL)
5. Discoverability (OPTIONAL, installs CLAUDE.md trampolines at SAFE paths only, never `~/.claude/`)
6. SessionStart hook (OPTIONAL, surfaces a session-start reminder to load adze-bonch via `/adze-bonch:main`)
7. Quickstart

**D17 Option D dropped from v0.1.0:** typed `shape:` / `repo:` / `kind:` metadata. The agent infers project shape and task kind from title + context. Active-project lookup uses FTS on cwd basename plus an ask-user fallback. Still unrevived as of v0.4.0; a future version may revive them via the parked research docs.

## Tackle lifecycle and agents

`/adze-bonch:tackle` is the task lifecycle orchestrator. `commands/tackle.md` is the authoritative step list; this is the summary.

- **Step 0** Load discipline, resolve the task, open or append the `kind:task-log` doc.
- **Step 0.5** Scrum-master routes: workflow type plus the `Documentation` and `TDD` flags.
- **Step 1** Researcher builds context (reads target repo and target CLAUDE.md, grounds third-party library and vendor facts via context7).
- **Step 2** Plan: interactive, one decision per turn, recommendations grounded before they are shown. Derives a task-level "Done when:" condition. Persisted as a `kind:plan` adze document.
- **Step 3** Branch creation.
- **Step 3.5** Test-writer writes FAILING tests first. TDD is the default (`TDD: yes`); only docs-only, dependency bumps, and pure config run implement-first.
- **Step 4a** Implementer executes plan steps, taking the failing tests green. It is the only agent that writes implementation code, at 4a and again at 4d.
- **Step 4b** Tests. Under TDD this is verification only; in non-TDD mode the test-writer runs here.
- **Step 4c** Parallel quality gate (6 reviewers on standard, including self-containment-reviewer): code-reviewer, acceptance-qa, edge-case-qa, code-smells-reviewer, test-reviewer, self-containment-reviewer. The diff is captured against a base SHA resolved from the REMOTE ref (`merge-base origin/<base-ref> HEAD`); a bare local base ref silently feeds reviewers a superset of the change. Never consolidate until every dispatched reviewer returned a real result.
- **Step 4c.5** Repro-verifier proves or refutes the gate's findings by running reproduction scripts in a scratch dir, and runs the target repo's own verification. MANDATORY on every workflow, no skip conditions. Returns Confirmed / Proven-safe / Inconclusive per finding.
- **Step 4d** Fix findings. Confirmed ones get fixed; Proven-safe false positives are dropped, not chased.
- **Step 4d.5** Confirm-fix. The repro-verifier re-runs each Confirmed finding's OWN repro against the fixed code, and it must now PASS. MANDATORY on every workflow, no skip conditions. The repo's own test suite going green is not sufficient: those tests did not catch the defect in the first place, which is why the repro exists. A fix whose repro still fails is not a fix and goes back to 4d, and a finding whose repro was never re-run does not reach the commit gate. Added after a 2026-08-25 failure where a Confirmed finding was "fixed" by moving a call site and adding a comment, the repro was never re-run, the green suite and a reviewer both passed it, and the defect survived.
- **Step 5** Commit gate, which checks the Step 2 Done-condition.
- **Step 6** PR handoff to the `pr-review` plugin.

**Fix-cycle budget:** max 3 per failure, plus a soft cross-loop total of roughly 8 across Steps 4a, 4b, and 4d. Past that, stop and reassess with the user.

**Standards model** (`reference/conventions.md` is canonical): each working agent reads the TARGET repo's own `CLAUDE.md` to enforce its conventions, and read-only reviewers receive those conventions injected by the orchestrator. No baked *project* ruleset lives in this plugin. A baked *language* baseline does: `reference/typescript-conventions.md` and `reference/python-conventions.md`, the conventions overlays, are injected into the six language-sensitive agents' spawn prompts. The target repo's `CLAUDE.md` stays authoritative and wins; the overlay is the baseline underneath it; general good practice fills what both leave silent. The detection rule that picks an overlay lives once in `seeds/workflow.md`.

**Adze state:** tackle persists all intermediate state bound to the task by `task_id`:
- `kind:research`: researcher findings.
- `kind:plan`: the approved plan.
- `kind:task-log`: progress, fix-cycle outcomes, and the commit gate verdict.

### Agent roster (11 tackle-lifecycle agents)

`Overlay` marks the language-sensitive agents that get a conventions overlay injected into their spawn prompt.

| File | Role | Overlay |
|------|------|---------|
| `agents/scrum-master.md` | Routes tasks; recommends workflow path. | no |
| `agents/researcher.md` | Explores target repo; builds context before planning. | no |
| `agents/implementer.md` | Disciplined plan executor; audits its own diff. Sole writer of implementation code (4a and 4d). | yes |
| `agents/test-writer.md` | Writes and updates test coverage. | yes |
| `agents/code-reviewer.md` | Reviews against target repo conventions. | yes |
| `agents/acceptance-qa.md` | Verifies against the task's acceptance criteria. | no |
| `agents/edge-case-qa.md` | Hunts boundary conditions and error paths. | yes |
| `agents/code-smells-reviewer.md` | Flags design issues and maintainability smells. | yes |
| `agents/test-reviewer.md` | Examines test quality. | yes |
| `agents/self-containment-reviewer.md` | Checks committed artifacts are self-contained. | no |
| `agents/repro-verifier.md` | Proves or refutes gate findings by running repro scripts (4c.5) in a durable scratch dir (`adze-gate repro-dir`); re-runs each Confirmed finding's repro after the fix in confirm mode (4d.5). | no |

`agents/pulse-writer.md` is a 12th agent file, outside the tackle pipeline and taking no overlay: it drafts the Project Pulse for `/adze-bonch:save`. The roster count of 11 covers the tackle pipeline only.

The `developer` agent was retired in v0.4.0. Do not reintroduce a second implementation-writing agent; the implementer covers both the implement step and the fix step.

## Lookup chain (D6): for any workflow setting

```
session override -> project workflow_overrides (in project.context) -> user profile doc -> canonical default (seed)
```

First hit wins. Cache for the duration of the turn.

## State oracle (D16)

`/adze-bonch:setup` detects install state via:

1. `tags_list(q="kind:bootstrap-state")` to resolve the tag id (create it if missing).
2. `documents_list(tag_id=..., limit=1)` to find prior installs.
3. If found, read YAML frontmatter for `adze_workflow_plugin_project_id` and `user_profiles_project_id`, then `projects_get` to verify each.
4. Branch on `plugin_version` for fresh / current / upgrade / newer-than-plugin.

Do NOT use `search` or project-tag filters for state detection. Project tags do not exist in adze (see hard rule 4).

## Five baseline conventions (loaded from `seeds/discipline.md`)

1. **Synchronous decision persistence:** write to adze before the next response. Don't batch.
2. **Supersede pattern:** never delete history; prepend a SUPERSEDED notice and rename the title.
3. **Authoritative-doc convention:** versioned title, dated header, TL;DR, Open Questions, Decisions Locked.
4. **Memory vs adze split:** user-level facts go to memory; project content goes to adze.
5. **Project context updates aren't optional:** when a project pivots, `projects.context` changes, not just docs.

Plus three named protocols: `[GOVERNANCE]`, `[PLAN-TEST-CONFLICT]`, `[SCOPE-EXPANSION]` (see `seeds/named-protocols.md`).

## Adze MCP tools, fast reference

Reads: `projects_list`, `projects_get`, `projects_brief`, `tasks_list`, `tasks_get`, `documents_list`, `documents_get`, `documents_for_project`, `search`, `tags_list`.

Writes: `projects_create`, `projects_update`, `tasks_create`, `tasks_create_many`, `tasks_update`, `documents_create`, `documents_update`, `documents_attach`, `documents_add_tag`, `tags_create`.

## On session start in this directory

1. `mcp__adze__projects_get(01KR7FQQCM37MFDTDG9N8N4JHR)` to load the meta-project context.
2. `mcp__adze__tasks_list(project_id=01KR7FQQCM37MFDTDG9N8N4JHR, status=["todo","doing","blocked"])` to see open work.
3. `mcp__adze__documents_get(01KR883C2A54R2MNX720MF34DN)` to load the design log if you'll be making design decisions.

Skip step 3 for pure file edits or trivial tweaks.

## Commit message style

- **Plugin-internal commits** (this repo): imperative present, conventional commits style. Example: `adze-bonch: drop Step 5 per D17`.
- **Upstream adze commits** (when contributing to `4lt7ab/adze`): captain's-log voice. Example: `I splice a group_key into tasks, run the line through every hatch, and tab the ledger.` Match Jacob's existing log.
