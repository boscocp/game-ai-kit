"""What a guard perceives, how aware it grows and what it believes: the
tier-1 half of `ai_perception`'s stealth techniques, standard library only.

Each technique is a function of numbers a game has already measured -- a
distance and an angle, a path length, a rate, a neighbour list -- so it can
be run and checked with no engine. `spec/vectors/perception/` holds this
and the GDScript addon to the same answers.

    shape.py       zones that widen then narrow, read as certainty
    hearing.py     loudness along a path, and the off-screen factor
    awareness.py   a number that rises, falls a phase at a time, and holds
    belief.py      where the target may be, over a neighbour list

The rate awareness rises by is a fuzzy controller, checked by the fuzzy
vectors through the kit's fuzzy package.
"""

from . import awareness, belief, hearing, shape
