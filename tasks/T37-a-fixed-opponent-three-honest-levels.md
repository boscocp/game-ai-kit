# T37 — A fixed opponent, at three honest levels

Size: M · Prereqs: T36 · Files: `godot/game/fighting/`, `godot/test/`

## Goal

An opponent for the fighting scenario that does not learn, at three
difficulties, none of which cheats. T12's rule on the fighting board: the hard
opponent is hard because it decides better, not because it sees more.

Shaped by T36's survey (`docs/concepts/fighting-game-ai.md`). Shipped
fighting games write their opponents by hand: reactions per situation --
after a hit, a block, a whiff, a knockdown -- with chance in them so they do
not repeat (Soulcalibur V's director). Street Fighter 6 groups those actions
into situational decks and sets difficulty on two axes: how many tactics a
level has, and how well it executes them. The research arena adds the third
axis and fixes it: every AI sees the fight 15 frames late, a person's
reaction time (the FightingICE platform paper).

The complaint players make most about fighting-game opponents is reflexes no
person has -- a low blocked on the frame it was pressed. Whether shipped
games read the controller was not established by T36, and this task makes no
claim about any game. It holds its own opponent to the rule either way.

## Steps

1. A rule-based opponent implementing `DecisionPolicy`: reactions grouped by
   situation -- neutral, after blocking, after being hit, the other fighter
   whiffing, the other fighter crouching -- each a weighted choice over T34
   and T39's options: guard standing or crouching, strike high, mid, low or
   overhead, throw, step in or out.
2. Three knobs, written down per level:
   - **reaction**, in frames -- how old the fight it sees is. At least 15 at
     every level, the competition's number; more at the easy end.
   - **tactics** -- how many of the situations' options the level has.
   - **execution** -- how often a chosen action comes out as chosen rather
     than as a slower or wrong one.
3. A gate: the opponent reads only a `FightState` at least its reaction time
   old, by construction -- it is handed the past, not the present -- and a
   planted opponent that reads the current frame is refused.
4. The levels are ordered: over a fixed set of seeded fights, each beats the
   one below it.
5. The training mode can put it in the dummy's place, and the panel shows
   the situation it saw, the frame it saw it on, and the choice it drew.

## Acceptance

```bash
make test-godot
```

## Manual check

Play each level. Easy should be beatable by mashing, hard should not, and
none should guard a low you pressed less than a quarter of a second ago.
