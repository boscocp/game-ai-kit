# Frame data: the fighting scenario

<!-- doc-meta
half_life: structure
verified_on: 2026-10-14
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a field in characters.json is renamed, or the resolution order in it changes
teaches: none
-->

> Every number a fight is resolved by, as data (T16). The Godot game reads a
> byte-for-byte copy, `godot/game/fighting/characters.json`, and a test
> holds the two equal; T17 and T18 read this one from Python.

`characters.json` holds:

- the stage, the input buffer's length, the pushback and the counter-hit
  bonus;
- `resolution`: the order a frame is resolved in, step by step, which
  `godot/game/fighting/fight_rules.gd` follows line for line -- who wins a
  trade (both: both hits land), what a counter-hit is (a hit on a move still
  in its startup), and what blocks (holding away while free or already
  blocking);
- two characters that differ in a way an opponent can exploit: the
  **lancer** reaches further and starts slower, the **dancer** is quick and
  short.

Per move: `startup`, `active` and `recovery` frames, counted from 1;
`damage`, `hitstun` and `blockstun`; a `hitbox` as the near and far edge in
front of the body, out only on active frames; `hurtbox_reach`, how far in
front the fighter can be hit from its first active frame to its last
recovery frame; and a `cancel_window` with the moves it `cancels_into`, open
only once the move has connected. Every number is a whole number: a fraction
of a frame would round differently somewhere, and a replay would drift.
