# T37 — A fixed opponent, at three honest levels

Size: M · Prereqs: T36 · Files: `godot/game/fighting/`, `godot/test/`

## Goal

An opponent for the fighting scenario that does not learn, at three
difficulties, none of which cheats. T12's rule on the fighting board: the hard
opponent is hard because it decides better, not because it sees more.

The cheat a fighting game is famous for is reading the input: blocking a low
on the frame it is pressed, before a person could have seen it. Here the
opponent reads only the fight as it was a reaction time ago, and the reaction
time is one of the difficulty knobs, in frames, written down.

## Steps

1. A rule-based opponent over the guard, strike and throw triangle of T34,
   implementing `DecisionPolicy`.
2. The knobs: reaction time in frames, how often it punishes what it could,
   and how much noise is in its choice. Three levels, each a set of numbers.
3. A check that the opponent never reads a frame newer than its reaction time.
4. The levels are ordered: each beats the one below it over a fixed set of
   seeded fights.

## Acceptance

```bash
make test-godot
```

## Manual check

Play each level. Easy should be beatable by mashing, hard should not, and none
should block a low you have only just pressed.
