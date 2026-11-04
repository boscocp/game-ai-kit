"""The Python half of `godot/addons/ai_core/`: what more than one technique shares.

Only the seeded generator lives here (T109): Monte Carlo search, the
particle filter, the bandit and the maze draw from it, so that each draws
what its GDScript twin draws from the same seed.

    xorshift.py   Marsaglia's 32-bit xorshift, drawn the same as the GDScript
"""

from gameaikit.core.xorshift import Xorshift

__all__ = ["Xorshift"]
