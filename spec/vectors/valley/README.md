# Conformance vectors: the valley

<!-- doc-meta
half_life: structure
verified_on: 2026-11-11
tier: 1
source: docs/adr/0025-a-save-is-a-record-of-deeds.md
invalidated_if: godot/game/valley/valley_rules.json or standing.json changes, or the order of a day (one night of the rules, then the day's deeds) changes
teaches: none
-->

> A record of deeds in, the world and the standing of every day out -- or
> a record refused, by the name of what was wrong with it: the files that
> say Python's valley and Godot's are one machine.

T164 keeps the player's deeds on the valley's places, and rebuilds the
world and the player's standing from them every session (ADR 0025). It is
written twice, `gameaikit.valley` and `godot/game/valley/`, and held here.

Each file is one of two kinds:

- `rebuilt`: `deeds`, each `{day, verb, place}`, and `days`, how many days
  to rebuild; `worlds`, every fact at the end of each day from 1 to
  `days`; `standing`, each virtue at the end of each day. A day is one
  night of the rules, then that day's deeds in the record's order.
- `refused`: `lines`, a saved record as its file holds it -- the header
  `{"version": 1}`, then one deed a line -- and `names`, the words the
  refusal must contain: the key, verb, place, day or version at fault,
  never empty, with numbers as JSON writes them (`0`, not `0.0`) and
  strings quoted, as both twins print them. Each is read twice, as lines
  and as the file that holds them, a newline after each line.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the machine, written from the "about" of `valley_rules.json` and
`standing.json` in plain dictionaries, importing nothing from this
repository. Independent of the code, not of its author: it would repeat a
misreading of the rules the other two share. It also checks that each case
shows what its name says -- the bread failing the day after the barn
burns, a consequence through two places taking two nights, the record's
order deciding two deeds on one day -- because a vector named for a rule it
never reaches holds nothing.

    python3 spec/vectors/valley/derive.py spec/vectors/valley

`make test-valley-vectors` checks the Godot side, and
`python3 -m unittest discover -s python/tests -t python -p "test_valley*.py"`
the Python side; each compares with the file, never with the other.
