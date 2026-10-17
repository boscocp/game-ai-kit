# T45 — The AI spends its money and keeps its pieces moving

Size: M · Prereqs: T44 · Files: `godot/game/tactical/`, `godot/test/`

## Goal

T44 measured the learned blue ending games with 172 funds unspent, its
workshop building nothing on 378 of 787 turns -- 377 of them boxed in by its
own pieces -- and 52.5% of its walkers' decisions "stays: no walk this turn
brings it nearer": pieces queued behind each other at the bridge. The rules
controller has its own silent refusal: against the learned side it built
nothing 503 times because "what would beat red's pieces cannot get past
them". Both are the controllers' faults, not the
game's, and both have a standard answer in
[docs/design/tactical-references.md](../docs/design/tactical-references.md)
(§2.1, Wesnoth's RCA AI): **spend first** -- recruitment outranks every move
-- and **never idle** -- a last, low-priority goal for a piece whose goal is
out of reach -- and **one piece per target**, as Wesnoth assigns villages so
that no two units go for the same one.

## Steps

1. The workshop's two silent refusals, measured in T44: the rules' reach
   rule that refuses every type when the enemy's pieces wall the routes (503
   times, the rules controller's), and a workshop boxed in by its own pieces
   (377, the learned blue's), which the board reports as
   "(12, 1) is not next to unit 6". The second says "no room beside the
   workshop", and the first no longer stops a build when a walker of blue's
   already reaches -- decide what it builds instead, and write down why.
2. A fallback goal for a walker whose goal is out of reach: the nearest
   enemy piece it can reach, or a staging cell behind the crossing that
   leaves the way clear -- decided here, said on screen as a rule.
3. Distinct targets: before blue's walkers move, each is given a target no
   other walker of its side has (a point, a bridge cell, a staging cell), so
   two pieces never queue for one cell.
4. `tactical_win_rates.gd` gains limits on what it already counts -- the
   share of stuck walker decisions and the funds left at the end -- so the
   acceptance below is a command.

## Acceptance

```bash
make test-godot
make tactical-win-rates GAMES=20 LIMITS="--at-most rl:stuck-percent:5 --at-most lr:stuck-percent:5 --at-most rl:blue-funds-left:10"
```

The suite must hold: the boxed-in workshop says there is no room; two
walkers of one side never take the same target in one turn; a walker with
no way to its goal moves to its fallback rather than staying.

## Manual check

Play `make demo-tactical` against each controller for ten rounds: blue's
pieces should cross or stage, not stand in a queue at the bridge.
