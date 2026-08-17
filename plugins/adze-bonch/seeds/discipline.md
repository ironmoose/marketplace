# Adze Discipline

*Authoritative as of 2026-05-10. Loaded by every adze-bonch command at top of execution. Per D11, this is the load-bearing rule. Edit this doc in adze (not in the plugin repo) to evolve discipline live.*

This doc is the rulebook for using adze effectively. Every rule traces to a real incident; new rules get added the same way. Plus the three named protocols every agent must respect.

## TL;DR

Five baseline rules:

1. **Synchronous decision persistence:** write to adze before the next response.
2. **Supersede pattern:** never delete history. Prepend a SUPERSEDED notice.
3. **Authoritative-doc convention:** versioned title, dated header, TL;DR, Open Questions, Decisions Locked.
4. **Memory vs adze split:** user-level facts go to memory; project content goes to adze.
5. **Project context updates aren't optional:** when a project pivots, `projects.context` changes, not just docs.

Three named protocols (see `named-protocols.md`):

- `[GOVERNANCE]`, `[PLAN-TEST-CONFLICT]`, `[SCOPE-EXPANSION]`

---

## Rule 1: Synchronous decision persistence

**When a decision is made in conversation, write it to adze before the next response.**

Don't accumulate decisions in conversation context and batch-write at session end. Conversation context evaporates; adze persists. The cost of writing one doc mid-flow is small; the cost of losing a decision tree across sessions is large.

**Triggers (write happens immediately):**
- Direction pivot ("we're going X instead of Y") -> update project context + supersede conflicting docs
- New playbook / pipeline / workflow defined -> create new dated doc
- Open question resolved -> update relevant doc, remove the question
- Reference / artifact captured (image, file, link the user shared) -> save to `~/workspaces/notes/<project>-*` + create adze doc pointing to it
- Tooling chosen / rejected -> update authoritative playbook, "Decisions Locked" section
- Approach abandoned -> supersede the doc that prescribed it

**Non-triggers (no adze write needed):**
- Exploratory chatter ("what if we tried X?") that didn't land
- Read-only research / web searches (unless they produce a decision)
- Implementation details inside an already-decided approach
- Reversible UI tweaks during live iteration

**Source incident:** Deathblood Lazer art-direction conversation 2026-05-09. Six docs batch-written at end-of-conversation when user asked "have we saved this to adze?"

The hammer for catching missed writes: `/adze-bonch:save`.

**Session-resume trailhead:** the canonical resume state for a project lives in its Project Pulse, one document per project tagged `kind:pulse`. `/adze-bonch:save` updates the Pulse synchronously alongside any decision writes, and `/adze-bonch:main` and `/adze-bonch:status` load it first when entering a project. See the Project Pulse section in `workflow.md` for the full three-section shape and the one-per-project rule.

---

## Rule 2: Supersede pattern (never delete history)

**Stale docs get a SUPERSEDED notice prepended; original content stays below.**

When a doc becomes obsolete:

1. Prepend a clearly-marked notice block at the very top:
   ```
   # SUPERSEDED <YYYY-MM-DD>

   <one-line summary of what changed>

   New authoritative doc: **<title>** (id: <id>)

   What's replaced: <bullet list>
   What carries forward: <bullet list>
   ```
2. Rename title to `[SUPERSEDED <YYYY-MM-DD>] <Original Title>`
3. Original content stays below an `# (Original content below)` separator. Don't delete.

**Why:** institutional memory. Future-you (or another agent) might need to know *why* something was rejected. Deleting history forces re-litigating old decisions.

**Source incident:** Deathblood Lazer Huntdown playbook + PixelLab research docs needed to be invalidated without losing the still-useful Godot integration patterns and AI-art gotchas embedded in them.

---

## Rule 3: Authoritative-doc convention

For any "playbook" / "pipeline" / "spec" doc that other docs depend on:

