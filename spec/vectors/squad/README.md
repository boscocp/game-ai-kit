# Squad vectors: one shot, cover and flanking

The XCOM-style mode's shot (T84), as `spec/squad/rules.json` states it.
Each file is a small map in the tactical map's letters (`#` rock, `T`
trees, `.` open), a shooter and a target -- type and cell, and the
target's health -- and the die the shot rolls. `expected` is what the shot
must come to: the target's `cover` against that shooter, whether the
shooter `flanked` it, the hit `chance`, whether it `hit`, and the target's
health left.

Every expected value was worked out by hand, from the rules and the
picture, and typed in: the `description` of each file is the working. No
program derived them, so neither language can have agreed with itself.

Read by:

- `make test-squad-vectors` -- the GDScript (`godot/test/squad/squad_vectors_runner.gd`),
  and the Python test below;
- `python/tests/test_squad_vectors.py` -- `gameaikit.squad.shot`;
- `godot/test/squad/squad_vectors_test.gd` -- the same check, as a gdUnit suite.

A cell is `[column, row]`, row 0 at the top.
