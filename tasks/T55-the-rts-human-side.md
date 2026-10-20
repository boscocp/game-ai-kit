# T55 — The RTS's human side: a clock's knobs, and the league in real time

Size: M · Prereqs: T20, T25 · Files: `godot/game/rts/`, `godot/game/league/`

## Goal

The half of T20's step 7 that needs a person's play as its reference, split
off on 2026-10-20 (T20's "Split"). T20 ships the RTS with its difficulty
levels on T12's strength axis; this task adds the axis T25 measures --
how human a side looks -- where only a clock makes it measurable.

## Steps

1. **The clock's knobs, on T25's human-likeness axis**, each a named knob
   documented beside T12's and T25's: a reaction delay between seeing
   something and the first command about it, drawn from the owner's
   recorded play rather than invented; and a cap on actions per minute in
   the spirit of AlphaStar's ("22 agent actions per 5 seconds"). Both are
   limits, never gifts: a side with them on sees, earns and may order
   exactly what it did without them.
2. **T25's league on the RTS board**: its teams as `RtsController`s, every
   team against every other over a fixed seed set, both sides each, with
   actions per minute and reaction time added to its human-likeness
   measures.
3. **T25's meter, in real time**: each team's share of T19's frame budget,
   drawn beside its units while the match runs.

## Acceptance

```bash
make check
```

The command that plays the RTS league prints both scores per team, with
their uncertainty, and asserts that every knob of step 1 costs strength
without handing anything over (a side with the knob on never sees, earns
or orders more than the same side with it off, over the seed set).

## Manual check

Play the middle difficulty with the human-likeness knobs on and off, and
say whether the one with them on reads more like a person's play.
