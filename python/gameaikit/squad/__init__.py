"""The XCOM-style mode of the tactical game, in Python: the shot, cover and flanking.

`shot` reads the rules from `rules.json` beside it, a byte-for-byte copy of
`spec/squad/rules.json`, and works out what `godot/game/squad/` works out:
the cover a target has against a shooter, whether the shooter flanked it,
the hit chance, and what one die does. The vectors in
`spec/vectors/squad/` hold the two languages to the same answers (T84).
"""
