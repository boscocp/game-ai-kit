"""How loud a noise is at a listener, from the length of the way between.

The tier-1 half of `godot/addons/ai_perception/path_hearing.gd`: 1 at the
source, 0 at the edge of the radius and where no path exists (a negative
length), the radius scaled by a listener factor of at most 1 -- Walsh's
off-screen halving [Walsh 2015].
"""

from __future__ import annotations

import math

NO_PATH = -1.0


def loudness(path_length: float, radius: float, listener_factor: float = 1.0) -> float:
    """The loudness `path_length` along the level from a noise of `radius`."""
    heard_within = radius * min(max(listener_factor, 0.0), 1.0)
    if path_length < 0.0 or not math.isfinite(path_length) or heard_within <= 0.0:
        return 0.0
    return min(max(1.0 - path_length / heard_within, 0.0), 1.0)
