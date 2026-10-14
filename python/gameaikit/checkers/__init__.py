"""Checkers with a learned evaluation (T32), after Samuel.

`rules` is the game as the Godot side plays it, `evaluation` the three counts
and their weights, `search` alpha-beta, `selfplay` the games the data comes
from, `train` the fit, the control and the match, and `report` writes the
weights file the game reads.
"""
