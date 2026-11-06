# T135 — ConstraintDraws draws from GakXorshift

Size: S · Prereqs: T109, T96 · Files: `godot/addons/ai_constraints/constraint_draws.gd`, `python/gameaikit/constraints/draws.py`, `modules/ai_constraints.json`, `godot/test/ai_constraints/`, `docs/techniques/ai_constraints.md`, `docs/techniques/ai_constraints.pt-BR.md`

## Goal

`ai_constraints` carries its own copy of Marsaglia's xorshift
(`ConstraintDraws`), written by T95 before T109 moved the generator to
`ai_core` as `GakXorshift`, so that addons could stop copying it.
Invariant 2 allows `ai_core`, and ADR 0021 calls it the kernel. The
review of wave 142 (T96, decision 5) agreed to keep the copy for that
wave, since swapping it there would have touched two vector families in a
wave about something else, and recommended this task.

## Decisions written down first (the owner confirms in review)

- `ConstraintDraws` keeps `shuffle` and `index`, which are this addon's
  own, and draws its numbers from a `GakXorshift`. The addon adds `ai_core`
  to `depends_on` in `modules/ai_constraints.json`, which is empty today:
  a manifest change, which `affected.py` reads as global, so the wave runs
  all of `make check`.
- `ConstraintDraws.SEED_FOR_ZERO` stays, as a name for `GakXorshift`'s own
  rule for a zero seed, because `ConstraintSolver` and `WaveCollapse` use it
  as their default seed; their callers keep compiling unchanged.
- The draws agree number for number, so no vector is regenerated. If one
  moves, that is a bug in the fold, not a new vector.
- The Python twin draws from `gameaikit.core.Xorshift` the same way.

## Steps

1. Fold the generator in both languages, and remove the copied shifts.
2. Run both vector families and the suites unchanged.
3. Correct the page and the class headers that call it a copy.

## Acceptance

```bash
make test-constraints-vectors
python3 -m unittest discover -s python/tests -t python -p "test_constraints*.py"
make test-godot-some SUITES="test/ai_constraints test/squad"
make lint-modules
make lint-tasks lint-status
```

## Manual check

None: nothing on screen changes.

## Notes

- Opened by wave 142 (T96), from its review's finding 4 and decision 5.
