---
name: setup
description: "First-time setup wizard for the adze-bonch plugin. Pre-flights the adze MCP, bootstraps canonical reference docs, creates user profile, offers discoverability shims, and optionally installs a SessionStart hook. Per D14: 7-step flow, bootstrap BEFORE identity."
---

# adze-bonch Setup Wizard

You are running the first-time setup wizard for the adze-bonch plugin. Walk through each step sequentially. Show results as you go, then move to the next step.

This wizard implements the 7-step flow locked in D14 (revised per D17). Per D11, it does NOT install rule files into `~/.claude/rules/`; discipline lives in adze. Per D12, it offers safe-path CLAUDE.md trampolines for discoverability.

## Step 1: Welcome + Pre-Flight

Print:

```
Setting up adze-bonch. This will:
  1. Pre-flight the adze MCP server
  2. Bootstrap canonical reference docs into adze
  3. Create your user profile
  4. (Optional) Pick a voice
  5. (Optional) Install CLAUDE.md trampolines for discoverability
  6. (Optional) Install a SessionStart hook
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

### State detection (doc-tag oracle)

Adze projects cannot be tagged, so state detection runs entirely off the bootstrap-state doc's tag. The doc itself carries `kind:bootstrap-state`; project IDs live in its YAML frontmatter.

1. Resolve the tag id:
   ```
   tag_id = mcp__adze__tags_list({ q: "kind:bootstrap-state" }).items[0].id
   ```
   If no such tag exists, create it: `mcp__adze__tags_create({ name: "kind:bootstrap-state" })`.

2. Look up any matching docs:
   ```
   hits = mcp__adze__documents_list({ tag_id: <tag_id>, limit: 1 })
   ```

3. Branch on `hits.total`:

   - **0** -> Fresh install path (below).
   - **1** -> Read `mcp__adze__documents_get({ id: hits.items[0].id })`, parse the YAML frontmatter, extract `adze_workflow_plugin_project_id` and `user_profiles_project_id`. Verify each via `mcp__adze__projects_get`. If either is null or unreachable, fall into the recovery branch (treat as Resume). Then compare frontmatter `plugin_version` to the running 0.2.0:
     - match  -> **Current**. Print "adze-bonch already set up. Re-running optional steps only." Skip to Step 3.
     - older  -> **Upgrade**. Diff `canonical_seeds[].seed_hash` against current seed files; create a new doc + supersede old for any drift. Update `plugin_version` and `last_sync_at`.
     - newer  -> Halt with a warning. Don't downgrade in place.
   - **>1** -> Halt. Per bootstrap-state-template.md ("one per adze instance"), this means duplicate state docs exist. Ask the user to merge or supersede the older one before re-running setup.

### Fresh install path

Before creating, do an adopt-or-rename pre-check for each canonical project. Adze projects cannot carry tags, so name collisions are detected by FTS.

1. Create (or adopt) the canonical reference project:
   - `mcp__adze__projects_list({ q: "adze-bonch reference" })`. If any hit, present the matches and offer adopt (reuse this project id) or rename (let the user supply a different title before create). Do not blind-create over a collision.
   - If no hit, create:
     ```
     mcp__adze__projects_create({
       title: "adze-bonch reference",
       context: "Canonical reference docs for adze-bonch. Seeded from plugin templates. Edits here are live and queryable.",
       status: "active"
     })
     ```
   - Do NOT apply project tags. Adze projects don't support tagging; the bootstrap-state doc's frontmatter records the project id.

2. Create (or adopt) the user-profiles project:
   - `mcp__adze__projects_list({ q: "adze-bonch user profiles" })`. Same adopt-or-rename behavior on hit.
   - If no hit, create:
     ```
     mcp__adze__projects_create({
       title: "adze-bonch user profiles",
       context: "Personal workflow profiles for adze-bonch users. One doc per user, tagged user-profile:{username} and kind:profile.",
       status: "active"
     })
     ```
   - Do NOT apply project tags.

3. Seed canonical docs from the plugin's `seeds/` directory. For each file in `seeds/*.md`:
   - Read the seed file from disk (the plugin install path; resolve from `${CLAUDE_PLUGIN_ROOT}/seeds/` or known marketplace path).
   - Compute a SHA256 of the file content (call it `seed_hash`).
   - Create a document under the "adze-bonch reference" project with:
     - `title` = the file's first H1 line, or the filename if no H1
     - `context` = the file body verbatim
     - tags: `provenance:canonical`, `kind:reference`, `concurrency:strict`, plus the seed-specific kind:
       - `workflow.md` -> `kind:workflow`
       - `named-protocols.md` -> `kind:protocols`
       - `discipline.md` -> `kind:discipline`
       - `bootstrap-state-template.md` -> `kind:bootstrap-state-template`
       - `voice-default.md` -> `kind:voice-profile` (replaces `kind:reference` for this one; still `provenance:canonical`, `concurrency:strict`)
       - `progress-format.md` -> `kind:progress-format`
       - `branch-naming.md` -> `kind:branch-naming`
   - Record the resulting `document_id` and `seed_hash`.

4. Write the bootstrap-state doc under "adze-bonch reference":
   ```yaml
   ---
   plugin_version: 0.2.0
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
     - file: progress-format.md
       document_id: <id>
       seed_hash: <sha256>
     - file: branch-naming.md
       document_id: <id>
       seed_hash: <sha256>
   user_profile_id: null
   discoverability_installed_at: []
   session_hook_scope: null
   session_hook_installed_at: null
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

Create the profile doc under the "adze-bonch user profiles" project:

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

## Step 5: Discoverability Layer (OPTIONAL)

Per D12, discipline lives in adze. To make sure Claude loads it without explicit `/adze-bonch:main`, offer CLAUDE.md trampolines at SAFE PATHS ONLY (never `~/.claude/`).

Print:

```
adze-bonch's discipline rule fires when you invoke /adze-bonch:* commands.
For always-on coverage, install a CLAUDE.md trampoline:

  1. Workspace (RECOMMENDED)  Append a section to ~/workspaces/CLAUDE.md.
                              Catches every session started under ~/workspaces/.
                              Local-only, never enters a git index, no leak to collaborators.
                              One install, every repo benefits.

  2. Per-project (advanced)   Append a section to <repo>/CLAUDE.md.
                              ONLY pick this if your team also uses adze-bonch and you want
                              the trampoline shared via git. Otherwise this pollutes the
                              repo with personal workflow.

  3. Skip                     Manually invoke /adze-bonch:main when you need discipline loaded.

Pick: 1 / 2 / both / skip   [default: 1]
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

## Step 6: SessionStart Hook (OPTIONAL)

A SessionStart hook runs at the start of every Claude Code session. Installing one here makes adze-bonch inject a session-start reminder to load its discipline and project status by running `/adze-bonch:main`. The hook does NOT run that command for you; it only surfaces a prompt at session start so the discipline gets loaded without you having to remember. You (or Claude) still invoke `/adze-bonch:main` to actually load it.

Print:

```
Want a SessionStart hook to load adze-bonch at session start?

  1. No hook (default)    Do nothing. Run /adze-bonch:main manually when needed.

  2. This project only    Install into <current-project>/.claude/settings.json.
                          Does NOT write to ~/.claude/.

  3. All projects         Install into ~/.claude/settings.json.
                          This is the one sanctioned, explicit exception to the
                          plugin rule "never write under ~/.claude/" and applies
                          only because you are opting in here directly.

Pick: 1 / 2 / 3   [default: 1]
```

If the user picks **1** (or presses Enter): skip. Update bootstrap-state: `session_hook_scope: null`, `session_hook_installed_at: null`.

If the user picks **2** or **3**:

Resolve the target path:
- **2**: `<current-project>/.claude/settings.json` (resolve `<current-project>` from the current working directory or project root).
- **3**: `~/.claude/settings.json`.

**Install (surgical merge, never clobber):**

1. If the target file exists, read and parse it as JSON. If it does not exist, start from `{}`.
2. Idempotency check: inspect every string under `hooks.SessionStart[*].hooks[*].command` for the substring `adze-bonch`. If any match is found, the hook is already installed. Print:
   ```
   adze-bonch SessionStart hook already installed at: <path>. Skipping.
   ```
   Record the existing scope and path in bootstrap-state and proceed.
3. If not found, merge the following entry into `hooks.SessionStart` (append if the array exists, create if it does not). Preserve all pre-existing keys:
   ```json
   { "hooks": [ { "type": "command", "command": "echo '[adze-bonch] session started -- run /adze-bonch:main to load discipline and project status'" } ] }
   ```
4. Write the merged JSON back to the target path, pretty-printed.
5. Print:
   ```
   SessionStart hook installed at: <path>
   ```

**Record** in the bootstrap-state doc:
- `session_hook_scope`: `"project"` (choice 2) or `"global"` (choice 3)
- `session_hook_installed_at`: the resolved absolute path to settings.json

**Removable:** the command string contains the literal text `adze-bonch`, so a future uninstall can locate and remove exactly this entry from `hooks.SessionStart` without touching other hooks in the file.

## Step 7: Quickstart Printout

Print:

```
adze-bonch is ready.

Commands:
  /adze-bonch:main          Load discipline + project, route to a sub-flow
  /adze-bonch:status        Read-only project snapshot
  /adze-bonch:save          Audit conversation for unpersisted decisions, capture them
  /adze-bonch:setup         (this wizard, re-run anytime; it's idempotent)

Lookup chain (voice, formats, etc.):
  session override  >  project workflow_overrides  >  user profile  >  canonical defaults

Where things live:
  - adze-bonch reference project: canonical reference docs (seeded from this plugin)
  - adze-bonch user profiles project: your profile doc (1 per user)
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
- Do not over-explain: users reading this already chose to install the plugin.
- Idempotent: re-running setup MUST NOT create duplicate projects, profiles, or seed docs. Always check the bootstrap-state doc first.
