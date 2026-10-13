"""From "somewhat alarmed and a little suspicious" back to one number: 63.

The rule base ends with a strength for every term of an output -- *alarmed*
at 0.25, *suspicious* at 0.75 -- and a game cannot set a guard's speed to a
sentence. Defuzzification turns the terms back into a number, and the
**centroid** does it the way the textbooks do: cut each term's shape off at
its strength, lay the cut shapes on top of each other, and find where the
pile would balance on a finger.

Overlapping rules are the point. Two rules firing at a quarter each land
*between* their two terms, never on either, and that in-between number is the
whole of fuzzy logic in one value. A defuzzifier that takes the strongest
rule's term instead produces steps, and the curve is where you see them.

Cost is `samples x sets`: the pile is measured at evenly spaced points rather
than integrated exactly. The sample count belongs to the output variable, so
two implementations that read the same controller measure at the same points.

When not to use it: when the output is a choice rather than an amount. The
centroid of "flee" and "fight" is a unit standing still.
"""

from __future__ import annotations

from .membership import Variable


def sample_points(output: Variable) -> list[float]:
    """Where the pile is measured: `samples` points, both ends included.

    Spelled as `minimum + span * index / (samples - 1)` on purpose, and the
    GDScript side spells it the same, so the two land on the same doubles.
    """
    span = output.maximum - output.minimum
    last = output.samples - 1
    return [output.minimum + span * index / last for index in range(output.samples)]


def clipped_height(output: Variable, strengths: dict[str, float], point: float) -> float:
    """How tall the pile is at one point: the highest cut shape there.

    Each term is cut off at its rule strength (`min`), and the terms are
    combined by taking the highest (`max`). That pair is Mamdani's, and it is
    the reason a rule firing weakly can never outvote a strong one.
    """
    height = 0.0
    for one in output.sets:
        height = max(height, min(strengths.get(one.name, 0.0), one.degree(point)))
    return height


def centroid(output: Variable, strengths: dict[str, float]) -> float:
    """The balance point of the cut shapes, or NaN when no rule fired.

    NaN rather than the middle of the range, or zero: a rule base with a hole
    in it is a defect, and a number that looks like an answer hides it. NaN
    compares false against every threshold, so it cannot pass for a decision.
    """
    weighted = 0.0
    area = 0.0
    for point in sample_points(output):
        height = clipped_height(output, strengths, point)
        weighted += height * point
        area += height
    if area == 0.0:
        return float("nan")
    return weighted / area
