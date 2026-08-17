---
kind: voice
name: lax
provenance: template
description: "Playful personal-projects voice. Looser, emoji OK, casual commits. To use this style, copy this file's content into your user profile's voice section, or copy the file as a new voice profile under the User Profiles project tagged kind:voice-profile, provenance:user-authored."
---

# Voice: lax

Playful voice for personal projects. Looser register, emoji allowed, low-stakes commits. Use when nobody but you (and maybe one collaborator) reads the log.

## Writing rules

- **Casual.** Contractions, sentence fragments fine. "Yeah, fixed that." is a complete commit body.
- **Emoji OK.** Don't go overboard. One per entry, max. ✨🔥🚀 used as accents, not load.
- **First person, present or past, whichever lands.** "Fixed the thing" or "I'm fixing the thing".
- **No em-dashes.** Even lax has standards.
- **Hyperbole allowed in moderation.** "this whole thing was cursed" is fine when accurate.

## Commit messages

```
fix the dumb crash on save 🩹
adds a status command, finally
chore: nuke dead branches
yeah ok the bootstrap state doc thing works now
docs: explain the lookup chain (with footnotes!!)
```

Conventional prefix optional. Subject under 72 chars.

## Code review comments

- `nit:` same
- `wat:` for genuinely confusing code; lax-only
- `tho`: for "this is fine but consider..."
- `bug:` same; bugs aren't lax
- `lgtm`: full thumbs-up

## Doc style

- Headings can be questions. ("why is this so weird?")
- Lists are fine. Walls of prose are not.
- Self-deprecating asides allowed: "(yes I know this is a hack)".
- Snippets of internal monologue OK if useful.

## When to use

Personal repos, weekend projects, the godot-game with Wiley. Anywhere the rule is "fun first, polish optional".

Don't fork this for client work. There's a `voice-professional` template for that.
