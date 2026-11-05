# T125 — A second, stronger floor for the squad mode's strength

Size: S · Prereqs: T85, T87 · Files: `godot/game/squad/`, `godot/test/squad/`, `spec/squad/`, `docs/godot/squad.md`, `Makefile`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B18: 100 of 100 against
`RandomSquad` cannot tell weighings apart, so a second, stronger floor,
with T87.

`make test-squad-match` holds the weighed enemy to at least 80 of 100
seeded matches a seat against a random mover. It wins 100 of 100 either
way, so the gate cannot tell one weighing from another: the page says it
cannot tell the shield's defence at 20 from 10 (`docs/godot/squad.md`).
T85's review (`docs/reviews/119-xcom-style-mode-you-can-play.md`,
finding 3) suggested a greedy shooter with no movement weighing. T87
(PR #69, decision 8) left strength measured, not gated, and pointed here.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **The opponent: a greedy shooter.** It takes the best shot it has, and
  otherwise walks toward the nearest enemy it has seen, with no cover
  weighing. A row of `SquadRoster`, so a person can play against it too.
- **The bar comes from measurement.** Run the weighed enemy against it
  from each seat, then set the bar below what it wins, with a margin
  written beside the number. It is a floor, not a target.
- **It must separate something.** A planted weighing known to be worse
  (cover weighed at zero, for instance) must fail the new bar while
  passing the old one. Without that, it is another gate that only goes
  green (invariant 4).
- **MCTS is not gated here.** A strength gate at 1,000 iterations costs
  about 40 CPU-minutes per 100 games (PR #69); MCTS against the greedy
  shooter goes in `make measure-squad-mcts`'s table, not in `make check`.
- **The time it costs** is measured and on the target's line; if it is
  much over T85's ~30 s, it gets fewer games, not a weaker bar.

## Steps

1. The greedy shooter, with a test that it shoots when it can and does
   not cheat (`SquadUnseenCheck`).
2. Measure, set the bar, plant the worse weighing.
3. The gate, beside `test-squad-match`, and the page's table.
4. Once its name is chosen, add the new target to this task's Acceptance
   (for instance `make test-squad-floor`), in the same wave.

## Acceptance

```bash
make test-squad-match
make test-godot-some SUITES="test/squad"
make lint-modules
python3 scripts/check_demos.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play the XCOM mode against the greedy shooter for a few turns: is it a
fair stand-in for a careless player?

## Notes

- Shares `godot/game/squad/` and `godot/test/squad/` with T88, T96,
  T117, T124, T126 and T127, `spec/squad/` with T88, T96, T117 and T120,
  and the `Makefile`. It does not run beside any of them.
- The new gate goes into `check:` by its own line, so `affected.py`'s
  rule 5 can read it as a gate added (`docs/howto/parallel-batch.md`).