- **Versioned title:** `<Topic> Playbook v2 - <Direction> (YYYY-MM-DD)`
- **Top-of-doc header:** `*Authoritative as of <date>. Supersedes <list of doc IDs>.*`
- **TL;DR section** at top: 3-bullet summary
- **Open Questions** section near the bottom: checklist of unresolved items
- **Decisions Locked** section at the very bottom: bullet list of choices that are no longer up for debate

**Why:** an agent loading the doc cold should know in 10 seconds: is this current? what's settled? what's still in flux?

---

## Rule 4: Memory vs adze split

**Memory** (`~/.claude/projects/.../memory/*.md`):
- User-level facts (role, hardware, preferences)
- Cross-project feedback rules ("user prefers X", "never do Y")
- References to external systems
- Cross-session collaboration discipline

**Adze project context** (`projects.context`):
- The project's purpose, scope, status, summary
- Stable architectural decisions
- The "if I came back in a month, what's this about?" answer

**Adze docs** (under a project):
- Playbooks, specs, research reports
- Capture-then-supersede artifacts
- Anything that might need to be replaced when direction changes

**Adze tasks** (under a project):
- Active work items with state
- Things with a deadline or owner

**The rule:** if it's about the *user* or *how I should behave*, it's memory. If it's about a *project's content*, it's adze. Don't conflate.

**Note:** per the user's no-dotclaude-writes policy, agents must not write to `~/.claude/` during work sessions. Surface memory updates as a Tab task in the `claude-config-sessions` project for a dedicated config session, OR write to `~/workspaces/notes/` instead.

---

## Rule 5: Project context updates aren't optional

When a project pivots, the **project context** (not just docs) must reflect the new direction.

The project context is what an agent sees first when querying the project. If it's stale, every doc downstream gets read against the wrong frame.

**Triggers for project context update:**
- Aesthetic / direction pivot
- Tooling stack change
- Scope expansion or contraction
- Hardware / platform change
- Status change (active -> stalled -> archived)

---

## Concurrency convention (D4)

- Reference docs (`concurrency:strict`): re-read with `documents_get` before writing IF last read was >60s ago. Skip otherwise.
- Tasks (default `concurrency:lax`): skip the re-read.

---

## Lookup chain for settings (D6)

When resolving any workflow setting (voice, ticket-prefix-pattern, formats, etc.):

1. Session override (user's current message)
2. Project `workflow_overrides` block in `project.context`
3. User profile doc (tagged `user-profile:{username}`)
4. Canonical default (this doc / the relevant seed)

First hit wins. Cache for the duration of the turn.

---

## Named protocols

Three flag-words sub-agents emit to communicate plan/scope/conflict signals:

- `[GOVERNANCE]`: plan/scope/timeline change. Surface to user always.
- `[PLAN-TEST-CONFLICT]`: RED test conflicts with plan. Halt implementer.
- `[SCOPE-EXPANSION]`: implementer wants a file outside the planned surface. Requires user approval.

Full spec in `named-protocols.md` (loaded alongside this doc). The orchestrator scans agent output for these tokens and routes them appropriately.

---

## Open Questions

- [ ] Hook automation feasibility (PostToolUse hook that fires on `mcp__adze__*` to enforce write-before-respond)
- [ ] Pre-flight check: should every conversation that touches an adze project start with a `projects_get` + "what's the latest playbook here" check?
- [ ] Standardized tag set (`superseded`, `playbook`, `decision-log`, `open-question`)
- [ ] Folder organization heuristics (when does a project benefit from folders?)

---

## Decisions Locked

- Five core rules above are baseline discipline.
- Three named protocols are mandatory tokens for sub-agents.
- This doc is the canonical home for workflow rules; edits land here, not in scattered locations.
- Per D2, the plugin lives in `~/workspaces/marketplace/plugins/adze-bonch/` until proposed upstream.
- Per D11, no `~/.claude/rules/` install; discipline lives in adze, loaded by every plugin command.
