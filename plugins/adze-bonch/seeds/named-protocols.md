# Named Protocols

*Authoritative as of 2026-05-10.*

The three named protocols any agent operating under adze-bonch discipline must respect. These are flag-words: when an agent emits one of these tokens, the orchestrator (and the user) know exactly what's happening and what's required.

## TL;DR

- `[GOVERNANCE]`: agent flags a plan/scope/timeline change. ALWAYS surface to user.
- `[PLAN-TEST-CONFLICT]`: implementer can't reconcile a RED test with the written plan. HALT.
- `[SCOPE-EXPANSION]`: implementer wants to touch a file outside the planned surface. REQUIRES user approval before continuing.

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

## Why these three

Every named protocol corresponds to a real failure mode that's expensive to debug after the fact:

- Plans drift silently when nobody flags scope changes; `[GOVERNANCE]` makes drift loud.
- TDD loops get force-fitted when the plan and test disagree; `[PLAN-TEST-CONFLICT]` halts before the implementer hacks one to match the other.
- "While I was here" edits balloon PR diffs and hide bugs; `[SCOPE-EXPANSION]` requires explicit consent.

Sub-agents must learn these tokens. The discipline doc instructs the orchestrator to look for them in agent output and route them to the user immediately.
