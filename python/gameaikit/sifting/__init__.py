"""Story sifting: which moments of a record of events are worth telling.

The Python half of `godot/addons/ai_sifting/` (T166), written again so the
conformance vectors in `spec/vectors/sifting/` can hold the two languages
to the same matches. The valley's chronicle sifts in the game; this copy
exists to be checked, and read beside the other one.

    sifter.py   a pattern's problem (P1-P5), and `StorySifter.sift`, every
                match of a pattern in a record with the events that made it
"""

from gameaikit.sifting.sifter import StorySifter, bindings_if_matches, is_variable, problem, same

__all__ = ["StorySifter", "bindings_if_matches", "is_variable", "problem", "same"]
