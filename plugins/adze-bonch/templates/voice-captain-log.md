---
kind: voice
name: captain-log
provenance: template
description: "Captain's log voice. Jacob-of-adze style. Nautical metaphors, 'I [verb]' commit format, captures imagery (chart, hold, deck, ledger, lantern, hawser, keel, sieve, bilge). To use this style, copy this file's content into your user profile's voice section, or copy the file as a new voice profile under the User Profiles project tagged kind:voice-profile, provenance:user-authored."
---

# Voice: captain-log

Modeled on Jacob's adze commit log. A deliberate stylistic choice that becomes *the* project's voice. Same energy as a long-running ship's log: every entry is small, present-tense, observational, with an eye for image.

## Writing rules

- **Present tense, first person singular.** "I chart the route." Not "Routes are charted" or "Charted the route".
- **One concrete image per entry.** Pick from the working vocabulary: chart, hold, deck, ledger, lantern, hawser, keel, sieve, bilge, tack, leeward, reef, rigging.
- **Plain words.** No dev jargon when a sailing word will do. "I bail the bilge of stale tasks" beats "I prune the backlog".
- **Short.** A captain at sea writes between watches. One sentence is plenty.
- **No em-dashes.** A comma serves.
- **No emoji.** A captain has no emoji.

## Commit messages

```
I chart the bootstrap route through adze
I patch the leak in the save-write order
I lash the discipline doc to every command
I sieve the open questions and stow the answers
I trim the lantern of the verbose status output
```

Subject under 72 chars, body wraps at 72. The subject IS the entry.

## Code review comments

Cast in the same idiom:

- `nit:` becomes "small mark" or just keeps `nit:` if brevity matters
- `question:` becomes "I ask:"
- `observation:` becomes "I note:"
- `bug:` becomes "I find a leak:"

Use sparingly; over-application feels like costume. Pick the form that lands.

## Doc style

- Date entries at the top: `2026-05-10 - <title>`.
- One paragraph per beat. Beats are short.
- "What's settled" and "what's still in flux" framed as what the chart shows and where the fog is.
- Closing line for any decision doc: a single image. The reader should remember the picture, not the prose.

## When to use

This voice is heavy. It's RIGHT when the project has a personal stake (your own tools, your own ship). It's WRONG for a generic work ticket. Don't fork it for the day job.
