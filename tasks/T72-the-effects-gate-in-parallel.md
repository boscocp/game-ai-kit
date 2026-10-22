# T72 — The bot match's effects gate, in parallel

Size: S · Prereqs: T51, T66, T67, T68 · Files: `godot/test/botmatch/`, `scripts/`, `python/tests/`, `Makefile`, `docs/godot/botmatch.md`

## Goal

`make test-botmatch-effects` plays every pairing's matches one after
another in one Godot process: 189 whole matches after T68, 2343 s on wave
76, against 1279 s in T67. Every wave that touches the bot match runs it,
and it runs again after a review changes the code, because the claims are
about what the matches did. The owner, 2026-10-22, watching wave 76 run
it a second time: "de novo? pq ta repetindo? precisa mesmo?" -- it does
need to run again, since the numbers it claims came from code that no longer
exists. But it does not need to take forty minutes.

Each match is a function of its pairing and its seed, with its own random
generator (`world.random`), so the matches are independent. Run them in
several Godot processes at once, and evaluate the claims once over the
merged results. Use **the same numbers, bit for bit** as the serial run:
the claims and their planted cases are not changed, only the waiting.

## Steps

1. **Measure first**: the time per match and per pairing, the number of
   cores, and whether a match leaves anything behind in its process that
   the next one reads.
2. **Shards**: the gate takes `-- --shard K/N --out DIR`, plays only its
   share of the matches, and writes each match's own counts. With
   `-- --merge DIR` it reads them back instead of playing, adds them in
   the serial order, and evaluates every claim as before. The job list
   stays the gate's own: one place says which matches there are.
3. **A runner** starts N shards (from the cores, capped), each with its own
   log file, then the merge. Its exit codes stay apart: 0 every claim held,
   1 a claim failed, 2 a shard could not run. It fails on any engine error
   in a shard's log (CLAUDE.md's trap: a SCRIPT ERROR does not fail a
   `-s` run) and on a shard that played no match (a runner that finds
   nothing exits 0).
4. **Planted cases**: a merge missing one match's record, a merge with a
   record no pairing asked for, a shard log with a SCRIPT ERROR, and a
   shard that played nothing must each fail.
5. **The proof**: the same seeds, serial and in shards, print the same
   report, character for character.
6. **Measure** serial against parallel wall time, and write the numbers in
   `docs/godot/botmatch.md` and below.

## Acceptance

```bash
make test-botmatch-effects
python3 -m unittest discover -s python/tests -t python -p 'test_godot_shards*.py'
make test-godot-some SUITES="test/botmatch"
python3 scripts/check_readability.py
python3 scripts/check_modules.py
```

## Manual check

None: the equal reports are the check, and the times are measured.
