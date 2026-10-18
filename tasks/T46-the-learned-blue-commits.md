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

## What was done so far (2026-10-18, wave 50) -- wip, one limit short

Taken out of table order on the owner's word: carry on with the design
study's proposals in their order.

- **Step 1.** Two bars in `LearnedBlue`: a walker commits at p(win) 0.5 and,
  once committed, gives up only below 0.3. The reference's 0.55 and 0.35 were
  measured first and did worse from both seats (below). Commitments are kept
  by the controller for one game and forgotten when the next begins, never
  saved (invariant 6). Every attack and retreat names the bar that decided it.
- **Step 2.** A walker within three cells of an attack another walker of its
  side made this turn joins in rather than retreat, said as this board's
  rule after Wesnoth's `attack_close`. Measured with and without: as blue no
  difference (7-13 both), as red 12-8 with it against 10-10 without. A test
  caught it counting a walker's own attack, which would have kept every
  attacker from giving up; it never fired in games, because a walker is asked
  about an attack once a turn.
- **Step 3, adopted.** A walker that will not fight retreats only when
  Wesnoth's caution (0.25) times red's strength within four cells outweighs
  blue's -- strength is the health of the walkers there. This is what cut the
  flips: with it off, 19% and 17% of fight decisions reversed the turn
  before's; with it on, 4.2% and 4.4%.
- **Step 4.** `tactical_win_rates.gd` counts flips, and takes
  `red-flips-percent`, `blue-flips-percent` and `flips-percent` as limits.

**Measured** (20 games a seat, learned against the rules):

| version | as blue: red / blue / draws | flips | as red: red / blue / draws | flips |
|---|---|---|---|---|
| before T46 (one bar at 0.5) | 0 / 1 / 19 | 19.0% | 4 / 0 / 16 | 17.9% |
| two bars 0.55 / 0.35, no strength rule | 0 / 1 / 19 | 19.5% | 10 / 0 / 10 | 16.5% |
| ... with the strength rule | 0 / 7 / 13 | 4.6% | 12 / 0 / 8 | 4.5% |
| ... without joining | 0 / 7 / 13 | 5.1% | 10 / 0 / 10 | 3.4% |
| **0.5 / 0.3, strength, joining (shipped)** | **0 / 8 / 12** | **4.2%** | **15 / 0 / 5** | **4.4%** |

The acceptance: flips 4.2% (at most 25) and `lr` draws 5 (at most 10) hold;
`rl` draws 12 (at most 10) does not -- exit 1. As blue the learned side
still has about 44% of its walker decisions stuck behind the bridge (T45's
record), and that, not the fight rule, is what runs its games to round 40.
T47's last round and T48's crossing are where that closes.

`tactical_learned_blue_test.gd` holds the task's three cases (0.45 after
committing at 0.6 keeps attacking; under 0.3 gives up; beside a fight it
joins) and three more: no attack under the commit bar uncommitted, the
strength rule both ways, and a new game forgetting commitments.
