# T46 — The learned blue commits to a fight

Size: M · Prereqs: T44, T45 · Files: `godot/game/tactical/learned_blue.gd`, `godot/test/`, `docs/`

## Goal

One threshold -- attack at p(win) 0.5, retreat below it -- is the setup that
flickers, and T44 watched it: a unit ran out of reach, walked back, and ran
again, every other turn. Stopping at the edge of the threat's reach ended
the running and not the draws. The references
([docs/design/tactical-references.md](../docs/design/tactical-references.md),
§2.1 and §2.3) agree on three things: two thresholds, one to commit and a
lower one to give up (hysteresis, a thermostat's two set points); a
remembered commitment, so a fight once started is not re-decided from
nothing; and joining a fight already started, after Wesnoth's
`attack_close` -- which, read in its source, only lets an attack within three
hexes of one already made this turn pass a check that refuses near-hopeless
attacks. Carrying that over to retreat, so pieces join a fight instead of
leaving one at a time, is this board's own rule, and is said as one. Wesnoth also retreats on the
power of the two sides near a unit, not on one fight's odds.

This stays the lesson T44 kept from the skirmish: a probability against a
threshold, on screen. Now two thresholds, both drawn.

## Steps

1. Commit at p(win) >= 0.55, give up below 0.35 -- the numbers are starting
   points, measured and then written down with why. A unit's commitment is
   held for the game in the controller, never saved (it is not training:
   invariant 6).
2. Join the fight: no retreat for a walker within three cells of an attack
   its side made this turn -- a rule of this board's, after Wesnoth's
   `attack_close`, measured with and without.
3. Retreat on the side's strength near the unit rather than on its own best
   fight, or say with a measurement why not.
4. `tactical_win_rates.gd` counts flips: a unit that advanced and retreated
   on consecutive turns.

## Acceptance

```bash
make test-godot
make tactical-win-rates GAMES=20 LIMITS="--at-most rl:flips-percent:25 --at-most rl:draw:10 --at-most lr:draw:10"
```

The suite must hold: a unit at 0.45 that committed at 0.6 keeps attacking;
one at 0.3 gives up; a unit beside a fight its side joined this turn does
not retreat.

## Manual check

Play three games against the learned blue: its pieces should be seen to
gather, then attack together, and the overlay should say which threshold
decided each one.
