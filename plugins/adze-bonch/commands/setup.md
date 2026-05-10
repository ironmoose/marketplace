---
name: setup
description: "First-time setup wizard for the adze-bonch plugin. Pre-flights the adze MCP, bootstraps canonical reference docs, creates user profile, and offers discoverability shims. Per D14: 7-step flow, bootstrap BEFORE identity."
---

# adze-bonch Setup Wizard

You are running the first-time setup wizard for the adze-bonch plugin. Walk through each step sequentially. Show results as you go, then move to the next step.

This wizard implements the 7-step flow locked in D14. Per D11, it does NOT install rule files into `~/.claude/rules/` — discipline lives in adze. Per D12, it offers safe-path CLAUDE.md trampolines for discoverability.

## Step 1: Welcome + Pre-Flight

Print:

```
Setting up adze-bonch. This will:
  1. Pre-flight the adze MCP server
  2. Bootstrap canonical reference docs into adze
  3. Create your user profile
  4. (Optional) Pick a voice
  5. (Optional) Tag existing projects
  6. (Optional) Install CLAUDE.md trampolines for discoverability
  7. Show the quickstart printout

Let's go.
```

### Pre-flight probe

Try calling `mcp__adze__projects_list()`.

**If it succeeds:**
Print: `adze MCP is reachable. Found {N} project(s).`
Move to Step 2.

**If it fails:**
Print and STOP:

```
adze MCP server is not reachable.

To set it up, add this to ~/.claude.json (the path is wherever you cloned 4lt7ab/adze):

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

Restart Claude Code, then run /adze-bonch:setup again.
```

Do NOT continue past Step 1 if the MCP is unreachable.

## Step 2: Bootstrap Infrastructure (BEFORE identity, per D14)

The plugin needs two adze projects and a set of canonical reference docs.

### State detection

Search for a bootstrap-state doc:

```
mcp__adze__search({ q: "bootstrap-state", kinds: ["document"], limit: 5 })
```

Filter results for tag `kind:bootstrap-state` AND project tagged `kind:bootstrap-state-project`.

Branch on what you find:

| Found | Branch |
|-------|--------|
| Nothing | **Fresh install** — create both projects, seed all canonical docs, write a new bootstrap-state doc. |
| Bootstrap-state doc, plugin_version matches | **Current** — print "adze-bonch already set up. Re-running optional steps only." Skip to Step 3. |
| Bootstrap-state doc, plugin_version older | **Upgrade** — diff `canonical_seeds[].seed_hash` against current seed files; create a new doc + supersede old for any drift. Update plugin_version. |
| Bootstrap-state doc, partial fields | **Resume** — pick up where the previous run stopped. |

### Fresh install path

1. Create the canonical project:
   ```
   mcp__adze__projects_create({
     title: "Adze Workflow Plugin",
     context: "Canonical reference docs for adze-bonch. Seeded from plugin templates. Edits here are live and queryable.",
     status: "active"
   })
   ```
   Tag it `kind:bootstrap-state-project` and `provenance:canonical`.

2. Create the user-profiles project:
   ```
   mcp__adze__projects_create({
     title: "User Profiles",
     context: "Personal workflow profiles for adze-bonch users. One doc per user, tagged user-profile:{username} and kind:profile.",
     status: "active"
   })
   ```
   Tag it `kind:user-profiles-project`.

3. Seed canonical docs from the plugin's `seeds/` directory. For each file in `seeds/*.md`:
   - Read the seed file from disk (the plugin install path; resolve from `${CLAUDE_PLUGIN_ROOT}/seeds/` or known marketplace path).
   - Compute a SHA256 of the file content (call it `seed_hash`).
   - Create a document under the "Adze Workflow Plugin" project with:
     - `title` = the file's first H1 line, or the filename if no H1
     - `context` = the file body verbatim
     - tags: `provenance:canonical`, `kind:reference`, `concurrency:strict`, plus the seed-specific kind:
       - `workflow.md` -> `kind:workflow`
       - `named-protocols.md` -> `kind:protocols`
       - `discipline.md` -> `kind:discipline`
       - `bootstrap-state-template.md` -> `kind:bootstrap-state-template`
       - `voice-default.md` -> `kind:voice-profile` (replaces `kind:reference` for this one; still `provenance:canonical`, `concurrency:strict`)
   - Record the resulting `document_id` and `seed_hash`.

4. Write the bootstrap-state doc under "Adze Workflow Plugin":
   ```yaml
   ---
   plugin_version: 0.1.0
   install_at: <ISO-8601 UTC>
   last_sync_at: <ISO-8601 UTC>
   adze_workflow_plugin_project_id: <id from step 1>
   user_profiles_project_id: <id from step 2>
   canonical_seeds:
     - file: workflow.md
       document_id: <id>
       seed_hash: <sha256>
     - file: named-protocols.md
       document_id: <id>
       seed_hash: <sha256>
     - file: discipline.md
       document_id: <id>
       seed_hash: <sha256>
     - file: bootstrap-state-template.md
       document_id: <id>
       seed_hash: <sha256>
     - file: voice-default.md
       document_id: <id>
       seed_hash: <sha256>
   user_profile_id: null
   discoverability_installed_at: []
   ---
   ```
   Tag it `kind:bootstrap-state` and `provenance:canonical`.

   Print: `Bootstrapped. Created 2 projects and {N} canonical docs.`

