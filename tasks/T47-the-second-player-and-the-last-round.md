# T47 — The side moving second, and a last round that decides

Size: M · Prereqs: T45 · Files: `godot/game/tactical/`, `spec/combat/rules.json`, `godot/test/`, `README.md`

## Goal

Rules against rules, the side moving first won 58 of 60 games in T26 and 20
of 20 with the points in T44. Every game in the genre has met this, and
they answer it with a small, stated counter for the second player
([docs/design/tactical-references.md](../docs/design/tactical-references.md),
§1.5): Wargroove's half-turn advantage, extra starting gold equal to the
income going second costs, a pre-recruited unit, or more health on the
second player's building; Advance Wars By Web's "predeployed infantry for
the second player is the tried-and-true way".

And a game that reaches round 40 is a draw, which T44's learned blue reached
in 17 of 20 games. Advance Wars By Web's day limit gives it to the side with
the most properties, and Polytopia's Perfection mode to the higher score
(§1.4). The reference's own caveat stands: on its own that only turns a
stalemate into a win, so it comes after T45 and T46, which give the game a
reason to end sooner.

## Steps

1. Sweep the counters as data, in the rules file: blue's starting funds
   (+1.5 rounded, +3), a blue shield placed at the start, more health on
   blue's workshop. Keep the smallest that lands red's mirror win rate in
   40-60%, and write the sweep down.
2. At the round limit the higher score wins: the workshop's health, then the
   rounds spent holding points, then the cost of what is left standing. A
   draw only on an equal score -- and a test plants an equal position and
   must get one.
3. The screen states both rules before the first move, and the README's
   tactical line follows.

## Acceptance

```bash
make test-godot
make tactical-win-rates GAMES=100 LIMITS="--at-most rr:red:60 --at-most rr:blue:60 --at-most rr:draw:5"
```

## Manual check

Play red three times against the rules: the owner says whether blue's
counter is visible and whether a game that runs long still feels decided.
