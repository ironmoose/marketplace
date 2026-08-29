# Agents guide

This plugin breaks the work of finishing a coding task into a team of narrow specialists. The main assistant runs the task from end to end and hands each specialist one small job: pick the workflow, read the codebase, write the tests, write the code, then check the result from several different angles. The single most useful thing to know is this: almost none of these agents can change your files. Eleven of the thirteen below cannot change a single file in your project. Ten of those are strictly read-only, and the eleventh, the repro checker, runs your code and writes scripts but only into a scratch folder of its own. They find things and report them back, and the main assistant decides what to do. Only the implementer and the test writer touch your code. That is why the useful question is never "did an agent look at this?" but "which agent was asked the question that would have caught it?" Each card below answers that. The thirteenth card is the odd one out: the session note writer has nothing to do with finishing a coding task, and is here only because it is the last agent this plugin ships.

### Workflow picker (scrum-master)

**One line:** Decides how much ceremony this task needs before any code is written.

**When it runs:** First, right after the task is loaded from the tracker and before anyone reads the codebase.

**What it looks at:** Only the text it is handed. The task title, description, acceptance criteria, any `kind:` tags, plus a record of how similar past tasks went. It has no Read, Grep, or Glob tools at all and cannot open a single file.

**What you get back:** A short workflow plan naming which agents run, in what order, which ones are skipped and why, whether tests are written first, whether docs need updating, and any risks worth flagging.

**A concrete example of something it would catch:** A task called "Add CSV export for reports" whose description quietly continues "and fix the export timeout while we're in there, and add a `--format` flag to the CLI." That is three separate pieces of work wearing one title. The workflow picker names the seam and proposes splitting it before the branch exists, instead of you finding out at review time that the change touches nine files.

**When it will NOT help:** It is judging a task by its description, not by reality. If the task text says "one-line config change" and the config key turns out to be read in fourteen places, this agent has no way to know. It also cannot veto anything. It recommends, and a person can say "one branch is fine."

### Codebase researcher (researcher)

**One line:** Reads the code around a task and reports what is really there before planning starts.

**When it runs:** After the workflow is chosen, before the plan is written.

**What it looks at:** The repository itself. It reads the project's CLAUDE.md files first, then finds the files the task touches, follows the call chain at least one level past the obvious files to find callers and callees, and checks other services that consume the same API shapes, event payloads, or shared types. When the task depends on how a third-party library actually behaves, it looks the behavior up in real documentation rather than answering from memory.

**What you get back:** A research summary: affected files with reasons, the traced call chain, a description of what the code does today, cross-service impacts, at least two possible approaches with tradeoffs, and an explicit list of risks and things it could not determine by reading. Every claim about a third-party library is labelled as either sourced from docs or an inference.

**A concrete example of something it would catch:** The task says "rename the response field `owner_id` to `ownerId`, it's a one-liner." The researcher greps past the service and finds the admin dashboard in a different repo destructuring `owner_id` off that exact response, plus a background worker keying its dedupe map on it. The rename is not a one-liner, and you learn that before the plan is written rather than after the deploy.

**When it will NOT help:** It never runs anything. Everything it tells you is what the code looks like, not what it does at runtime, so a bug that only appears under real data or real timing is invisible to it. It also does not choose. It hands you two or more approaches and the tradeoffs, and someone else picks.

### Implementer (implementer)

**One line:** Writes the code the plan asked for, and honestly reports every place it did something else.

**When it runs:** After the plan is approved and the branch exists. Under the test-first default the failing tests already exist, and this agent makes them pass. It runs a second time later to fix confirmed review findings.

**What it looks at:** The approved plan, the explicit list of files the plan allows it to edit, the existing code in the area it is changing (so it copies the surrounding style rather than inventing a new one), and the project's CLAUDE.md rules.

**What you get back:** The actual code changes in your working tree, plus a report listing files changed, which plan steps are done or blocked, and two required self-audits: a count of every pattern the repo forbids found in its own changes, and a list of every deviation from the plan with a self-rating of whether a reviewer should accept or push back on it.

