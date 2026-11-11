"""The valley's memory (T164, ADR 0025): a record of deeds on places, and
the world and the player's standing rebuilt from it.

`record` is the deed log and a saved record's lines read back; `rules`
rebuilds the world of any day from the record and `valley_rules.json`;
`standing` sums `standing.json`'s fixed weights over the record. Godot's
`DeedLog`, `ValleySave`, `ValleyRules`, `ValleyWorld` and `Standing` are
the same machine; the vectors in spec/vectors/valley/ hold the two to one
answer. Nothing here is fitted: every rule and every weight is authored
(invariant 6).
"""
