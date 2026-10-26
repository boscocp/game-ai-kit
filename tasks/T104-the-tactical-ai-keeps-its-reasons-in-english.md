# T104 — The tactical AI keeps its reasons as keys, translated where shown

Size: M · Prereqs: T80 · Files: `godot/game/tactical/`, `godot/game/main.gd`, `godot/test/tactical/`, `godot/test/skirmish/`, `docs/godot/localisation.md`

## Goal

T79 had the tactical teams word their reasons with `tr()` when they decide
(`RuleBasedBlue`, the planners, the learned policy, `TacticalCombat`): the
reason an AI keeps, and the overlay `test-demo-overlays` reads, are in the
language on screen when the decision is made. T80's review found the RTS
and the fighting game doing the same and had them keep a `Sentence` -- the
English key and its values -- worded where it is shown (`RtsThinking`,
`FightingPanel`). The owner's rule is the same everywhere: code and
identifiers stay English, the prose on screen is translated where it is
shown. Bring the tactical match and the skirmish to it.

## Steps

1. Each reason a tactical team gives becomes a `Sentence`
   (`godot/game/sentence.gd`): its key and its values, a value a piece's
   name, a cell, or another sentence. `TacticalDecision.reason` keeps it.
2. `TacticalStatus`, the plan view and the skirmish's panel word it with
   `Sentence.translated`, the pieces' names through their article table.
3. The overlays carry `Sentence.english`; the suites that compare a reason
   compare the English or the key, and no longer need the locale pinned to
   read it.
4. `docs/godot/localisation.md`: drop the T79 precedent T80 recorded.

## Acceptance

```bash
python3 scripts/check_translations_game.py
make test-locale-screen
make test-demo-overlays
make test-decisions
make test-godot-some SUITES="test/tactical test/skirmish"
```

## Manual check

In PT-BR, play a tactical match, switch to English mid-turn: does the last
reason on the panel change language with the rest?
