# adze-bonch (v0.2.0)

A Claude Code plugin that adds workflow discipline to [adze](https://github.com/4lt7ab/adze) projects. Synchronous decision persistence, voice profiles, project-level overrides, named protocols for plan/scope/conflict signals, a setup wizard that bootstraps canonical reference docs INTO adze, and a full tackle lifecycle that runs tickets end-to-end with a team of 11 specialized agents.

v0.2.0 ships the full tackle lifecycle alongside the v0.1.0 workflow foundations. brainstorm, refine, and verify remain future work.

## What this plugin is

- **A discipline loader.** Every command starts by loading the canonical discipline doc from adze.
- **A decision-capture hammer.** `/adze-bonch:save` audits recent conversation turns and writes any unpersisted decisions synchronously.
- **A bootstrap wizard.** `/adze-bonch:setup` creates two adze projects ("adze-bonch reference" and "adze-bonch user profiles"), seeds canonical reference docs, creates your user profile, and optionally installs a SessionStart hook.
- **A read-only status check.** `/adze-bonch:status` for a cheap "where am I?" snapshot.
- **A router.** `/adze-bonch:main` resolves the active project, applies the lookup chain, and routes intent.
- **A tackle orchestrator.** `/adze-bonch:tackle` runs the full ticket lifecycle: load discipline, resolve task, scrum-master routes, researcher builds context, plan is written and stored in adze, implementer executes on a branch, test-writer adds coverage, a parallel quality gate runs 6 reviewers in parallel (including self-containment-reviewer), fix cycles clear findings, and the commit gate hands off to `pr-review`.

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
2. Bootstraps canonical reference docs into adze (creates two projects, seeds 7 canonical docs, writes a bootstrap-state doc).
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
| `/adze-bonch:tackle` | Full ticket lifecycle orchestrator. Research, plan, implement, test, quality gate, and PR handoff via `pr-review`. |

## Tackle lifecycle and agents

`/adze-bonch:tackle` runs a ticket end to end. The pipeline:

1. **Load discipline** from adze; resolve the target task.
2. **Scrum-master routes** the ticket (type and complexity determine the workflow path).
3. **Researcher** builds context from the target repo.
4. **Plan:** the orchestrator drafts a step-by-step plan with the user, persisted as a `kind:plan` adze document.
5. **Branch** created from the target repo's default branch.
6. **Implementer** executes plan steps; a developer agent is available for lighter-weight passes.
7. **Test-writer** adds or updates test coverage.
8. **Quality gate** runs 6 reviewers in parallel, including self-containment-reviewer: code-reviewer, acceptance-qa, edge-case-qa, code-smells-reviewer, test-reviewer, self-containment-reviewer. Findings feed fix cycles.
9. **Commit gate** and PR handoff to the `pr-review` plugin.

### Agents (11)

| Agent | Role |
|-------|------|
| `scrum-master` | Routes tickets; recommends workflow path. |
| `researcher` | Explores the target repo; builds context before planning. |
| `implementer` | Disciplined plan executor; audits its own diff against the plan. |
| `developer` | Lighter-weight implementer for simpler passes. |
| `test-writer` | Writes and updates test coverage. |
| `code-reviewer` | Reviews changed files against the target repo's conventions. |
| `acceptance-qa` | Verifies the implementation meets the ticket's acceptance criteria. |
| `edge-case-qa` | Hunts boundary conditions, error paths, and data permutations. |
| `code-smells-reviewer` | Flags design issues and maintainability smells. |
| `test-reviewer` | Examines test quality: hollow assertions, over-mocking, coverage gaps. |
| `self-containment-reviewer` | Checks that committed artifacts are self-contained and leak no internal references. |

### Standards model

Working agents (researcher, implementer, developer, test-writer) read the target repo's own `CLAUDE.md` to enforce its conventions directly. Read-only reviewers receive those conventions injected by the orchestrator. No baked ruleset lives in adze-bonch; standards come from the repo being worked on.

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
    workflow.md              (system shape: lookup chain, project conventions, v0.2.0 scope)
    named-protocols.md       ([GOVERNANCE], [PLAN-TEST-CONFLICT], [SCOPE-EXPANSION])
    discipline.md            (the load-bearing rule, per D11)
    voice-default.md         (canonical baseline voice; bootstrapped into adze)
    bootstrap-state-template.md
  agents/
    scrum-master.md
    researcher.md
    implementer.md
    developer.md
    test-writer.md
    code-reviewer.md
    acceptance-qa.md
    edge-case-qa.md
    code-smells-reviewer.md
    test-reviewer.md
    self-containment-reviewer.md
```

## Design log

The 17 decisions that shaped v0.1.0 live in adze as document `01KR883C2A54R2MNX720MF34DN` under the "Adze Workflow" project (`01KR7FQQCM37MFDTDG9N8N4JHR`). Read it for the why behind every choice: split projects (D9), live-doc discipline (D11), CLAUDE.md trampolines vs `~/.claude/rules/` (D12), single canonical voice (D13), wizard order (D14), state oracle without project tags (D16), shape/repo/kind dropped from v0.1.0 (D17), and the rest.

## Credits

Built on [adze](https://github.com/4lt7ab/adze) by [@4lt7ab](https://github.com/4lt7ab). Sister plugins `tab-workflow` and `pr-review` ship in the same marketplace.