**A concrete example of something it would catch:** The plan says to keep an existing streaming hash helper and add a separate small prefix-read for file-type detection, because reading whole multi-megabyte files on every batch operation was measured as too slow. The test that was written first happens to force a full-file read. The easy path is to delete the streaming helper, read the whole file once, and watch everything go green. This agent is required to stop instead, quote the plan, quote the test, and report a plan-versus-test conflict, so nobody merges a performance regression that had a passing test suite.

**When it will NOT help:** It will not touch a file that is not on its approved list, even when that file is obviously where the problem lives. It stops and flags instead, which costs a round trip. It does not review its own code, does not write new tests, does not modify existing tests, and does not run the repo's full lint and typecheck and test suite. If the plan itself is wrong, this agent will faithfully build the wrong thing and tell you it matched the plan.

### Test writer (test-writer)

**One line:** Writes the tests for the change, in the repo's own testing style.

**When it runs:** Usually first, before any code exists, writing tests that are supposed to fail. In non-test-first workflows it runs after the code is written instead. It runs once more at the very end to turn proven bugs into permanent tests.

**What it looks at:** The project's test config to detect the runner and assertion library, and at least one existing test file next to where the new test will live, so imports, mock setup, naming, and structure match what is already there. In test-first mode it works from the planned function signatures rather than from the implementation.

**What you get back:** Test files created or modified, a coverage summary per file, the exact command it ran, and confirmation the tests are green. Anything it noticed but deliberately did not test is listed for the edge case agent.

**A concrete example of something it would catch:** Writing an ordinary error-path test for `createReport` when the template is missing, it discovers the service wraps everything in a `try` that logs and returns `null`. The caller cannot distinguish "no template" from "empty report," and no test can assert the failure because the failure never escapes. It reports that as a production bug rather than quietly writing a test that asserts `null` and calling it covered.

**When it will NOT help:** It is forbidden from touching production code, so when it finds a bug it reports it and moves on. It deliberately stays on the happy path, expected errors, and obvious boundaries like empty arrays and zero counts. Race conditions, timeouts mid-operation, partial writes, and adversarial input are somebody else's job by design. It also will not invent a pattern: if the repo has no mock helper for a new dependency, it flags that rather than building one.

### Code reviewer (code-reviewer)

**One line:** Checks the changed code against this project's own written rules.

**When it runs:** After the code and tests exist, alongside the other reviewers, all looking at the same change at once.

**What it looks at:** Only what it is handed. The change itself, the bodies of the changed functions and their callers, and the project's conventions pasted directly into its instructions. It is told not to go fetch config or convention files on its own.

**What you get back:** A list of findings, each with a file, line number, severity from low to critical, the rule it violates, and a suggested fix. If nothing is wrong it says so explicitly, because silence and clean are not the same thing.

**A concrete example of something it would catch:** A new repository method that takes the notification service in its constructor so it can send an email after the insert. The project's CLAUDE.md says repositories must never depend on services. The reviewer flags it as high severity, names the rule, and suggests moving the send up to the service layer. It also checks its own advice before offering it: if the obvious fix would silently do nothing (a status transition guarded on a state the row is not in, for instance), it says so in the fix rather than sending you down a dead end.

**When it will NOT help:** Every finding must trace to a rule that was given to it. With no project conventions supplied it falls back to universally bad patterns only and will not invent house style. It does not check whether the feature does what the ticket asked, does not hunt for edge cases, does not run anything, and deliberately ignores pre-existing problems in files your change did not touch. It also holds back on speculative advice: it will not tell you to add an index, a column, or an abstraction unless it can name a query or invariant that exists today and needs it.

### Acceptance checker (acceptance-qa)

**One line:** Asks one question per requirement: does the code actually do this?

**When it runs:** Alongside the code reviewer and the edge case agent, on the same finished change.

**What it looks at:** The task's acceptance criteria, the approved plan, and the change with the relevant function bodies pasted in. It is asked not to go crawling the repo; if the code that implements a requirement was not included, it records that as a missing piece rather than hunting for it.

**What you get back:** A table with one row per criterion, marked PASS, PARTIAL, or FAIL, each with evidence: a file and line where the behavior lives, or a specific statement of what is absent. Work that was done but matches no criterion is noted separately as scope drift, which is information rather than a failure.

