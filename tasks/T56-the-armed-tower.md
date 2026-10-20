# T56 — The armed tower: an upgrade the commander must choose to pay for

Size: S · Prereqs: T20 · Files: `godot/addons/ai_rts_core/`, `godot/game/rts/`

## Goal

The owner's request of 2026-10-20, playing T20: the tower that sees may be
upgraded to shoot. T20 left upgrades out on purpose ("a tech tree deeper
than one building ... comes back only with a task that names the AI it is
for"); this is that task, and the AI it is for is the commander: an
upgrade is a purchase that competes with fighters for the same ore and
magma, so the build order has a new choice in it, and the plan has a new
step to time.

## Steps

1. **The rule, in the core.** An "arm" upgrade bought at a complete tower
   (a price and a time, like training), after which that tower strikes the
   nearest visible enemy in reach -- with the line of fire every shot
   needs. A tower arming is not yet armed; a tower lost loses its upgrade.
2. **The domain.** `rts-build-order-domain.pddl` gains `arm_tower` and a
   fact `tower_armed`; the PDDL and JSON stay equal (`make test-python`).
3. **The commander chooses it.** A goal that asks for `tower_armed` when
   its home is threatened, and `BuildSchedule` times it like any step.
4. **The queues' rule**, so the baseline has it too.

## Acceptance

```bash
make check
```

```bash
make rts-measure
```

`rts_core_test.gd` holds the rule (a tower shoots only once armed, never
through a wall); `rts-measure` prints the commander against the queues
with towers armed, and the record goes in `docs/concepts/rts-ai.md`.

## Manual check

Play against normal and say whether arming a tower felt like a choice
between it and another squad.
