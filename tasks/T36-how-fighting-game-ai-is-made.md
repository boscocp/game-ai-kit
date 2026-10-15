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
