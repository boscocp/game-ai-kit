# T40 — An evade, and levels that are hard enough

Size: M · Prereqs: T18, T37, T38 · Files: `spec/frames/`, `godot/game/fighting/`, `godot/test/`

## Goal

The owner played T18's manual check and found the clone, the two ghosts and
T17's learner hard to tell apart, and every opponent very easy -- the fixed
hard one only a little harder than the rest. The owner's guess: the game,
not the AI. With no evade there are few choices, and opponents with few
choices look alike and are easy to read.

So two things, measured separately:

1. **An evade** -- a backdash, a quick hop backwards with a few frames in
   which strikes pass through, and recovery that a read punishes. It is the
   move fighting games give a player who wants out without guarding, and it
   gives every opponent here one more choice to differ in.
2. **Levels that are hard enough.** Hard should beat a person who is
   learning, often. T37's knobs stay honest -- reaction never under 15
   frames, no reading the controller -- so what can change is tactics and
   execution, and the options each situation offers once the evade exists.

Before writing it, read how shipped fighting games build a backdash
(invulnerable frames, distance, recovery) and write the source down, as T36
did; the frame data is a design choice and its numbers need a reason.

## Steps

1. The backdash in the frame data and in `FightRules`: its input, its
   frames, which of them strikes pass through, and the resolution order
   updated and tested rule by rule. The recorded log still replays to its
   digests, or is recorded again on purpose (`make record-replay`).
2. `FightAction` reads it as an action, "evade", so T17's n-gram and T18's
   rows see it; the rows are cut again, and the owner's recordings, which
   have no evade in them, say so.
3. The fixed opponent gains the evade among its options, and an answer to a
   player who evades too often.
4. Hard is retuned and measured: T37's ordering still holds (each level
   beats the one below 60 times in 100), and hard beats a scripted
   stand-in that plays like a learning person a stated number of times.
5. T18's comparison is run again on new recordings with the evade, and its
   page says whether the opponents became easier to tell apart.

## Acceptance

```bash
make test-godot
make test-replay
make test-opponent-levels
make test-clone-rows
python3 python/gameaikit/cloning/compare.py --report
```

## Manual check

Play hard: it should win more often than not against you, without ever
reacting faster than a person could. Then play the clone, the ghosts and
the learner again, and say whether they can now be told apart.