## Step 3: Create User Profile

Read `$USER` from the environment. Default username is `$USER` (e.g. `khildrak` → suggest `parker` if user wants something nicer; ask).

Print:

```
Creating your user profile.

  System username: {$USER}
  Profile username (used in tags): [{suggested}]
  Display name: [{suggested}]

Press enter to accept, or type a replacement.
```

Wait for input.

Create the profile doc under the "User Profiles" project:

```yaml
---
username: <chosen username>
display_name: <chosen display name>
voice: default
created_at: <ISO-8601 UTC>
---

# {display_name}'s Workflow Profile

Personal overrides for adze-bonch. Lookup chain:
session-override -> project workflow_overrides -> THIS PROFILE -> canonical defaults.

## Voice
default

## Notes
(empty)
```

Tags: `kind:profile`, `user-profile:{username}`, `provenance:user`.

Update the bootstrap-state doc's `user_profile_id` field to the new doc's id.

Print: `Profile created. id: {doc_id}`

## Step 4: Voice (OPTIONAL)

Print:

```
You're using the 'default' voice (no em-dashes, conventional commits, neutral tone).

Three other voices ship as TEMPLATES. To use one, you fork it into your profile:

  - captain-log    Jacob's adze style: nautical, "I [verb]" commits, imagery
  - lax            Playful personal-projects voice, emoji OK
  - professional   Formal work voice, [TICKET-KEY] commit prefixes

Fork one now? (name / no)
```

If the user picks one:
- Read the matching template from `${CLAUDE_PLUGIN_ROOT}/templates/voice-{name}.md`.
- Append its body to the user profile doc, replacing the `## Voice` section content.
- Update profile YAML frontmatter `voice: {name}`.

If `no`: skip.

## Step 5: Tag Existing Projects (OPTIONAL)

Print:

```
adze-bonch uses tags to organize project shape and which repos a project touches.

  shape:work-stream   (default — concept-aligned project)
  shape:ticket        (rare — single ticket as a project)
  repo:<name>         (multi-tag — every repo this project touches)

Tag your existing projects now? (yes / skip)
```

If yes:
- `mcp__adze__projects_list()`
- For each untagged project, ask: shape? (work-stream / ticket / skip), then repos? (comma-separated / skip).
- Apply tags via `mcp__adze__projects_update`.

If skip: move on.

## Step 6: Discoverability Layer (OPTIONAL)

Per D12, discipline lives in adze. To make sure Claude loads it without explicit `/adze-bonch:main`, offer CLAUDE.md trampolines at SAFE PATHS ONLY (never `~/.claude/`).

Print:

```
adze-bonch's discipline rule fires when you invoke /adze-bonch:* commands.
For always-on coverage, install a CLAUDE.md trampoline at one or more of:

  1. Per-project    Append a section to <repo>/CLAUDE.md (you pick which repos)
  2. Workspace      Append a section to ~/workspaces/CLAUDE.md (catches all sessions under workspaces)
  3. Skip           Manually invoke /adze-bonch:main when you need discipline loaded

Pick: 1 / 2 / both / skip
```

For each chosen target:
- Use `bash` to check whether the target file exists.
- If exists, APPEND a delimited section (do not overwrite). Use markers:
  ```
  <!-- BEGIN adze-bonch trampoline -->
  ## adze-bonch
  This repo uses the adze-bonch workflow plugin. At session start, run:
      /adze-bonch:main
  to load the canonical discipline doc and project context from adze.
  <!-- END adze-bonch trampoline -->
  ```
- If the markers already exist, skip (idempotent).
- If the file does not exist, create it with the section.
- Record each successful path under `discoverability_installed_at` in the bootstrap-state doc.

**HARD RULE:** never write under `~/.claude/`. If a candidate target resolves under `~/.claude/`, skip it and warn the user.

## Step 7: Quickstart Printout

Print:

```
adze-bonch is ready.

Commands:
  /adze-bonch:main          Load discipline + project, route to a sub-flow
  /adze-bonch:status        Read-only project snapshot
  /adze-bonch:save          Audit conversation for unpersisted decisions, capture them
  /adze-bonch:setup         (this wizard — re-run anytime; it's idempotent)

Lookup chain (voice, formats, etc.):
  session override  >  project workflow_overrides  >  user profile  >  canonical defaults

Where things live:
  - Adze Workflow Plugin project: canonical reference docs (seeded from this plugin)
  - User Profiles project: your profile doc (1 per user)
  - Your project's context: optional `workflow_overrides` block

Try:
  /adze-bonch:status
  /adze-bonch:main I want to tackle <something>
  /adze-bonch:save
```

That's it. Setup is complete.

## Style Rules

- No em-dashes in running text.
- Each step is one interaction: show the result, then move on.
- Do not over-explain — users reading this already chose to install the plugin.
- Idempotent: re-running setup MUST NOT create duplicate projects, profiles, or seed docs. Always check the bootstrap-state doc first.