**A concrete example of something it would catch:** The criterion says "users can filter reports by status." The implementation has a condition covering `draft` and `published`, and the enum has four values. `archived` and `pending` fall through and return everything. Every test passes, because the tests were written against the same two branches. This agent reads the criterion, counts the statuses, and marks it PARTIAL with the two missing ones named.

**When it will NOT help:** It can only check requirements someone wrote down. An unstated expectation is invisible to it. It cannot run the application, so anything you can only see by looking at a screen, like "the user gets a success message," is something it will flag as unverifiable rather than pass or fail. It makes no judgment about code quality, naming, or architecture, and a difference in approach is not a failure to it as long as the observable result matches.

### Edge case breaker (edge-case-qa)

**One line:** Looks at each changed function and asks what input or timing would break it.

**When it runs:** Alongside the code reviewer and the acceptance checker, on the same finished change.

**What it looks at:** The change and the full bodies of the changed functions, plus the bodies of their callers whenever a signature changed, so it can see whether upstream code already guarantees what the function assumes.

**What you get back:** A list of failure scenarios, each with a file, line, risk level, and a concrete recommended change to the code or the tests. Vague advice like "worth documenting" or "consider handling this" is explicitly not allowed. It also lists the scenarios the current test suite most likely does not cover.

**A concrete example of something it would catch:** `listReports({statuses: []})` passes an empty array straight into a database array-match filter. An empty array matches nothing, so the query returns zero rows. The intent was "no filter means everything." The user clears all the filter chips in the UI and the table goes blank. The agent flags it as critical and recommends omitting the clause entirely when the array is empty, plus a test for the empty-filter case.

**When it will NOT help:** It never runs the code, so every finding is a hypothesis until a later agent actually reproduces it. It writes no tests and no fixes. It ignores pre-existing problems in code your change did not touch. And it is deliberately restrained about invented inputs: before claiming a bug that a specific value triggers, it must name where that value came from (a real sample file, a test fixture, a log line). If the honest answer is "I made it up," it is required to report it quietly as a question instead of a defect, so some real-but-unproven concerns land lower than you might expect.
### Design smell reviewer (code-smells-reviewer)

**One line:** Flags design problems that are not bugs but make the code hard to live with.

**When it runs:** After the code and tests exist, alongside the other reviewers, all looking at the same change at once.

**What it looks at:** The change and the full bodies of the changed functions, handed to it directly. Plus the project's own written rules and, for TypeScript or Python, a language style baseline the plugin ships. It skips test files entirely, because tests are held to different design standards.

**What you get back:** Findings with a file, a line, the name of a smell from a fixed catalogue (feature envy, data clumps, flag arguments, magic numbers, leaky abstraction, and about thirty more), a severity, and a specific change to make. "Consider extracting this" is explicitly rejected as a suggestion. It is also required to sanity-check its own advice: if the obvious refactor would break something else, it says so in the suggestion.

**A concrete example of something it would catch:** Comment bloat. Its ceiling is three sentences for any comment or docstring, and it counts them. A five-sentence comment above a helper, explaining that the timeout is 30 seconds, how that number was benchmarked, which release changed it, and which ticket tracked the change, gets flagged with the sentence count and the exact cut: keep the value and the trap it protects against, move the history to the commit message. That rule is written this hard because this reviewer once looked at exactly that comment, answered "mostly earns it," and a person had to catch it by hand.

**When it will NOT help:** It does not hunt bugs, does not check requirements, does not look at test files, and ignores anything in code your change did not touch. It also restrains itself on purpose, so real design problems can land lower than you expect: duplication at only two call sites is a low finding at most, a long procedural route handler is a sequence rather than a smell, and a service calling another injected service is dependency injection rather than feature envy.

### Test quality reviewer (test-reviewer)

**One line:** Asks whether each new test would actually fail if the code broke.

**When it runs:** In the same review round as the code reviewer, once the tests exist. If the change contains no test files, it says so and stops.

**What it looks at:** The changed test files and the production code each one covers, both handed to it directly. Plus whatever the project says about its test framework, fixture setup, and assertion style.

