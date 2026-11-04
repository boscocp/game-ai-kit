"""The bot match's player model (T100), in Python.

`player_model` counts what the person's bot did during one match -- shots,
hits, kills, deaths, damage dealt and taken -- reads an estimate of how well
they play off those counts as a Beta mean, and turns it into the other
team's aim error through the fixed table in
godot/game3d/botmatch/rules.json. Godot's `PlayerModel`
(godot/game3d/botmatch/player_model.gd) is the same arithmetic; the vectors
in spec/vectors/player_model/ hold the two to one answer.

Nothing here is fitted, and nothing outlives a match: ADR 0016's amendment
lets this model count during play on three conditions -- counts only,
empty at the start of every match, rebuildable from that match's log.
"""
