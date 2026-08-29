# Reviewer agents

This directory holds the agent definition files for the `adze-bonch` tackle lifecycle. This README documents the reviewers that make up the parallel quality gate, plus the repro-verifier that runs after it.

Per the plugin README, the quality gate runs its reviewers in parallel on standard workflows: code-reviewer, acceptance-qa, edge-case-qa, code-smells-reviewer, test-reviewer, self-containment-reviewer, comment-claim-verifier. The diff is pinned to a base SHA resolved against the remote ref, so a stale local base cannot feed reviewers a superset of the change. Findings are consolidated only once every reviewer has returned a real result.

Every reviewer below declares `tools: Read, Grep, Glob` and states in its own file that it is read-only: it returns structured findings to the orchestrator and never modifies files.

## code-reviewer

**What it does.** The agent file's `description` reads: "Reviews every changed file against the project conventions injected by the orchestrator. Returns structured findings with file, line, severity, and suggested fix. Spawned in Step 4c of standard workflows as part of the quality gate."

The file states that it enforces the conventions the orchestrator injected for the target project, that every finding it reports must cite a specific injected rule by name or description, and that it carries no fixed rule set and does not look up conventions itself. If it was not provided project conventions, it notes that at the top of its output and reviews only for universally bad patterns (unsafe casts, exception swallowing, obvious layer violations), and does not invent rules. Its spawn prompt may also name a language conventions overlay, which it applies and cites like any other injected rule; precedence runs target repo `CLAUDE.md` first, then the overlay, then general good practice. The file also instructs it to check its own suggested fix before proposing it, and to report clean explicitly, because silence is not the same as clean.

**Why it exists.** In the author's words: "First one, the obvious one. But it doesn't have opinions of its own. It only reviews against the conventions in that repo, and every finding has to point at one of them. If it can't cite your rule, it can't file it."

File: [`code-reviewer.md`](code-reviewer.md)

## test-reviewer

**What it does.** The agent file's `description` reads: "Read-only reviewer that examines test code quality. Catches hollow assertions, over-mocking, bloated permutation tests, ignored existing test infrastructure, and AI-generated test smells. Spawned at Step 4c (quality gate)."

The file gives it one central question for every test: "Would this test fail if the production code it claims to cover was deleted or broken?" If the answer is no, the test is hollow. It filters the changed files to test files only, and if the changeset includes no test files it reports "No test files in changeset" and stops. It works through a Test Smells Catalog whose categories include Hollow Assertions (asserting the mock, tautological assertion, no assertion, asserting setup rather than behavior), Over-Mocking (testing the wiring, mock leak, spy overkill), and Bloat. It does not flag pre-existing test issues in unchanged files, and it does not enforce test count minimums.

**Why it exists.** In the author's words: "AI writes tests just to have tests. I had a five-line fix come back with a thousand lines of tests, and it wasn't reusing any of the fixtures already sitting there. Test bloat is the worst."

File: [`test-reviewer.md`](test-reviewer.md)

## self-containment-reviewer

**What it does.** The agent file's `description` reads: "Read-only reviewer that verifies every committed-facing artifact in the diff is self-contained, fully understandable by a brand-new engineer with zero access to the author's local scratch files and zero memory of this task's private history. Flags leaked local scratch directory paths, internal plan-label shorthand (C1/C2/C3, D1/D2, similar), leaked session identifiers, private process/history references, person names, and dangling context. Spawned at the quality gate."

Its single question, quoted from the file, is: "Would a brand-new engineer with ZERO access to the author's local scratch files and ZERO memory of this task's private history understand this fully? If it points at something they cannot see, it is a leak." Its review surface is code comments, `CLAUDE.md` files, committed markdown and doc files in the diff, test descriptions, and fixture strings and test data. The file states that a regex hook already runs at commit time and misses semantic leaks, so this agent's value is judgment rather than pattern-matching. It does not review prose quality, grammar, spelling, tone, or wording, and it does not review local scratch files, which are never committed and are out of scope. For each leak it reports the file, line, the exact offending text, severity, why it leaks, and a ready-to-apply self-contained rewrite.

**Why it exists.** In the author's words: "Claude would leave things in the docs and code comments that only made sense from our conversation, or from my own notes. Anybody else reading it would have no idea what it was talking about."

File: [`self-containment-reviewer.md`](self-containment-reviewer.md)

## acceptance-qa

**What it does.** The agent file's `description` reads: "Read-only product-minded QA agent that verifies implementation meets task acceptance criteria. Reads the ADZE TASK description, the approved plan, and the code, then returns a per-criterion pass/fail report with evidence. Spawned at the quality gate."

The file has it extract every acceptance criterion explicitly before verification, verify each against the inlined implementation, and cite concrete evidence (file path and line number, or a clear statement of what is missing) for every pass or fail. Its verdicts are PASS, PARTIAL (addressed but with gaps, or implemented in a way that does not match the described intent), and FAIL (no implementation found, the implementation contradicts the criterion, or a critical piece is missing). It also notes scope drift, work not covered by any acceptance criterion, as informational rather than a failure. It does not review code quality or style, does not suggest refactors, and does not run tests, linting, or any commands.

**Why it exists.** In the author's words: "I ran a ticket end to end and what came out wasn't what the ticket asked for. I didn't catch it until PR time."

File: [`acceptance-qa.md`](acceptance-qa.md)

## code-smells-reviewer

**What it does.** The agent file's `description` reads: "Read-only reviewer that identifies code smells (design issues that are not bugs but make code harder to maintain). Looks for long methods, feature envy, data clumps, primitive obsession, excessive coupling, and other Fowler-catalog smells. Spawned at Step 4c (quality gate)."