**What you get back:** A list of test files with a test count and a finding count each, a list of shared fixtures and helpers the repo already provides, and findings with a file, a line, a smell name, a severity, and a suggestion.

**A concrete example of something it would catch:** A test named "should return report data" that configures the repository mock to return `{id: '123'}` and then asserts `result.id === '123'`. It passes today, and it would still pass if you deleted the service's entire body and replaced it with a straight pass-through, because the only thing it verifies is the mocking library. The service actually computes several fields on top of that row, and none of them are asserted. That is a high finding, because the test is not weak, it is false confidence.

**When it will NOT help:** It only reads test files, and only ones this change touched. It will not tell you which tests are missing, and it will not write any. It also checks itself before flagging: a call-argument assertion followed later in the same test by a real assertion on the result drops to low, and mocking a repository or an HTTP client is normal and never flagged. And it will not go searching your repo, so "this reinvents a helper you already have" usually comes back as a suspicion to confirm rather than a proven finding.

### Private context leak checker (self-containment-reviewer)

**One line:** Catches comments and docs that only make sense to the person who wrote them.

**When it runs:** In the same review round as the other reviewers. It runs on every kind of change, including a docs-only one.

**What it looks at:** Only the change, handed to it directly, and only the parts of it a human reads: comments, CLAUDE.md entries, committed markdown, test descriptions, and literal strings in fixtures. Logic, types, and control flow are somebody else's problem.

**What you get back:** Findings with a file, a line, the exact offending text, an explanation of what private thing it points at, and a rewrite you can paste straight in. Two severities only: MUST-FIX for a confirmed leak and LOW for a genuinely ambiguous one. There is no informational tier, because a leak that ships is the whole thing it exists to prevent.

**A concrete example of something it would catch:** A shipped service comment reading `// C2: re-attach the stripped fields; C3 handles the enum case`. C2 and C3 were chunk labels in a plan that only ever existed on the author's machine. A human reviewer hit this exact comment and asked "what is C for C2, C3?" The rewrite it hands back is `// Re-attach fields that the mapping function strips (it drops anything not in the target enum); the enum case is handled below.` The same shape catches "reverted per the redirect", "fixed in fix-cycle 2", a path into somebody's home directory, and a teammate's first name used as the reason a feature is behind a flag.

**When it will NOT help:** It says nothing about grammar, tone, wording, or whether a comment should exist at all. It cannot tell you whether a claim is true, only whether a stranger could follow it. And it is cautious to a fault: a bare `T1` might be a generic type parameter or a plan label, and it cannot tell from the change alone, so it files that at LOW with both readings stated and lets a person decide rather than blocking on a guess.

### Comment fact checker (comment-claim-verifier)

**One line:** Checks whether comments and docstrings are actually true of the code beneath them.

**When it runs:** In the same review round as the other reviewers, on every kind of change including docs-only.

**What it looks at:** Every comment and docstring the change touched, including one whose own words did not change but whose code moved underneath it. Unlike its neighbours, this one is expected to read well outside the changed lines. A claim like "safe because the caller validates this" is settled at the callers, not at the comment, so it follows each claim to the assignment, the guard, or the call site it actually rests on.

**What you get back:** A list of every checkable claim it pulled out, each marked Verified, Contradicted, or Unverifiable, plus a written-out finding for each contradiction showing the trace. Contradicted is always high severity. Unverifiable means only running something could settle it, and when the claim is load-bearing it names what a reproduction would have to check and hands it to the repro checker.

**A concrete example of something it would catch:** Its third verdict, and the sharpest thing in this plugin. A bug was "fixed" by moving a call and adding this comment: "open_integrated_terminal() does not depend on wmctrl, it has its own xdotool guard, so it must not live inside the HAVE_WMCTRL branch." Check the sentences one at a time and both are true. The function really does not call wmctrl. The call really is outside the branch. The code is still broken, because the function's only input is a variable assigned in exactly one place, inside the branch the call was just moved out of, so it is empty every time and the guard it promises never fires. Every premise true, conclusion false, and a separate reviewer read that comment and passed the fix. This agent is required to check the conclusion as its own claim rather than adding up the premises, and to mark that case specially when it finds it.

