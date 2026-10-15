# T36 — How fighting-game AI is made

Size: S · Prereqs: T34 · Files: `docs/concepts/`, `tasks/`

## Goal

Before writing an opponent, read how others have. A page that surveys
fighting-game AI from two sides -- the academic literature (the FightingICE
competition and what has been tried in it) and shipped games (the opponents
that imitate a player, and how commercial games set difficulty) -- and ends by
rewriting T37, T17 and T18 in the light of it.

Every reference is checked against its source before it is cited: a title, an
author and a year that were not read are not written down.

## Steps

1. The academic side: what the competitions measure, and which techniques
   placed -- rules, search, learning from a player, reinforcement learning.
2. The shipped side: fixed opponents and how their difficulty is tuned, and
   opponents that learn from a player.
3. How an opponent cheats, and how a player can tell: reading the input before
   it is on screen, reacting faster than a person can.
4. What this kit takes from each, and what it leaves, in T37, T17 and T18.

## Acceptance

```bash
python3 scripts/check_links.py
python3 scripts/check_doc_freshness.py
```

## Manual check

Every reference opens and says what the page says it says.

## Decided on the way (2026-10-15)

- **The page is `docs/concepts/fighting-game-ai.md`.** 26 sources, each
  opened, bar two papers checked from their bibliographic records only, and
  said to be so. Ricciardi & Thill, the wording of Millington & Funge's
  n-gram section, two competition winners' methods, Virtua Fighter 4's and
  Mortal Kombat 11's opponents from their publishers, and any game reading
  the controller could not be checked, and are listed as such, not used.
- **What it changed**: T37 gets three knobs from the sources -- reaction
  (at least the competition's 15 frames), tactics and execution (Street
  Fighter 6) -- and is handed only the past; T17 says plainly that shipped
  games mostly write opponents by hand, and feeds its prediction through
  T37's levels; T18 compares a nearest-neighbour ghost as well.
- **The throw escape window T34 left here**: not needed. Nothing found makes
  it necessary for the opponent model.
- **Not taken**: deep reinforcement learning (tier 1 cannot train it, and
  the sources show it exploiting its training opponent and reacting faster
  than a person) and MCTS on the fighting scenario (worth its own task after
  T18; `FightRules.step` is the simulator it would need).
