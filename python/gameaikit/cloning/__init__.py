"""Behaviour cloning: learn what a recorded player did, and ask what it bought (T18).

The recordings are fights the game kept (`data/fights/`); Godot replays them
and cuts one row per decision (`data/cloning/rows.json`), because only Godot
can replay a fight. Here the rows are split by recording, a softmax model is
fitted and a ghost's table counted on one part, and both are measured on the
other against T17's n-gram -- `compare.py`, which is the task.

Standard library only: no numpy, no install step.
"""
