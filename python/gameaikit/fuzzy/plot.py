"""Draw one controller's output across one input, in the terminal.

T13's manual check is to look at the curve: a fuzzy controller that steps
rather than slopes has a bug, and a plot is where it shows. This draws it
with nothing but characters, so the check needs no plotting library.

    PYTHONPATH=python python3 -m gameaikit.fuzzy.plot \\
        spec/vectors/fuzzy/the-guard.fcl distance light=0.9

The named input is swept across its range; every other input is held at the
value given for it. `slope` in `test_fuzzy.py` is the half of this check a
command can hold.
"""

from __future__ import annotations

import argparse
import math
import pathlib
import sys

from .fcl import read_fcl
from .rules import RuleBase

#: Rows in the plot. One per step of the swept input.
ROWS = 41

#: Characters across, for the output's whole range.
WIDTH = 60


def sweep(controller: RuleBase, swept: str, held: dict[str, float],
          rows: int = ROWS) -> list[tuple[float, dict[str, float]]]:
    """Each input value tried, with every output it produced."""
    variable = next(one for one in controller.inputs if one.name == swept)
    span = variable.maximum - variable.minimum
    found = []
    for index in range(rows):
        value = variable.minimum + span * index / (rows - 1)
        found.append((value, controller.evaluate({**held, swept: value})))
    return found


def draw(controller: RuleBase, swept: str, held: dict[str, float]) -> str:
    """The sweep as text: the input down the side, the first output as a bar.

    One output, because one bar per row is what stays readable at sixty
    characters; a controller with two outputs is plotted one at a time.
    """
    output = controller.outputs[0]
    lines = [f"{output.name} against {swept}, holding {held or 'nothing'}"]
    for value, outputs in sweep(controller, swept, held):
        answer = outputs[output.name]
        if math.isnan(answer):
            lines.append(f"{value:8.2f} | no rule fired")
            continue
        share = (answer - output.minimum) / (output.maximum - output.minimum)
        lines.append(f"{value:8.2f} | {'#' * round(share * WIDTH):<{WIDTH}} {answer:7.2f}")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    """Read the file, sweep the input, print the picture."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("controller", type=pathlib.Path)
    parser.add_argument("swept")
    parser.add_argument("held", nargs="*", help="name=value for every other input")
    arguments = parser.parse_args(argv)
    try:
        controller = read_fcl(arguments.controller.read_text(encoding="utf-8"))
        held = {name: float(value) for name, _, value in
                (pair.partition("=") for pair in arguments.held)}
    except (OSError, ValueError) as problem:
        print(f"plot: {problem}", file=sys.stderr)
        return 2
    inputs = {one.name for one in controller.inputs}
    if arguments.swept not in inputs:
        print(f"plot: {arguments.swept} is not an input", file=sys.stderr)
        return 2
    # A held value for no input, or for the one being swept, would be ignored
    # in silence -- and a plot of something other than what was asked for is
    # worse than no plot.
    stray = sorted(name for name in held if name not in inputs or name == arguments.swept)
    if stray:
        print(f"plot: {', '.join(stray)} cannot be held: not an input, or the swept one",
              file=sys.stderr)
        return 2
    try:
        print(draw(controller, arguments.swept, held))
    except ValueError as problem:
        print(f"plot: {problem}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
