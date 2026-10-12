#!/usr/bin/env python3
"""Hold the first invariant: the code is teaching material before it is a library.

The rule
--------
Someone should be able to read an algorithm here top to bottom and understand
it. The mechanical half of that is checkable, and this is it:

  * a function is at most 40 lines;
  * nesting inside a function goes at most 3 levels deep;
  * a file under godot/addons/ is at most 400 lines;
  * a public function (one whose name does not start with `_`) carries a doc
    comment above it;
  * function parameters and return types are annotated, and so is every `var`
    declaration that does not infer with `:=`;
  * no single-letter names outside a short allowlist, each entry with a reason.

Why this gate exists
--------------------
The readable version wins over the fast one here, and an exception needs a
benchmark rather than an opinion. None of that survives as prose in a
contributing guide; it survives as a command with an exit code.

What this gate deliberately does NOT check
------------------------------------------
Whether the file reads in the order the book explains the algorithm; whether
the header says when *not* to use the addon; whether a comment is worth having.
Those are review questions. A gate that tried to judge them would fire on good
code, and what a contributor learns from that is how to disable the gate.

Exit codes
----------
0   clean
1   violations found (each one printed as path:line)
2   wrong usage, or a file that cannot be read

Usage
-----
    check_readability.py [--root PATH]
    check_readability.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import subprocess
import sys
import tempfile

MAX_FUNCTION_LINES = 40
MAX_NESTING = 3
MAX_FILE_LINES = 400

# Short names that are clearer than any expansion, each kept for a reason.
# Keep this list short: every entry is a hole in the rule.
ALLOWED_SHORT_NAMES = {
    "g": "cost-so-far in heuristic search; the literature's name",
    "h": "heuristic estimate; the literature's name",
    "f": "g + h; the literature's name",
    "i": "loop index",
    "j": "second loop index",
    "x": "horizontal coordinate",
    "y": "vertical coordinate",
}

# Third-party code under addons/ that this project does not author.
VENDORED_DIRS = {"gdUnit4"}

FUNC_RE = re.compile(r"^(\t*)func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*?)\)\s*(->\s*\S+)?\s*:")
VAR_RE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)?(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\s*(:=|:|=)")
PARAM_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(:\s*[^=]+)?(=.*)?$")


def gdscript_files(root: pathlib.Path) -> list[pathlib.Path]:
    """Every .gd file this project authors, vendored code excluded."""
    found = []
    for path in sorted(root.rglob("*.gd")):
        if any(part in VENDORED_DIRS for part in path.parts):
            continue
        found.append(path)
    return found


def is_public(name: str) -> bool:
    """A leading underscore marks a private or engine-called function."""
    return not name.startswith("_")


def check_file_length(path: pathlib.Path, lines: list[str], label: str) -> list[str]:
    if "addons" in path.parts and len(lines) > MAX_FILE_LINES:
        return [f"{label}:{len(lines)} file is {len(lines)} lines; {MAX_FILE_LINES} is the limit"]
    return []


def check_functions(path: pathlib.Path, lines: list[str], label: str) -> list[str]:
    """Length, nesting, doc comment and type annotations, per function."""
    findings = []
    is_test = path.name.endswith("_test.gd")

    for index, line in enumerate(lines):
        match = FUNC_RE.match(line)
        if match is None:
            continue

        indent, name, params, return_type = match.groups()
        number = index + 1
        body = function_body(lines, index, len(indent))

        if len(body) > MAX_FUNCTION_LINES:
            findings.append(
                f"{label}:{number} {name}() is {len(body)} lines; {MAX_FUNCTION_LINES} is the limit"
            )

        depth = deepest_nesting(body, len(indent))
        if depth > MAX_NESTING:
            findings.append(f"{label}:{number} {name}() nests {depth} deep; {MAX_NESTING} is the limit")

        if return_type is None:
            findings.append(f"{label}:{number} {name}() has no return type annotation")

        findings += check_params(params, name, label, number)

        # Tests document themselves by their names, and a doc comment on every
        # one of them is noise that teaches the reader to skip comments.
        if is_public(name) and not is_test and not has_doc_comment(lines, index):
            findings.append(f"{label}:{number} public {name}() has no doc comment above it")

    return findings


def function_body(lines: list[str], start: int, indent_width: int) -> list[str]:
    """The lines belonging to the function that starts at `start`."""
    body = []
    for line in lines[start + 1:]:
        if line.strip() and not line.startswith("\t" * (indent_width + 1)):
            break
        body.append(line)
    while body and not body[-1].strip():
        body.pop()
    return body


def deepest_nesting(body: list[str], base_indent: int) -> int:
    """How many tabs past the function signature the deepest line sits."""
    deepest = 0
    for line in body:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        tabs = len(line) - len(line.lstrip("\t"))
        deepest = max(deepest, tabs - base_indent)
    return deepest


def has_doc_comment(lines: list[str], func_index: int) -> bool:
    """True when a `##` or `#` comment sits directly above the function."""
    for line in reversed(lines[:func_index]):
        if not line.strip():
            continue
        return line.lstrip().startswith("#")
    return False


def check_params(params: str, func_name: str, label: str, number: int) -> list[str]:
    """Every parameter carries a type annotation, and is not a bare letter."""
    findings = []
    for raw in split_params(params):
        param = raw.strip()
        if not param:
            continue
        match = PARAM_RE.match(param)
        if match is None:
            continue
        name, annotation, _default = match.groups()
        if annotation is None:
            findings.append(f"{label}:{number} {func_name}({name}) has no type annotation")
        if len(name) == 1 and name not in ALLOWED_SHORT_NAMES:
            findings.append(f"{label}:{number} {func_name}({name}) is a single-letter name")
    return findings


def split_params(params: str) -> list[str]:
    """Split a parameter list on commas that are not inside brackets."""
    parts, depth, current = [], 0, ""
    for char in params:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
            continue
        current += char
    parts.append(current)
    return parts


def check_variables(lines: list[str], label: str) -> list[str]:
    """Every `var` is typed, by annotation or by `:=` inference."""
    findings = []
    for index, line in enumerate(lines):
        match = VAR_RE.match(line)
        if match is None:
            continue
        name, operator = match.groups()
        number = index + 1
        if operator == "=":
            findings.append(f"{label}:{number} var {name} is untyped; use `: Type` or `:=`")
        if len(name) == 1 and name not in ALLOWED_SHORT_NAMES:
            findings.append(f"{label}:{number} var {name} is a single-letter name")
    return findings


def run(root: pathlib.Path) -> int:
    findings = []
    for path in gdscript_files(root):
        label = str(path.relative_to(root)) if path.is_relative_to(root) else str(path)
        lines = path.read_text(encoding="utf-8").splitlines()
        findings += check_file_length(path, lines, label)
        findings += check_functions(path, lines, label)
        findings += check_variables(lines, label)

    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


GOOD = """\
# A readable example, used by the self-test.
extends Node2D


