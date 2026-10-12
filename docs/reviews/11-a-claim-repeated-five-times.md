# Review: fix/11-a-claim-repeated-five-times

Not reviewed by a fresh context. The finding in it was not found by a review at
all -- it was found by running `make check` after adding an unrelated script
and noticing the output disagreed with something this session had written down
five times.

## What was reviewed

`scripts/run_selftests.py`, read against the claim four files and one review
record were making about it, after it ran the self-test of a script that is not
named `check_*.py`.

## Findings

**A claim repeated in five places was wrong.** The wave 08 review said
`lint-selftests` "finds gates by the name `scripts/check_*.py`", and that
sentence was copied into `vectors_runner.gd`, `search_vector.gd`,
`search_vector_test.gd`, the wave 08 review record and `STATUS.md` without
being checked once.

`run_selftests.py` discovers in two parts, and its own docstring says so: it
runs **every** script in `scripts/` carrying the `--self-test` marker, and
separately insists that anything named `check_*.py` carry one. The naming rule
is about which files are *required* to have a self-test, not about which are
found.

The hole it was used to explain is real -- the conformance runner had no
planted case for any of its rules -- but the reason given was wrong. The runner
is invisible to `lint-selftests` because it is GDScript living under `godot/`,
and nothing outside `scripts/` is looked at whatever it is called.

## What was done about them

All five places now say what `run_selftests.py` does. The review record carries
the correction in place rather than a silent edit, because it was merged before
the mistake was found and a record that quietly changes is worth less than one
that shows its working.

This branch also carries `make wave`, which was asked for separately: it reads
the index, picks the first task whose prerequisites are all done, numbers the
branch from the review records rather than from the task list -- those have not
been the same number since wave 6 -- and prints the resuming section. It does
not do the work, and its docstring says so. Its self-test is what caught the
wrong claim: the script is not named `check_*.py`, and `make check` ran it
anyway.
