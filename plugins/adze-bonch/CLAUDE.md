# adze-bonch — plugin development context

This file is auto-loaded when a Claude Code session starts in `~/workspaces/marketplace/plugins/adze-bonch/`. It is for *developing the plugin itself*. It does not affect end users of the installed plugin (D12 covers that via the wizard's CLAUDE.md trampolines).

## What this plugin is (one paragraph)

`adze-bonch` is a Claude Code plugin that adds workflow discipline to projects tracked in [adze](https://github.com/4lt7ab/adze). Ships a setup wizard, a discipline loader, a project router, a status snapshot, and a synchronous decision-capture command (`/adze-bonch:save`). v0.1.0 is dogfood-grade. Lifecycle commands (tackle, refine, brainstorm, verify) come once the patterns surface from real use, per D2.

## Where things live (load-bearing pointers)

| Thing | Location |
|-------|----------|
| Plugin source-of-truth | `~/workspaces/marketplace/plugins/adze-bonch/` (this directory) |
| Deployed cache (do NOT edit) | `~/.claude/plugins/cache/ironmoose-marketplace/adze-bonch/<version>/` |
| Marketplace remote | `git@github.com:ironmoose/marketplace.git` |
| Adze repo (maintainer: Jacob @4lt7ab) | `~/workspaces/adze` |
| Design Decisions Log (D1..D17) | adze doc `01KR883C2A54R2MNX720MF34DN` |
| Meta-project ("Adze Workflow") | adze project `01KR7FQQCM37MFDTDG9N8N4JHR` |
| Dogfooding findings (2026-05-10) | adze doc `01KRAFJK0H7TV1AQARH8SNCWYT` |
| Parked: C-path upstream pitch | adze doc `01KRANRSBMCPZHQ31K2VQ78KTW` |
| Parked: hybrid encoding (v0.2.0+) | adze doc `01KRANSF16K4VHFTMB5ZPNDN1G` |

## Hard rules for this plugin's source

1. **Edit `~/workspaces/marketplace/plugins/adze-bonch/` only.** Never edit the deployed cache under `~/.claude/plugins/cache/`. After source edits, `git push`, then `claude plugin marketplace update ironmoose-marketplace` to refresh deploys.
2. **No em-dashes in new prose.** Parker considers them an AI tell. Use commas, semicolons, parentheses, or simple periods. Em-dashes that predate D16/D17 work and live in untouched sections may stay.
3. **Adze upstream commits use the captain's-log voice.** "I [verb] ..." with nautical imagery; Jacob's house style. Plugin-internal commits use conventional plain English.
4. **Tags only attach to documents in adze.** Projects and tasks cannot be tagged. Do not write code that depends on `projects_add_tag` or `tasks_add_tag` (they do not exist). See D16, D17 for the full implications.
5. **Adze MCP `documents_update` and `projects_update` fully replace `context`.** No patching, no merging. Always re-read before writing if the last read is >60s old (D4 concurrency rule).

## v0.1.0 shipping scope (per D14 + D17)

The setup wizard is **6 steps** (D17 dropped the original Step 5):

1. Welcome + pre-flight (probe adze MCP)
2. Bootstrap infrastructure (creates "adze-bonch reference" + "adze-bonch user profiles" projects, seeds canonical docs, writes the bootstrap-state doc)
3. Create user profile
4. Voice (OPTIONAL)
5. Discoverability (OPTIONAL, installs CLAUDE.md trampolines at SAFE paths only, never `~/.claude/`)
6. Quickstart

**D17 Option D dropped from v0.1.0:** typed `shape:` / `repo:` / `kind:` metadata. The agent infers project shape and task kind from title + context. Active-project lookup uses FTS on cwd basename plus an ask-user fallback. v0.2.0 may revive these features via the parked research docs.

## Lookup chain (D6) — for any workflow setting

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

1. **Synchronous decision persistence** — write to adze before the next response. Don't batch.
2. **Supersede pattern** — never delete history; prepend a SUPERSEDED notice and rename the title.
3. **Authoritative-doc convention** — versioned title, dated header, TL;DR, Open Questions, Decisions Locked.
4. **Memory vs adze split** — user-level facts go to memory; project content goes to adze.
5. **Project context updates aren't optional** — when a project pivots, `projects.context` changes, not just docs.

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