## Returns the straight-line distance, which is admissible on this grid and so
## keeps A* optimal.
func heuristic(from: Vector2i, to: Vector2i) -> float:
\tvar dx: int = absi(from.x - to.x)
\tvar dy: int = absi(from.y - to.y)
\treturn sqrt(dx * dx + dy * dy)


func _ready() -> void:
\tvar total := 0
\tfor i in range(3):
\t\ttotal += i
"""


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(path: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(path)

    def project(root: pathlib.Path, name: str, source: str) -> pathlib.Path:
        folder = root / name / "godot" / "addons" / "ai_search"
        folder.mkdir(parents=True)
        (folder / "search.gd").write_text(source)
        return root / name

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        expect("readable file", quiet(project(root, "good", GOOD)), 0)

        # Planted: a public function with no doc comment.
        undocumented = GOOD.replace(
            "## Returns the straight-line distance, which is admissible on this grid and so\n"
            "## keeps A* optimal.\n",
            "",
        )
        expect("public func without doc", quiet(project(root, "undoc", undocumented)), 1)

        # Planted: a missing return type.
        untyped_return = GOOD.replace("func heuristic(from: Vector2i, to: Vector2i) -> float:",
                                      "func heuristic(from: Vector2i, to: Vector2i):")
        expect("missing return type", quiet(project(root, "noret", untyped_return)), 1)

        # Planted: an untyped parameter.
        untyped_param = GOOD.replace("func heuristic(from: Vector2i, to: Vector2i) -> float:",
                                     "func heuristic(from, to: Vector2i) -> float:")
        expect("untyped parameter", quiet(project(root, "noparam", untyped_param)), 1)

        # Planted: an untyped var.
        untyped_var = GOOD.replace("var dx: int = absi", "var dx = absi")
        expect("untyped var", quiet(project(root, "novar", untyped_var)), 1)

        # Planted: a single-letter name that is not on the allowlist.
        bad_name = GOOD.replace("var dx: int =", "var q: int =")
        expect("single-letter name", quiet(project(root, "badname", bad_name)), 1)

        # `g`, `h` and `i` are on the allowlist with a reason, and must pass.
        allowed = GOOD.replace("var dx: int = absi(from.x - to.x)", "var g: int = absi(from.x - to.x)")
        expect("allowlisted short name", quiet(project(root, "allowed", allowed)), 0)

        # Planted: a function past the line limit.
        long_body = "\n".join("\tvar line_%d := %d" % (n, n) for n in range(MAX_FUNCTION_LINES + 5))
        too_long = GOOD + "\n\n## Too long on purpose.\nfunc overlong() -> void:\n" + long_body + "\n"
        expect("overlong function", quiet(project(root, "long", too_long)), 1)

        # Planted: nesting past the limit.
        deep = (
            GOOD
            + "\n\n## Too deep on purpose.\nfunc deep() -> void:\n"
            + "\tif true:\n\t\tif true:\n\t\t\tif true:\n\t\t\t\tprint(1)\n"
        )
        expect("over-nested function", quiet(project(root, "deep", deep)), 1)

        # Planted: a file past the length limit.
        padding = "\n".join("# filler %d" % n for n in range(MAX_FILE_LINES + 10))
        expect("overlong file", quiet(project(root, "bigfile", GOOD + "\n" + padding)), 1)

        # A test file is exempt from the doc-comment rule but not the rest.
        test_root = root / "tests" / "godot" / "test"
        test_root.mkdir(parents=True)
        (test_root / "thing_test.gd").write_text(
            "extends GdUnitTestSuite\n\n\nfunc test_something() -> void:\n\tassert_int(1).is_equal(1)\n"
        )
        expect("test file without doc comments", quiet(root / "tests"), 0)

        # Vendored code is not this project's to format.
        vendor = root / "vendor" / "godot" / "addons" / "gdUnit4"
        vendor.mkdir(parents=True)
        (vendor / "messy.gd").write_text("func whatever(a, b):\n\tvar z = 1\n")
        expect("vendored code ignored", quiet(root / "vendor"), 0)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--root", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        return 2

    if args.self_test:
        return self_test()

    root = pathlib.Path(args.root or pathlib.Path(__file__).resolve().parent.parent)
    try:
        return run(root)
    except OSError as error:
        print(f"check_readability: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