The file requires that every finding's suggestion name a concrete change to make, and explicitly rejects "worth documenting", "consider extracting X", "might be worth revisiting", or the smell restated as a command. If the agent cannot name a concrete change, the file tells it to investigate further or drop the finding. It is told to check its own suggestion before proposing it, in case the obvious fix silently does nothing or breaks an invariant elsewhere. Its catalog includes structural smells such as Long Method/Function, Large Class, God Object, and Comment Bloat, for which the file sets a sentence ceiling and instructs the agent to report the sentence count and the concrete cut rather than "too verbose", and forbids judging it proportionally. It does not flag smells in unchanged code, does not flag smells in test files, and does not nitpick.

**Why it exists.** In the author's words: "Claude kept writing shortcut code. It worked, but it was full of smells, and that bugged me because I know better."

File: [`code-smells-reviewer.md`](code-smells-reviewer.md)

## edge-case-qa

**What it does.** The agent file's `description` reads: "Read-only QA agent that thinks like a breaker. Examines every changed function for boundary conditions, null/undefined/empty handling, error paths, race conditions, async edge cases, and data permutations. Returns structured scenarios the test suite should cover. Spawned at the quality gate."

The file frames its job as asking, of every changed function, "What inputs, states, or sequences would make this fail?" It works through a Breaker Mindset checklist covering null, undefined and empty handling, boundary conditions, and the other categories named above, and is told to explicitly consider each category before skipping it. For each scenario it reports the file, line, scenario description, risk level, and a recommendation. It uses the inlined caller bodies to check what data shapes flow in and whether upstream code guarantees the assumptions the function makes. It identifies scenarios but does not write tests, and it does not flag pre-existing edge cases in unchanged code.

**Why it exists.** In the author's words: "I'd fix something in the Word doc export and it'd break somewhere else, because I never ran that exact scenario by hand."

File: [`edge-case-qa.md`](edge-case-qa.md)

## comment-claim-verifier

**What it does.** The agent file's `description` reads: "Read-only reviewer that extracts falsifiable claims from changed comments and docstrings and verifies each one against the code by tracing its data dependencies, not by checking sentences in isolation. Verdicts are Verified / Contradicted / Unverifiable; Contradicted is HIGH severity, including the case where every premise checks out but the conclusion does not follow. Cannot execute code, so a claim that only execution can settle is Unverifiable and, when worth pursuing, handed to the repro-verifier at Step 4c.5. Spawned at Step 4c (quality gate)."

The file states why the lane exists: every other reviewer on the gate reviews code, and none of them review the claims the comments make about that code. A reviewer who reads a comment and moves on has accepted an unverified test result, because the comment told them what the code does and they believed it. The file also notes that agent-written comments are confident, well-structured and plausible in a way terse or stale human comments rarely are, so prose quality is not evidence of code correctness.

Its traversal license differs from its sibling reviewers. For most of them, reading outside the diff is a rare, targeted fallback; for this one the file describes it as the routine, load-bearing mechanism, because a claim like "does not depend on X" or "safe because the caller validates" cannot be settled by the inlined diff alone. It is still told not to free-roam: every Read, Grep, or Glob call should be chasing a specific referent of a specific extracted claim. It evaluates the comment's conclusion as its own claim, separately from its premises, and does not let true premises stand in for a verified conclusion. It does not execute code, does not flag rationale, intent, or non-falsifiable prose, does not flag a comment merely for being vague, and does not report bugs that no comment asserts anything about: its findings are always anchored to a specific quoted claim.

**Why it exists.** This is the seventh reviewer, added later. In the author's account: one of the reviewers found a real bug, described it correctly, and then cleared it because the code comment and the README both said the behavior was on purpose. That is worse than missing it, because now it has been looked at and signed off. So he wrote a reviewer whose only job is to check whether the comment is actually true.

File: [`comment-claim-verifier.md`](comment-claim-verifier.md)

## The repro-verifier is not one of the reviewers

The repro-verifier does not sit on the parallel gate. Per its own `description`, it is "spawned after the Step 4c quality gate consolidates, seeded with the correctness and edge-case findings". Per the plugin README, this step is mandatory with no skip conditions.

It is an "evidence-driven verifier that proves or refutes the static quality gate's findings by writing and running reproduction scripts, and grounds them by running the target repo's own verification commands. Returns a structured REPRO-VERIFIER REPORT with a Confirmed / Proven-safe / Inconclusive verdict per finding." The plugin README describes the same step: the repro-verifier writes and runs reproduction scripts in its own scratch dir and runs the target repo's verification, returning Confirmed, Proven-safe, or Inconclusive per finding.

Unlike the reviewers, it declares `tools: Read, Grep, Glob, Bash, Write`. Its file states that it is read-only toward application code, that its only writable space is the scratch directory named in its prompt, and that it never writes fixes. A finding is not upheld until a script triggers it, and not dismissed until a script runs the exact feared input and shows correct behavior. It does not mark a finding PROVEN-SAFE unless it actually ran the feared input and observed correct behavior: "I could not reproduce it" is INCONCLUSIVE, not safe. Its safety rules forbid touching shared or production infrastructure and destructive operations against any real or shared resource, and limit network access to local package installation.

Note: the agent file and `CLAUDE.md` also describe a second dispatch of this agent, at Step 4d.5 in confirm mode, to re-run each Confirmed finding's own repro against the fixed code. The plugin README's numbered pipeline does not mention that step. The sources describe the repro-verifier's dispatch points differently.

File: [`repro-verifier.md`](repro-verifier.md)

## Known gaps

These are the author's own stated gaps.

- There is no security reviewer.
- Nothing checks that two sides of an interface still agree, so a frontend reading a key the API does not send passes through.
