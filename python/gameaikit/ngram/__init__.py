"""An n-gram predictor of a player's next action: the Python half of T17.

The same table as `godot/addons/ai_opponent/ngram_predictor.gd`, written
again so the conformance vectors in `spec/vectors/ngram/` can hold the two
languages to the same numbers. It is not trained here and published: the
game counts during the fight (ADR 0016). This copy exists to be checked, and
to be read beside the other one.
"""

from gameaikit.ngram.predictor import NGramPredictor

__all__ = ["NGramPredictor"]
