# Named Protocols

*Authoritative as of 2026-05-10.*

The four named protocols any agent operating under adze-bonch discipline must respect. These are flag-words: when an agent emits one of these tokens, the orchestrator (and the user) know exactly what's happening and what's required.

## TL;DR

- `[GOVERNANCE]`: agent flags a plan/scope/timeline change. ALWAYS surface to user.
- `[PLAN-TEST-CONFLICT]`: implementer can't reconcile a RED test with the written plan. HALT.
- `[SCOPE-EXPANSION]`: implementer wants to touch a file outside the planned surface. REQUIRES user approval before continuing.
- `[UNVERIFIED]`: agent is about to assert something it has not verified from a source. Flag IN THE SAME RESPONSE as the claim.

---

## [GOVERNANCE]

**Use when:** an agent observes a change to the project's plan, scope, or timeline that wasn't sanctioned by the user this session.

**Examples:**
- The plan said "ship feature X this week," and during work a dependency surfaces that pushes the timeline.
- A research finding makes part of the plan irrelevant.
- A new acceptance criterion emerges that wasn't in the original task body.

**Required form:**
```
[GOVERNANCE] <one-line summary>
- What changed: <description>
- Why: <reason>
- Impact: <what this affects in the plan>
- Recommendation: <what the agent suggests doing>
```

**Orchestrator behavior:**
- ALWAYS surface to the user. Never auto-decide.
- Create a task tagged `kind:governance` capturing the flag, even if the user dismisses it. Institutional memory.
- The user's call: accept, reject, defer.

---

## [PLAN-TEST-CONFLICT]

**Use when:** an implementer agent is in a TDD loop and finds the RED test cannot be made GREEN without violating the written plan.

**Examples:**
- Plan says "do not modify module Y," but the failing test asserts behavior that lives in Y.
- Test asserts a return shape the plan says should be different.
- Plan and test agree on intent but disagree on observable behavior.

**Required form:**
```
[PLAN-TEST-CONFLICT] <one-line summary>
- Test: <failing test name + path>
- Test asserts: <what it expects>
- Plan says: <conflicting plan clause, quoted>
- Two reconciliations:
  A) <option A: amend plan>
  B) <option B: amend test>
- Recommendation: <which the agent prefers and why>
```

**Orchestrator behavior:**
- HALT the implementer. No further code changes until the conflict is resolved.
- Surface to the user. Resolve by amending plan, amending test, or splitting into two tasks.
- The amended artifact gets a new doc (per Rule 3) or a `tasks_update` with the resolution recorded.

---

## [SCOPE-EXPANSION]

**Use when:** an implementer wants to modify a file that was NOT listed as part of the task's planned surface.

**Examples:**
- Plan says "edit `src/auth.py`," and the agent realizes `src/db.py` also needs a one-line fix to compile.
- A refactor opportunity surfaces in an adjacent module.
- A typo in an unrelated doc was noticed.

**Required form:**
```
[SCOPE-EXPANSION] <one-line summary>
- Planned surface: <files/modules listed in the task plan>
- Proposed addition: <new file(s) + reason>
- Smallest viable change: <can this be deferred? a one-line stub? a separate task?>
- Risk if not expanded: <what breaks>
```

**Orchestrator behavior:**
- REQUIRES user approval before the agent proceeds.
- If approved, update the task's plan to include the new surface (so future review agents know what was sanctioned).
- If rejected, the agent must either find a smaller change inside the original surface or hand off the proposed expansion as a new task.

---

## [UNVERIFIED]

**Use when:** you are about to state as fact something you have not verified from a source this session.

**Verify first. This token is NOT a license to guess with a label attached.**
Before emitting it, you must have actually attempted the cheap verification:

- WebSearch, official docs, the product's own wiki
- The file, the repo, the working code, the installed artifact (jar manifest, package.json, `--version`)
- Adze, for anything the user tracks there

If any of those would settle it in under a minute, GO GET IT and answer from the source instead. `[UNVERIFIED]` is for claims that genuinely cannot be checked right now. It is not for claims you did not feel like checking.

**Mandatory triggers.** Any one of these means the claim is unverified, no matter how confident it feels:

- **An unfamiliar proper noun.** An item, block, flag, setting, API field, config key, or error string you do not actually recognize. Not recognizing it is the signal. It is not a puzzle to solve from context.
- **A version you cannot place**, or one newer than your training data. If the user's game, library, or tool version postdates your knowledge, every mechanic claim about it is unverified by default until checked against that version's release notes.
- **A claim assembled from circumstantial evidence** rather than read from a source. Clues that "add up" are not verification. Four consistent clues are still zero sources.
- **Any exact number, limit, ratio, filename, or parameter name recalled from memory** rather than read this session.

**Required form:**
```
[UNVERIFIED] <the specific claim>
- Basis: <what it actually rests on: recall / inference from X / pattern match>
- Would settle it: <the exact source, command, or search that would confirm>
- If wrong: <what breaks, or what the user wastes acting on it>
```

**Also required, with or without the token:** confidence language must match the evidence. Do not narrate a recalled claim in the same declarative voice as a verified one. Ruling something OUT from a local source (a mod list, a repo grep, an adze doc) never licenses a positive claim about the thing itself. It only narrows the search.

**Orchestrator behavior:**
- Surface to the user in the SAME response as the claim, never in a later one and never in a closing caveat after the user has already read the claim as fact.
- Prefer fetching the source over emitting the token. Emitting it when a source was reachable is itself a discipline failure.
- If the user then supplies the source (a screenshot, a version number, a path), re-answer from it rather than defending the original claim.

**Source incident:** 2026-08-29. The user asked whether a Minecraft "Sulfur Spike" works as a "drip spike"; the assistant did not recognize the term, but assembled four consistent circumstantial clues (a wandering trader sold it, 2-for-1 emeralds, a spike-shaped icon, the `minecraft:` namespace) into a confident, wrong claim that it was pointed dripstone renamed by a resource pack. It is a real vanilla block from the Minecraft 26.2 game drop (2026-06-16), which postdates the assistant's training cutoff. One web search settled it, and the user had to prompt that lookup himself. The failure was not missing information. It was not noticing that information needed to be fetched.

---

## Why these four

Every named protocol corresponds to a real failure mode that's expensive to debug after the fact:

- Plans drift silently when nobody flags scope changes; `[GOVERNANCE]` makes drift loud.
- TDD loops get force-fitted when the plan and test disagree; `[PLAN-TEST-CONFLICT]` halts before the implementer hacks one to match the other.
- "While I was here" edits balloon PR diffs and hide bugs; `[SCOPE-EXPANSION]` requires explicit consent.
- Confident recall is indistinguishable from knowledge in the output. `[UNVERIFIED]` makes the difference visible to the user at the moment it matters, instead of after they act on it.

Sub-agents must learn these tokens. The discipline doc instructs the orchestrator to look for them in agent output and route them to the user immediately.
