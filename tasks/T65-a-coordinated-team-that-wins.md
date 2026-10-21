# T65 — A coordinated team that wins

Size: M · Prereqs: T51 · Files: `docs/concepts/`, `godot/game3d/botmatch/`, `godot/test/botmatch/`, `tasks/`

## Goal

T51 measured what its three techniques do, and the result went against the
task's expectation. Claims keep a squad off one spot, the commander spreads
the team over the points, and retreat loses fewer bots per point given up.
But a team with all three on loses to the same team with any one of them
off: on that arena caution loses to aggression
(`docs/godot/botmatch.md`). The owner chose, on 2026-10-21, to state it,
and to give "a coordinated team that wins" a task of its own.

Studied before anything is tuned ([research before tuning]): what in a
shipped bot match makes holding, spreading and falling back pay?

## Steps

1. **Read first.** For Unreal Tournament's domination and Killzone's
   warzone bots, find what rewards a defender: spawn placement and respawn
   waves, how contested capture works, how big a point is against how far
   a defender sits, ticket and score rules. For each, write down what the
   source says and where it was read, and open every source before citing
   it, as T49 did. Write it into `docs/concepts/shooter-ai.md`.
2. **Propose**, from that reading, the fewest rule changes that should
   make coordination pay. State each one's expected effect as a number
   before measuring it. The owner picks among them.
3. **Measure** with `botmatch_effects.gd`, and add the claim T51 dropped:
   a team with every technique on holds points longer than the same team
   with any one of them off, by a margin stated in the header.
4. If no change from the reading makes it true, say so, and stop.

## Acceptance

```bash
make test-botmatch-effects
python3 scripts/check_doc_freshness.py
```

## Manual check

Watch a match where blue has everything on and red has the commander off.
Can you see why blue holds more points, before the score says so?
