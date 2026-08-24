# adze-bonch (v0.5.0)

A Claude Code plugin that adds workflow discipline to [adze](https://github.com/4lt7ab/adze) projects. Synchronous decision persistence, voice profiles, project-level overrides, named protocols for plan/scope/conflict signals, a setup wizard that bootstraps canonical reference docs INTO adze, and a full tackle lifecycle that runs tasks end-to-end with a team of 11 specialized agents.

v0.4.0 hardens the tackle lifecycle: TDD is now the default sequencing, a mandatory repro-verify step proves or refutes every quality-gate finding before anything is fixed, planning runs as an interview that surfaces judgment calls to the user, and the review diff is pinned to a base SHA resolved from the remote ref. It also adds TypeScript and Python conventions overlays, a language baseline for the agents that write or judge code, and retires the `developer` agent so the implementer is the single writer of implementation code. v0.3.0 added the Project Pulse session-resume trailhead on top of the v0.2.0 tackle lifecycle and the v0.1.0 workflow foundations. brainstorm, refine, and verify remain future work.

## What this plugin is

- **A discipline loader.** Every command starts by loading the canonical discipline doc from adze.
- **A decision-capture hammer.** `/adze-bonch:save` audits recent conversation turns and writes any unpersisted decisions synchronously.
- **A session-resume trailhead.** Each project has a Project Pulse: one lean `kind:pulse` doc that records where you left off, the next move, and anything open for the user. `/adze-bonch:main` and `/adze-bonch:status` lead with it, and `/adze-bonch:save` writes it via a dedicated `pulse-writer` sub-agent. One Pulse per project.
- **A bootstrap wizard.** `/adze-bonch:setup` creates two adze projects ("adze-bonch reference" and "adze-bonch user profiles"), seeds canonical reference docs, creates your user profile, and optionally installs a SessionStart hook.
- **A read-only status check.** `/adze-bonch:status` for a cheap "where am I?" snapshot.
- **A router.** `/adze-bonch:main` resolves the active project, applies the lookup chain, and routes intent.
- **A tackle orchestrator.** `/adze-bonch:tackle` runs the full task lifecycle: load discipline, resolve task, scrum-master routes, researcher builds context, plan is written interactively and stored in adze, failing tests are written first (TDD is the default), the implementer takes them green on a branch, a parallel quality gate runs 6 reviewers, a mandatory repro-verify step proves or refutes each finding, fix cycles clear the confirmed ones, and the commit gate hands off to `pr-review`.
- **Skills.** Reusable playbooks that load on demand: `subagent-edit-verification` (check what an editing agent actually did before committing) and `interview-prep-sheet-rehearsal-audit` (repair a prep document by rehearsing it out loud).

## What this plugin is NOT (yet)

- Not a brainstorming flow. `mcp__adze__projects_create` directly for now.
- Not a refine/verify pipeline. Those grow from observed usage.
- Not a general hook installer. The setup wizard can optionally install a SessionStart hook; arbitrary hook configuration is out of scope.

## Setup

### Install

```
/plugin marketplace add ironmoose/marketplace
/plugin install adze-bonch@ironmoose-marketplace
```

### First-time setup

```
/adze-bonch:setup
```

This wizard:
1. Pre-flights the adze MCP server.
2. Bootstraps canonical reference docs into adze (creates two projects, seeds every canonical doc in the plugin's `seeds/` directory, writes a bootstrap-state doc).
3. Creates your user profile.
4. (Optional) Lets you pick a voice template to fork.
5. (Optional) Installs CLAUDE.md trampolines at safe paths for discoverability.
6. (Optional) Installs a SessionStart hook that surfaces a session-start reminder to load adze-bonch via `/adze-bonch:main`.
7. Prints a quickstart.

It's idempotent. Re-run anytime; only optional steps re-prompt.

### Prerequisites

- The adze MCP server running locally.
- Claude Code with MCP support.
- Add the adze server to `~/.claude.json` (the path is wherever you cloned `4lt7ab/adze`):
  ```json
  "mcpServers": {
    "adze": {
      "type": "stdio",
      "command": "uv",
      "args": [
        "run",
        "--project",
        "/path/to/adze",
        "python",
        "-m",
        "adze_mcp"
      ],
      "env": {}
    }
  }
  ```

## The five baseline conventions

Loaded by every command from the canonical discipline doc in adze:

1. **Synchronous decision persistence:** write to adze before the next response. Don't batch.
2. **Supersede pattern:** never delete history; prepend a SUPERSEDED notice and rename the title.
3. **Authoritative-doc convention:** versioned title, dated header, TL;DR, Open Questions, Decisions Locked.
4. **Memory vs adze split:** user-level facts go to memory; project content goes to adze.
5. **Project context updates aren't optional:** when a project pivots, `projects.context` changes, not just docs.

Plus three named protocols (in `seeds/named-protocols.md`):

- `[GOVERNANCE]`: agent flags a plan/scope/timeline change. Surface to user.
- `[PLAN-TEST-CONFLICT]`: implementer can't reconcile RED test with plan. Halt.
- `[SCOPE-EXPANSION]`: implementer wants a file outside the planned surface. Requires user approval.

## The lookup chain

When resolving any workflow setting (voice, ticket-prefix-pattern, formats):

```
session override  ->  project workflow_overrides  ->  user profile  ->  canonical default
```

First hit wins. Per-project overrides live in `project.context` as a fenced `workflow_overrides` YAML block.

## Commands

| Command | Description |
|---------|-------------|
| `/adze-bonch:main` | Router. Loads discipline, resolves project, routes intent. |
| `/adze-bonch:setup` | First-time setup wizard. Idempotent. 7 steps. |
| `/adze-bonch:status` | Read-only project snapshot. Never writes. |
| `/adze-bonch:save` | Synchronous decision capture. The "save our work" hammer. |
| `/adze-bonch:tackle` | Full task lifecycle orchestrator. Research, plan, implement, test, quality gate, and PR handoff via `pr-review`. |

## Tackle lifecycle and agents

`/adze-bonch:tackle` runs an adze task end to end. The pipeline:

1. **Load discipline** from adze; resolve the target task and its `kind:task-log` progress doc.
2. **Scrum-master routes** the task, returning the workflow type plus the `Documentation` and `TDD` flags.
3. **Researcher** builds context from the target repo, grounding third-party library and vendor facts via context7 rather than recall.
4. **Plan:** an interview, not a finished plan presented for a yes/no. The orchestrator surfaces each substantive judgment call to the user one decision per turn, grounds every recommendation before showing it, and derives a task-level "Done when:" condition. Persisted as a `kind:plan` adze document.
5. **Branch** created from the target repo's default branch.
6. **Failing tests first.** TDD is the default: the test-writer produces a red baseline against the interface the plan defines. Only docs-only changes, dependency bumps, and pure config run implement-first.
7. **Implementer** takes the tests green. It is the only agent that writes implementation code, here and again at the fix step.
8. **Quality gate** runs 6 reviewers in parallel on standard workflows: code-reviewer, acceptance-qa, edge-case-qa, code-smells-reviewer, test-reviewer, self-containment-reviewer. The diff is pinned to a base SHA resolved against the remote ref, so a stale local base cannot feed reviewers a superset of the change. Findings are consolidated only once every reviewer has returned a real result.
9. **Repro-verify** (mandatory, no skip conditions). The repro-verifier writes and runs reproduction scripts in its own scratch dir and runs the target repo's verification, returning Confirmed, Proven-safe, or Inconclusive per finding.
10. **Fix cycles** clear the Confirmed findings. Proven-safe false positives are dropped rather than chased. Max 3 cycles per failure, with a soft total of roughly 8 across implement, test, and fix.
11. **Commit gate** (which checks the Done-condition) and PR handoff to the `pr-review` plugin.

### Agents (11 in the tackle lifecycle)

The `Overlay` column marks the agents that receive a language conventions overlay, described in the next section.

| Agent | Role | Overlay |
|-------|------|---------|
| `scrum-master` | Routes tasks; recommends workflow path. | no |
| `researcher` | Explores the target repo; builds context before planning. | no |
| `implementer` | Disciplined plan executor; audits its own diff against the plan. The only agent that writes implementation code. | yes |
| `test-writer` | Writes and updates test coverage. | yes |
| `code-reviewer` | Reviews changed files against the target repo's conventions. | yes |
| `acceptance-qa` | Verifies the implementation meets the task's acceptance criteria. | no |
| `edge-case-qa` | Hunts boundary conditions, error paths, and data permutations. | yes |
| `code-smells-reviewer` | Flags design issues and maintainability smells. | yes |
| `test-reviewer` | Examines test quality: hollow assertions, over-mocking, coverage gaps. | yes |
| `self-containment-reviewer` | Checks that committed artifacts are self-contained and leak no internal references. | no |
| `repro-verifier` | Proves or refutes each gate finding by reproduction; returns Confirmed, Proven-safe, or Inconclusive. | no |

A 12th agent, `pulse-writer`, sits outside the tackle pipeline: it drafts the Project Pulse for `/adze-bonch:save`. It takes no overlay.

The `developer` agent shipped through v0.3.0 and was retired in v0.4.0. If you referenced `adze-bonch:developer` directly, use `adze-bonch:implementer` instead; it now covers both the implement step and the fix step.

### Standards model

Working agents read the target repo's own `CLAUDE.md` to enforce its conventions directly, and read-only reviewers receive those conventions injected by the orchestrator. adze-bonch bakes in no *project* ruleset: your repo's standards come from your repo.

What it does ship is a *language* baseline, the **conventions overlay**. `reference/typescript-conventions.md` and `reference/python-conventions.md` hold rules that are true of the language itself (type safety, nullability, error handling, test structure) and nothing that is true only of a particular repo or framework. The orchestrator detects the language of the changed code and injects the matching overlay into the spawn prompts of the six agents that write or judge code: implementer, test-writer, code-reviewer, code-smells-reviewer, test-reviewer, and edge-case-qa. The other agents take no overlay, because they reason about acceptance criteria, leaked private context, or runtime behavior rather than language conventions. If the code is in neither language, there is no overlay and the agents work from your `CLAUDE.md` plus general good practice.

Precedence is unambiguous:

```
your repo's CLAUDE.md  ->  conventions overlay  ->  general good practice
```

Your repo is authoritative and always wins. The overlay is the baseline underneath it, so a repo with a thin or missing `CLAUDE.md` still gets sane language-level rules instead of whatever an agent happens to guess. General good practice covers whatever both leave silent. Agents are told never to impose an overlay rule over a committed standard; when the two diverge, they follow the repo and flag the divergence.

The full model, including where adze-side session and project overrides sit above all of this, is in `reference/conventions.md`.

### State in adze

Tackle persists all intermediate state as adze documents bound to the task by `task_id`:

- `kind:research`: the researcher's findings and context.
- `kind:plan`: the approved plan.
- `kind:task-log`: progress notes, fix-cycle outcomes, and the commit gate verdict.

## File layout

```
plugins/adze-bonch/
  README.md
  .claude-plugin/plugin.json
  commands/
    main.md
    setup.md
    status.md
    save.md
    tackle.md               (orchestrator)
  templates/
    voice-captain-log.md     (template; opt-in fork)
    voice-lax.md             (template; opt-in fork)
    voice-professional.md    (template; opt-in fork)
  seeds/
    workflow.md              (system shape: lookup chain, project conventions, pipeline scope)
    named-protocols.md       ([GOVERNANCE], [PLAN-TEST-CONFLICT], [SCOPE-EXPANSION])
    discipline.md            (the load-bearing rule, per D11)
    voice-default.md         (canonical baseline voice; bootstrapped into adze)
    branch-naming.md
    progress-format.md       (the kind:task-log shape)
    pulse-template.md        (the kind:pulse shape)
    bootstrap-state-template.md
  reference/
    agent-prompts.md         (prompt templates; the inline-context contract)
    conventions.md           (the standards model: read, do not bake project rules)
    typescript-conventions.md (language baseline injected for .ts / .tsx work)
    python-conventions.md     (language baseline injected for .py work)
  agents/
    scrum-master.md
    researcher.md
    implementer.md
    test-writer.md
    code-reviewer.md
    acceptance-qa.md
    edge-case-qa.md
    code-smells-reviewer.md
    test-reviewer.md
    self-containment-reviewer.md
    repro-verifier.md
    pulse-writer.md          (outside the tackle pipeline; drafts the Project Pulse)
```

## Design log

The 18 decisions behind adze-bonch live in adze as document `01KR883C2A54R2MNX720MF34DN` under the "Adze Workflow" project (`01KR7FQQCM37MFDTDG9N8N4JHR`). D1 through D17 shaped the v0.1.0 foundations; D18 shaped the Project Pulse that shipped in v0.3.0. Read it for the why behind every choice: split projects (D9), live-doc discipline (D11), CLAUDE.md trampolines vs `~/.claude/rules/` (D12), single canonical voice (D13), wizard order (D14), state oracle without project tags (D16), shape/repo/kind dropped from v0.1.0 (D17), the Project Pulse trailhead and its anti-bloat budget (D18), and the rest.

## Credits

Built on [adze](https://github.com/4lt7ab/adze) by [@4lt7ab](https://github.com/4lt7ab). Sister plugin `pr-review` ships in the same marketplace.
