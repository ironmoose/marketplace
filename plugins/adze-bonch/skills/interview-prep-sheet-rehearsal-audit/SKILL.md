---
name: interview-prep-sheet-rehearsal-audit
description: |
  Repair an interview cheat sheet by rehearsing it out loud, because the document
  itself causes delivery failures that re-reading never reveals. Use when: (1)
  preparing for a recruiter screen, hiring-manager round, or panel, (2) building or
  revising a call sheet or anchors doc, (3) running a mock interview, (4) the speaker
  says "doubled" or "a lot" when a real figure exists, (5) a prepped line sounds
  unlike the person who has to say it, (6) a number in the prep docs has no traceable
  source, (7) the interview's running order changes and later sections still assume
  the old one.
author: Claude Code
version: 1.0.0
date: 2026-08-23
---

# Interview Prep: Rehearsal as a Sheet Audit

## Problem

A prep sheet reads fine and still produces bad answers, because the speaker speaks
from the page. Whatever form a fact takes on the sheet is the form that comes out of
their mouth under pressure. Re-reading never catches this. Only saying it out loud to
someone who pushes back does.

Treat the mock interview as a test harness for the document, not just practice for the
speaker. Every stumble is a bug report against a specific line.

## The method

1. Play the actual interviewer, by name, using researched facts: their tenure, what
   they built, what the posting says, what pain the recruiter disclosed. Generic
   interviewers produce generic practice.
2. One question at a time. Let the speaker say "pause" to break character and draft out
   loud. Drafting mid-scene is where the real wording appears.
3. When they stumble, find the line on the sheet that caused it. Patch and commit
   immediately; the reason is fresh now and gone in ten minutes.
4. Let the interviewer surface the objection the speaker failed to pre-empt, rather
   than explaining it as a coach. Being caught teaches it in one rep.

## The four defects a sheet encodes

**1. A summary on the page produces a summary in the mouth.** A bullet reading
"doubled throughput" reliably produces the word "doubled," even when the raw pair is
known. Interviewers stop believing ratios, especially when they intend to repeat the
figure to someone in finance.
Fix: write the raw pair. "13 to 26", not "doubled".

**2. Jargon on the page gets spoken by someone who does not use jargon.** Under
pressure people reach for the phrase they just read. A sheet saying "say n=1" puts
"n=1" in the mouth of someone who would never say it and may not be able to define it
if asked.
Fix: write the spoken version. If the speaker would air-quote a word, it is not theirs.
Swap the word, do not decorate it. If they ask what a word on their own sheet means,
that word is disqualified.

**3. A compressed line loses its plain root and drifts in meaning.** Polishing "honesty
and communication" into a sharper line about priorities and money produced something
the interviewer heard as a budget request, which a manager cannot promise. The sharp
line was the example; the plain statement was the point, and it had been cut.
Fix: say the plain thing first, then the sharp line as illustration. When a line "feels
like it needs more", that is the signal a plainer root was removed.

**4. Unverified claims propagate until they read as fact.** A claim that adoption was
measurable "because installs leave a record" originated in one research write-up, was
copied into an anchors doc, then onto the sheet. No evidence file ever held an install
count, and the distribution mechanism produces none.
Fix: trace every number to primary evidence before it goes on the sheet. Ask what
system would have produced it. Separate what is countable (pull requests, named people,
ticket state transitions) from what is not, and write the honest boundary as a line to
say out loud.

## Order the sheet by call chronology

Put what is needed in the first five minutes on page one and everything else after a
hard visual break. A heavy rule plus a "PAGE 2" heading works as a scroll cue.

Changing the running order invalidates assumptions elsewhere. When the format became
"the call opens with the candidate's questions", a later section still said to ask what
was costing the team most, a question already answered in minute two. After any
reordering, re-read the whole sheet for lines that assume the old sequence and for
material now spent twice.

## Notes

- **The speaker's own corrections are usually right.** When they say a line is not
  something they would say, cut it. If a line sounds like a better version of them than
  they would actually say, it is wrong. Ask for their reason; never infer the motive
  from the artifact.
- **A motive that flatters is usually false.** "I did not need a yes" was replaced by
  "I was not willing to sit idle waiting for the usage cap to reset." The unflattering
  version is truer, comes out without hesitation, and ties back to hard numbers.
- **Commit the sheet to git early.** Prep files often sit untracked, so there is no
  history to diff against when a line changes or vanishes.
- **Keep deep research in a second file.** The glance sheet holds what gets scanned
  mid-call; dossiers and full answers live in files read the night before.

See also: `subagent-edit-verification` for checking the edits made during these fast
patch cycles.
