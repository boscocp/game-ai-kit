# T49 — How shooter AI is made

Size: S · Prereqs: T14 · Files: `docs/concepts/`, `tasks/`

## Goal

T36's pattern, for shooters, first and third person: before writing a bot,
read how others have. A survey from both sides -- research and shipped
games -- in the three parts the owner asked for: what **one bot** decides,
how **bots cooperate**, and the **stealth version** of the same bots, where
the player can hide and the bots perceive, grow suspicious, search and call
each other. It ends by writing T51 and T52 in its light.

Every reference is opened before it is cited; what could only be read as an
abstract, slides or an article about the work is said to be so; what could
not be opened is listed and not used.

## Steps

1. One bot: what picks the activity, where it stands, what it perceives,
   how it aims; research and shipped games.
2. Bots that cooperate: emergent, an arbiter, a squad, a commander, a
   director; and what learned teams did.
3. The stealth version: perception that accumulates, alert levels, the last
   known position, the search, and how guards search together; and how
   shipped games keep it fair and readable.
4. Difficulty and cheating: the honest knobs, the pacing tools, the
   admitted cheats.
5. What T51 and T52 take -- 1-3 techniques each that the player toggles --
   and what they leave.

## Acceptance

```bash
test -f docs/concepts/shooter-ai.md
python3 scripts/check_links.py
python3 scripts/check_doc_freshness.py
python3 scripts/check_tiers.py
```

## Manual check

Every reference opens and says what the page says it says.

## Decided on the way (2026-10-18, wave 53)

- **The page is `docs/concepts/shooter-ai.md`.** 48 references, each
  opened. About a third were read only in part -- an abstract, a record,
  slides, a partial extraction, or an article about the work rather than by
  its developers -- and each entry says so. What
  could not be opened -- Isla's occupancy-map chapter, Booth's
  Counter-Strike bot, the Doom 2016 talks, van der Sterren's squad tactics,
  Hitman's crowds, Metal Gear after MGS1 -- is listed and not used.
- **What T51 takes**: positions scored on screen with claims; a commander
  over a shared influence map; squad confidence and retreat in waves.
- **What T52 takes**: a role arbiter (one shooter, one flanker); awareness
  that accumulates, with three alert levels; a shared belief map for the
  search, with a coordinator.
- **Left**: learned bots (tier 1 cannot train them; no shipped source uses
  one), GOAP/HTN for the single bot (T15 compares the ways to decide),
  opponent prediction and a director (later tasks).
