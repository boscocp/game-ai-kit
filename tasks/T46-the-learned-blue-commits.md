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

## What was done so far (2026-10-18, wave 50) -- wip, two limits short

Taken out of table order on the owner's word: carry on with the design
study's proposals in their order. The first version of this record was
wrong in two ways wave 50's review found, and this is the corrected one.

- **Step 1.** Two bars in `LearnedBlue`: a walker sets out for a fight at
  p(win) 0.5 and, while on its way to *that same red walker*, gives up only
  at or below 0.3. Kept for one game and never saved (invariant 6). The first
  version called any walker that had attacked once "committed" and gave it
  the lower bar against *any* later enemy -- but every fight between walkers
  kills somebody, so there is no fight left to be committed to after the
  blow, and the reason on screen ("it committed to this fight") was false
  every time. Now the commitment ends with the blow. On this board a walker
  only sets out for a fight it can reach this turn, so the way there is one
  walk long and what the second bar decides is the blow after the walk.
  **Measured, it makes no difference:** with and without it, the same games
  to the move (below). It stays because it is correct, cheap and tested, and
  it is the lesson the task names; a board with longer approaches (T48) is
  where it can matter.
- **Step 2.** A walker within three cells of an attack *another* walker of
  its side made this turn joins that fight at any odds rather than retreat,
  after Wesnoth's `attack_close`, said on screen as this board's rule.
  Joining is not setting out: it gives no lower bar later.
- **Step 3, adopted.** A walker that will not fight retreats only when
  Wesnoth's caution (0.25) times red's strength near it outweighs blue's --
  this board's version: strength is the health of the walkers within four
  cells as the crow flies, where Wesnoth weighs what each side can bring onto
  the hex and the terrain's exposure. When it does not retreat it goes on to
  its points or red's workshop, and that walk's reason ends by saying it did
  not retreat, from what, under which bar (invariant 13).
- **Step 4.** `tactical_win_rates.gd` counts flips **by distance**: a walk
  that ended nearer the nearest enemy walker after one that ended further,
  or the other way round, on the walker's side's consecutive turns. The
  first version read reasons, could not see the walks the strength rule
  turns retreats into, and reported 4.2% -- a counting artefact. Counted by
  distance the rules are measured the same way.
- **The scene.** C now cycles blue through the rules, the planner and the
  learned policy, so T44's missing key exists and this task's manual check
  can be done.

**Measured** (20 games a seat, the same seeds; flips by distance):

| version | learned as blue: red / blue / draws | flips | learned as red: red / blue / draws | flips |
|---|---|---|---|---|
| **shipped: two bars, joining, strength** | **0 / 5 / 15** | **26.0%** | **11 / 0 / 9** | **20.5%** |
| without the commitment | 0 / 5 / 15 | 26.0% | 11 / 0 / 9 | 20.5% |
| without the strength rule | 0 / 1 / 19 | 25.0% | 7 / 0 / 13 | 22.9% |
| without joining | 0 / 5 / 15 | 25.2% | 9 / 0 / 11 | 21.5% |
| the rules, in the same games, for scale | | 26-27% | | 25% |

The acceptance: `lr` draws 9 (at most 10) holds; `rl` flips 26.0% (at most
25) and `rl` draws 15 (at most 10) do not -- exit 1. What the rules here
are worth is the strength rule: it is what turns the learned side's
stalemates into wins from both seats. What they are not is a cure for
flipping as the distance counts it: the learned blue reverses about as often
as the rules do, which on a board where every piece in reach is attacked at
once is mostly walkers going round one another, not fights abandoned. The
draws as blue are its seat's: about a third of its walker decisions stuck
behind the bridge (T45). T47's last round and T48's crossing are next.

`tactical_learned_blue_test.gd` holds the task's three cases (0.45 after
setting out at 0.6 still strikes; at 0.3 it gives up; beside another's
fight it joins) and the rules around them: the lower bar for the same red
walker only, the blow ending the commitment, commitments kept from turn to
turn and forgotten on a new game, a far-off attack and last turn's attack
not stopping a retreat, joining not committing, the strength rule both ways
and its radius, and the bar named in a retreat and in standing ground. Each
of the review's surviving mutations turns one red (planted and undone).
