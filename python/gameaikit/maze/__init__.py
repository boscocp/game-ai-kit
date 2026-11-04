"""The small Pac-Man maze: its rules, in Python, step for step as Godot plays them.

`rules` reads the maze and the rules from the JSON beside it (copies of
`spec/maze/`), and `game` plays a step, rolling `gameaikit.core`'s seeded
generator -- the one `ai_core` writes for Godot. T98's value iteration
builds its transition model from `game`, so a move here means what it means
in `godot/game/maze/`; the vectors in `spec/vectors/maze/` hold the two to
the same positions.
"""
