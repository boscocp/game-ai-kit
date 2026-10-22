# T71 — A new gate selects its module, not everything

Size: S · Prereqs: T58 · Files: `scripts/affected.py`, `scripts/check_modules.py`, `python/tests/`

## Goal

Wave 75 fixed one scene in the 3D racer and added one gate for it,
`make test-racing3d-you-drive`. Adding a gate means two lines elsewhere:
a target in the `Makefile` (and its name in `check:`), and the target's
name in `modules/racing3d.json`'s `gates`. Both paths are global, so
`make affected` said `selected: everything`, and a change whose code
touched one module ran all of `make check`, about nine minutes. Every wave
that adds a gate pays that, and adding gates is what the invariants ask
for.

The owner, 2026-10-22: "ele n foi otimizado pra rodar só onde foi
alterado?" -- it was, but not for this case.

A change that **only adds** a gate is not a change to what the other
gates stand on. Recognise it, and select the module whose gate it is (and
its dependents), not everything. Keep T58's first rule: fail towards
running more. Anything the reader of the diff is not sure of is still
global.

## Steps

1. **Read the diff, not the path.** For the `Makefile` and a manifest,
   look at the hunks (`git diff -U0 base...head -- <path>`), not only that
   the path changed.
2. **The `Makefile` is local only when every hunk is one of:**
   - an added block of `.PHONY: test-x`, `test-x: <prerequisites> ## …`
     and recipe lines, whose recipe names files that one module owns
     (`-s res://test/<module>/…`, a script it owns);
   - `test-x` appended to the `check:` list, and nothing else on that
     line changed.

   Any removed line, any changed recipe of an existing target, any change
   to a variable, an include or a pattern rule: global, as now.
3. **A manifest is local only when** the one change is names appended to
   its own `gates` and every name is a target that step 2 accepted in the
   same change. Changing `owns` or `depends_on` stays global: that is the
   selector's map.
4. **The module selected is the one owning the new target's files**, plus
   its dependents, as for any path that module owns.
5. **Planted cases** in `affected.py --self-test`, each as T58 wrote them:
   - wave 75's diff (one target added, one name in `check:`, one gate in
     `racing3d.json`) selects `racing3d` and its dependents, not
     everything;
   - the same diff plus one changed character in another target's recipe
     selects everything;
   - a new target whose recipe runs another module's file selects
     everything (or both modules -- decide and say which);
   - a removed target, a changed variable, and a change to `owns` each
     select everything;
   - a `Makefile` hunk that cannot be parsed selects everything.
6. **Measure**: `make affected` on wave 75's commits before and after,
   and the time `make check-affected` takes for each.

## Acceptance

```bash
python3 scripts/affected.py --self-test
make test-python
python3 scripts/check_readability.py
python3 scripts/check_modules.py
```

## Manual check

Read the new reader of the `Makefile` diff top to bottom: is it simple
enough that a person trusts it to say "local"? If it is not, the nine
minutes are the cheaper price.
