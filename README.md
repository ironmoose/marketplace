# ironmoose Marketplace

Personal Claude Code plugin marketplace. Install the marketplace once, then pick the plugins you want.

## Plugins

| Plugin | Command | What it does |
|--------|---------|--------------|
| **[pr-review](plugins/pr-review/README.md)** | `/pr-review:review` | Multi-agent PR review pipeline. 5-7 specialized agents review in parallel, findings walked through one at a time, comments posted with human voice. |
| **[adze-bonch](plugins/adze-bonch/README.md)** | `/adze-bonch:main` | Workflow discipline for [adze](https://github.com/4lt7ab/adze) projects. Setup wizard, decision persistence, the Project Pulse session-resume trailhead, and a full tackle lifecycle: 11 agents, TDD by default, TypeScript/Python conventions overlays, a parallel quality gate, and a repro-verify step that proves or refutes findings before they are fixed. v0.4.0. |

## Retired plugins

`tab-workflow` was the original project lifecycle manager, built on [Tab for Projects](https://github.com/4lt7ab/Tab). It is retired and superseded by `adze-bonch`, which does the same job on top of [adze](https://github.com/4lt7ab/adze). If you were running `tab-workflow`, move to `adze-bonch`. Its source stays in the repo under `plugins/tab/`, unmaintained and no longer listed for install.

## Install

```
# Add the marketplace
/plugin marketplace add ironmoose/marketplace

# Install a plugin
/plugin install <plugin>@ironmoose-marketplace

# For example
/plugin install adze-bonch@ironmoose-marketplace
```

`<plugin>` is any name from the table above: `pr-review` or `adze-bonch`.

adze-bonch requires a running [adze](https://github.com/4lt7ab/adze) MCP server.

## What's New in v2.3

- **adze-bonch v0.4.0**: the tackle lifecycle now proves its findings before acting on them. A mandatory repro-verify step runs reproduction scripts against every quality-gate finding, so confirmed bugs get fixed and false positives get dropped instead of chased. TDD is the default sequencing: failing tests are written before the implementation. Planning runs as an interview that surfaces each judgment call to you one decision per turn rather than presenting a finished plan for a yes/no. Review diffs are pinned to a base SHA resolved from the remote ref, so a stale local ref can no longer feed reviewers a superset of the change. New TypeScript and Python conventions overlays give the agents that write or judge code a language baseline; your repo's own `CLAUDE.md` stays authoritative and the overlay sits underneath it. The `developer` agent is retired, so `implementer` is the single writer of implementation code; the tackle roster stays at 11 agents.

## What's New in v2.2

- **adze-bonch v0.3.0**: the Project Pulse, a per-project session-resume trailhead. Each project gets one lean `kind:pulse` document holding where you left off, the single next move, and anything open for you. `/adze-bonch:main` and `/adze-bonch:status` load it first and lead with it, so entering a project starts from its resume state instead of a cold read. `/adze-bonch:save` writes and updates it in place via a dedicated `pulse-writer` agent. Anti-bloat rules keep it from drifting into a status report: a 25-line budget, one active thread, exactly one next move, no accumulated history. Anything that overflows is filed as adze tasks rather than kept in the doc.

## What's New in v2.1

- **adze-bonch plugin**: workflow discipline for adze projects. Sister plugin to `tab-workflow`. Ships a setup wizard that bootstraps canonical reference docs into adze, a synchronous decision-capture command (`/adze-bonch:save`), a project router, a read-only status snapshot, a Project Pulse session-resume trailhead, three named protocols for plan/scope/conflict signals, and a full tackle lifecycle orchestrator (`/adze-bonch:tackle`) with 11 specialized agents and a parallel quality gate. v0.3.0; brainstorm, refine, and verify remain future work.

## What's New in v2.0

- **Quality Gates**: Commit gate checks that all review findings, verification failures, and tasks are resolved before allowing a commit.
- **Workflow Routing**: The `/tab-workflow:main` router detects intent and dispatches to the appropriate pipeline (brainstorm, refine, implement, verify). PR review intent routes to the pr-review plugin.
- **pr-review plugin**: PR reviews are now a standalone plugin (`/pr-review:review`). Multi-agent review pipeline with 5-7 parallel specialist agents, voice-controlled comment posting, and optional Tab integration.

## Update

```
# Pull latest plugin versions
/plugin marketplace update ironmoose-marketplace

# Update a specific plugin
/plugin update <plugin>@ironmoose-marketplace

# For example
/plugin update adze-bonch@ironmoose-marketplace
```

## For other editors

The command `.md` files are portable. Agents and rules are Claude Code-specific.

```bash
git clone git@github.com:ironmoose/marketplace.git
# Copy plugins/<plugin>/commands/*.md into your editor's command directory
# e.g. plugins/adze-bonch/commands/*.md
```

Plugin directories are `plugins/pr-review` and `plugins/adze-bonch`.

## Credits

Built on [adze](https://github.com/4lt7ab/adze), and previously on [Tab for Projects](https://github.com/4lt7ab/Tab) for the retired `tab-workflow`, both by [@4lt7ab](https://github.com/4lt7ab).
