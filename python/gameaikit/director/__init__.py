"""The infiltration level's director (T90): Booth's adaptive pacing, in Python.

`pacing` is the machine -- the player's intensity, raised by events and
decaying, and the four phases read from it -- stepped on a list of timed
events. Godot's `Director` (godot/game3d/infiltration/director.gd) is the
same machine; the vectors in spec/vectors/director/ hold the two to one
answer. Nothing here is fitted: every number is spec/director/director.json's
(invariant 6).
"""
