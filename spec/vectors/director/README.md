# Conformance vectors: the director

<!-- doc-meta
half_life: structure
verified_on: 2026-10-30
tier: 1
source: https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
invalidated_if: spec/director/director.json changes, or the order of a step (events, decay, clamp, phase) changes
teaches: none
-->

> An event list in, the intensity curve and the phase changes out: the
> files that say Python's director and Godot's are one machine.

T90 paces the infiltration level with a director after Booth's Left 4 Dead
one: the player's intensity, raised by what happens to them and decaying
towards zero, and four phases read from it -- build up, sustain the peak,
fade, relax. It is written twice, `gameaikit.director.pacing` and
`godot/game3d/infiltration/director.gd`, and held here.

Each file is one run of the machine from rest:

- `steps`, how many steps it runs (each `step_seconds` of
  `spec/director/director.json`), and `events`, each with the `step` it
  happens in, its `kind` (`seen`, `heard`, `hurt`, `search_near`, `chase`,
  `exit`) and its number (`points`, `distance`, `on`, `metres`);
- `intensity`: the intensity after every step;
- `changes`: every phase change, with the step it happened in.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the machine, written from `director.json`'s "about" in plain
dictionaries, importing nothing from this repository. Independent of the
code, not of its author: it would repeat a misreading of Booth the other
two share. It also checks that each case shows what its name says -- the
whole cycle, no decay during a chase, a search adding less the further it
is, damage in proportion and the top held, a relax cut short by the player
moving on, and nothing at all -- because a vector named for a rule it never
reaches holds nothing.

    python3 spec/vectors/director/derive.py spec/vectors/director

`make test-director-vectors` checks the Godot side, and
`python3 -m unittest discover -s python/tests -t python -p "test_director*.py"`
the Python side; each compares with the file, never with the other.