**When it will NOT help:** It cannot run anything, so "idempotent under retry" comes back Unverifiable no matter how carefully it reads. It only extracts claims that could be proved false, so intent ("this is a workaround for a vendor bug"), todos, and opinions are left alone, and a missing comment is never its finding. Vague prose is not a defect to it either. And it will not report a bug that no comment says anything about: every finding is anchored to a sentence somebody actually wrote.

### Repro checker (repro-verifier)

**One line:** The one agent that settles a finding by running code instead of reading it.

**When it runs:** Twice, and neither run can be skipped on any task. First right after the review round, handed every correctness and edge-case finding the reviewers produced. Then again after the fixes are written.

**What it looks at:** The findings, the change, and the repo. It starts by running the project's own lint, typecheck, and test commands the way the project defines them, because a real pass or failure often settles a finding on its own. Then, one finding at a time, it writes a small script that tries to trigger the reported bug and runs it. Its scripts live in a scratch folder outside your repo that survives across sessions. It never edits your code, your tests, or your fixtures, and it never connects to a shared or production system.

**What you get back:** Per finding, CONFIRMED (a script triggered the bug), PROVEN-SAFE (a script ran the exact feared input and the behavior was correct), or INCONCLUSIVE (no honest reproduction was possible). Each verdict cites the exact command and the output that decided it. Confirmed findings get fixed; proven-safe ones get dropped instead of chased. On the second run it re-runs each confirmed finding's own script, unchanged, and that script must now pass.

**A concrete example of something it would catch:** The second run exists because of a specific failure. A confirmed bug was "fixed" by moving a call and adding a comment that was, sentence by sentence, accurate. The repo's test suite was green, because those tests had never covered that case in the first place, and a reviewer read the comment and approved the fix. The defect survived and shipped. Re-running the original script would have taken about ten seconds and would have failed. That is the rule now: a green test suite does not confirm a fix, a good-looking diff does not confirm a fix, only the script that proved the bug, run again, confirms a fix.

**When it will NOT help:** It never writes a fix. It will not touch a shared database, a message broker, or any live endpoint, so a bug that only appears against real infrastructure gets described in words rather than run, and comes back inconclusive. "I could not reproduce it" is inconclusive and never counts as safe. It only checks findings it was handed, so a bug nobody reported is out of reach unless it happens to trip over one, and even then it reports it only with a working script attached. And a passing script proves the one path it walked, which is why it also counts the other routes to the same behavior and marks each one covered or not.

### Session note writer (pulse-writer)

**One line:** Writes the short note that tells your next session where you left off.

**When it runs:** Never during a coding task. It has no place in the sequence above and will not appear while a change is being written or reviewed. It runs when you save your work on a project, or when you first open one, and that is all.

**What it looks at:** Almost everything is handed to it: the project name, a summary of what just happened this session (task ids, document ids, commit hashes, file paths, decisions, and where you stopped), the previous note if one exists, and the writing voice to match. It can read a file or check a path to confirm something it is about to name, and nothing else. It gets exactly one turn and never asks a follow-up question.

**What you get back:** A note under 25 lines in three parts. "Where we left off" is a short conversational paragraph naming real ids and paths so the detail can be fetched. "Next move" is exactly one concrete action. "Open for user" appears only if a question is genuinely waiting. Separately, it sends back a list of everything it trimmed out, each labelled with why, so those can be filed as tasks. It does not save the note itself; a person confirms it first.

**A concrete example of something it would catch:** You spent an evening finishing a migration, half-starting an unrelated refactor, and leaving a naming question open. The obvious note would mention all three, and three weeks later you would read it and not know which one you were in the middle of. This one keeps the migration thread with its commit hash and the single next action, and pushes the refactor out as an item marked "second thread" and the extra idea out as "extra next action". What you come back to is a lead, not a log.

**When it will NOT help:** It tells you nothing you did not already tell it. It works from the summary it is handed and does not go read your repo or your task tracker, so a thin summary produces a thin note, and it gets no second turn to ask for more. It drops your second thread and your spare ideas out of the note by design, so if nobody files the trimmed list as tasks, those are simply gone. And it is not a status report: architecture, decisions, and backlog belong in other places and it will not carry them.
