# adze-bonch (v0.1.0)

A Claude Code plugin that adds workflow discipline to [adze](https://github.com/4lt7ab/adze) projects. Synchronous decision persistence, voice profiles, project-level overrides, named protocols for plan/scope/conflict signals, and a setup wizard that bootstraps canonical reference docs INTO adze (per D1 in the design log: discipline lives in adze, not in `~/.claude/rules/`).

This is v0.1.0, dogfood-grade. The lifecycle commands you'd expect (tackle, refine, brainstorm, verify) aren't shipped yet. Per D2, we build the plugin, use it on real work for weeks, then propose upstream once the patterns are real.

## What this plugin is

- **A discipline loader.** Every command starts by loading the canonical discipline doc from adze.
- **A decision-capture hammer.** `/adze-bonch:save` audits recent conversation turns and writes any unpersisted decisions synchronously.
- **A bootstrap wizard.** `/adze-bonch:setup` creates two adze projects ("adze-bonch reference" and "adze-bonch user profiles"), seeds canonical reference docs, and creates your user profile.
- **A read-only status check.** `/adze-bonch:status` for a cheap "where am I?" snapshot.
- **A router.** `/adze-bonch:main` resolves the active project, applies the lookup chain, and routes intent.

## What this plugin is NOT (yet)

- Not a tackle/implement orchestrator. Use sub-agents manually for now; that grows from observed usage.
- Not a brainstorming flow. `mcp__adze__projects_create` directly for now.
- Not a refine/verify pipeline. Same.
- Not a hook installer. Per the user's no-dotclaude-writes policy, hooks are deferred until they're worth the setup friction.

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
2. Bootstraps canonical reference docs into adze (creates two projects, seeds 5 canonical docs, writes a bootstrap-state doc).
3. Creates your user profile.
4. (Optional) Lets you pick a voice template to fork.
5. (Optional) Installs CLAUDE.md trampolines at safe paths for discoverability.
6. Prints a quickstart.

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

1. **Synchronous decision persistence** — write to adze before the next response. Don't batch.
2. **Supersede pattern** — never delete history; prepend a SUPERSEDED notice and rename the title.
3. **Authoritative-doc convention** — versioned title, dated header, TL;DR, Open Questions, Decisions Locked.
4. **Memory vs adze split** — user-level facts go to memory; project content goes to adze.
5. **Project context updates aren't optional** — when a project pivots, `projects.context` changes, not just docs.

Plus three named protocols (in `seeds/named-protocols.md`):

- `[GOVERNANCE]` — agent flags a plan/scope/timeline change. Surface to user.
- `[PLAN-TEST-CONFLICT]` — implementer can't reconcile RED test with plan. Halt.
- `[SCOPE-EXPANSION]` — implementer wants a file outside the planned surface. Requires user approval.

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
| `/adze-bonch:setup` | First-time setup wizard. Idempotent. |
| `/adze-bonch:status` | Read-only project snapshot. Never writes. |
| `/adze-bonch:save` | Synchronous decision capture. The "save our work" hammer. |

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
  templates/
    voice-captain-log.md     (template; opt-in fork)
    voice-lax.md             (template; opt-in fork)
    voice-professional.md    (template; opt-in fork)
  seeds/
    workflow.md              (system shape: lookup chain, project conventions, v0.1.0 scope)
    named-protocols.md       ([GOVERNANCE], [PLAN-TEST-CONFLICT], [SCOPE-EXPANSION])
    discipline.md            (the load-bearing rule, per D11)
    voice-default.md         (canonical baseline voice; bootstrapped into adze)
    bootstrap-state-template.md
  agents/                    (empty for v0.1.0; subagents grow from /tackle later)
```

## Design log

The 17 decisions that shaped v0.1.0 live in adze as document `01KR883C2A54R2MNX720MF34DN` under the "Adze Workflow" project (`01KR7FQQCM37MFDTDG9N8N4JHR`). Read it for the why behind every choice: split projects (D9), live-doc discipline (D11), CLAUDE.md trampolines vs `~/.claude/rules/` (D12), single canonical voice (D13), wizard order (D14), state oracle without project tags (D16), shape/repo/kind dropped from v0.1.0 (D17), and the rest.

## Credits

Built on [adze](https://github.com/4lt7ab/adze) by [@4lt7ab](https://github.com/4lt7ab). Sister plugins `tab-workflow` and `pr-review` ship in the same marketplace.
