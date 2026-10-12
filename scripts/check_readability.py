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

FUNC_RE = re.compile(r"^([\t ]*)func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*?)\)\s*(->\s*\S+)?\s*:")
# The operator is optional: `var running_total` with no initialiser is legal
# GDScript and untyped, and requiring an operator meant the gate never saw it.
# `const` is matched too -- it was not checked at all.
VAR_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)?(?:static\s+)?(var|const)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)\s*(:=|:|=)?"
)
# `for q in range(3)` binds a name just as a declaration does.
FOR_RE = re.compile(r"^\s*for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b")
# Opens a function, whether or not the parentheses close on the same line.
OPENS_FUNC = re.compile(r"^[\t ]*func\s+[A-Za-z_][A-Za-z0-9_]*\s*\(")
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
        signature = join_signature(lines, index)
        if signature is None:
            continue
        joined, span = signature
        match = FUNC_RE.match(joined)
        if match is None:
            continue

        _indent, name, params, return_type = match.groups()
        number = index + 1
        base_columns = indent_columns(line)
        body = function_body(lines, index + span - 1, base_columns)

        if len(body) > MAX_FUNCTION_LINES:
            findings.append(
                f"{label}:{number} {name}() is {len(body)} lines; {MAX_FUNCTION_LINES} is the limit"
            )

        depth = deepest_nesting(body, base_columns)
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


# One indentation level, in columns. A tab counts as this many, so a file that
# mixes the two is still measured rather than silently skipped.
INDENT_COLUMNS = 4


def indent_columns(line: str) -> int:
    """Leading whitespace in columns, tabs expanded.

    Measuring by counting tabs was the original mistake: a space-indented file
    produced an empty function body, which turned the length, nesting and
    parameter checks off without reporting anything. A gate that goes quiet on
    input it does not recognise is a gate that passes the day it matters.
    """
    leading = line[: len(line) - len(line.lstrip("\t "))]
    return len(leading.expandtabs(INDENT_COLUMNS))


def join_signature(lines: list[str], start: int) -> tuple[str, int] | None:
    """One logical signature, and how many lines it spans.

    A signature split across lines is legal GDScript, and matching only
    single-line ones skipped the whole function: untyped parameters and a
    missing return type went unreported. Returns None when this line does not
    open a function at all. Gives up after a dozen lines rather than scanning
    the file -- an unbalanced parenthesis is a syntax error, not a signature.
    """
    if not OPENS_FUNC.match(lines[start]):
        return None
    joined = ""
    for offset, line in enumerate(lines[start:start + 12]):
        joined += line.rstrip() if offset == 0 else " " + line.strip()
        if joined.count("(") <= joined.count(")"):
            return joined, offset + 1
    return None


def function_body(lines: list[str], start: int, base_columns: int) -> list[str]:
    """The lines belonging to the function that starts at `start`."""
    body = []
    for line in lines[start + 1:]:
        if line.strip() and indent_columns(line) <= base_columns:
            break
        body.append(line)
    while body and not body[-1].strip():
        body.pop()
    return body


def deepest_nesting(body: list[str], base_columns: int) -> int:
    """How many indentation levels past the signature the deepest line sits."""
    deepest = 0
    for line in body:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        levels = (indent_columns(line) - base_columns) // INDENT_COLUMNS
        deepest = max(deepest, levels)
    return deepest


def check_indentation(lines: list[str], label: str) -> list[str]:
    """GDScript indents with tabs. The style guide says so, and so does this.

    Only a line *starting* with a space is reported: a tab followed by spaces is
    ordinary alignment inside a call and flagging it would make the gate a
    nuisance, which is how gates get switched off.
    """
    findings = []
    for index, line in enumerate(lines):
        if line.startswith(" ") and line.strip():
            findings.append(f"{label}:{index + 1} indents with spaces; GDScript uses tabs")
    return findings


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
    """Every `var` and `const` is typed, and no bound name is a bare letter."""
    findings = []
    for index, line in enumerate(lines):
        number = index + 1

        loop = FOR_RE.match(line)
        if loop and len(loop.group(1)) == 1 and loop.group(1) not in ALLOWED_SHORT_NAMES:
            findings.append(f"{label}:{number} loop variable {loop.group(1)} is a single-letter name")

        match = VAR_RE.match(line)
        if match is None:
            continue
        keyword, name, operator = match.groups()
        if operator in ("=", None):
            findings.append(
                f"{label}:{number} {keyword} {name} is untyped; use `: Type` or `:=`"
            )
        if len(name) == 1 and name not in ALLOWED_SHORT_NAMES:
            findings.append(f"{label}:{number} {keyword} {name} is a single-letter name")
    return findings


def run(root: pathlib.Path) -> int:
    findings = []
    for path in gdscript_files(root):
        label = str(path.relative_to(root)) if path.is_relative_to(root) else str(path)
        lines = path.read_text(encoding="utf-8").splitlines()
        findings += check_indentation(lines, label)
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

        # Planted: a single-letter *parameter*. Mutation showed that deleting
        # this rule left the self-test green -- it was covered only by var.
        letter_param = GOOD.replace("func heuristic(from: Vector2i, to: Vector2i) -> float:",
                                    "func heuristic(q: Vector2i, to: Vector2i) -> float:")
        expect("single-letter parameter", quiet(project(root, "letterparam", letter_param)), 1)

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

        # Planted: the exact file a review used to show this gate going quiet.
        # Indented with spaces, it used to produce an empty function body, which
        # switched off the length, nesting and parameter checks without saying
        # anything. It must now report BOTH the spaces and the nesting.
        spaced = (
            "## Why this exists.\n"
            "func enormous() -> void:\n"
            "    if true:\n"
            "        if true:\n"
            "            if true:\n"
            "                if true:\n"
            "                    if true:\n"
            "                        print(\"six deep\")\n"
        )
        spaced_root = project(root, "spaced", spaced)
        expect("space-indented and over-nested", quiet(spaced_root), 1)
        with contextlib.redirect_stdout(io.StringIO()) as captured:
            run(spaced_root)
        reported = captured.getvalue()
        if "indents with spaces" not in reported:
            failures.append("space-indented file: the spaces themselves were not reported")
        if "nests" not in reported:
            failures.append("space-indented file: nesting was not measured through the spaces")

        # A tab followed by spaces is alignment inside a call, not a finding.
        aligned = (
            "## Why this exists.\n"
            "func thing(first: int, second: int) -> int:\n"
            "\treturn maxi(\n"
            "\t\tfirst,\n"
            "\t\tsecond,\n"
            "\t)\n"
        )
        expect("tab then spaces for alignment", quiet(project(root, "aligned", aligned)), 0)

        # Planted: a signature split across lines. The single-line pattern used
        # to skip the whole function, so two untyped parameters and a missing
        # return type went unreported.
        multiline = (
            "## Why this exists.\n"
            "func pathfind(\n"
            "\tstart,\n"
            "\tgoal\n"
            "):\n"
            "\treturn []\n"
        )
        expect("multi-line signature", quiet(project(root, "multiline", multiline)), 1)

        # The same signature written correctly must still pass, or the fix
        # would just be a new way to fire on good code.
        multiline_ok = (
            "## Why this exists.\n"
            "func pathfind(\n"
            "\tstart: Vector2i,\n"
            "\tgoal: Vector2i\n"
            ") -> Array:\n"
            "\treturn []\n"
        )
        expect("multi-line signature, typed", quiet(project(root, "mlok", multiline_ok)), 0)

        # Planted: a declaration with no initialiser. Legal, untyped, and the
        # pattern required an operator so it never matched.
        no_initialiser = GOOD.replace("var dx: int = absi(from.x - to.x)", "var running_total")
        expect("var with no initialiser", quiet(project(root, "noinit", no_initialiser)), 1)

        # Planted: const was not checked at all.
        untyped_const = GOOD.replace("var dx: int = absi(from.x - to.x)", "const LIMIT = 3")
        expect("untyped const", quiet(project(root, "const", untyped_const)), 1)

        # Planted: a single-letter loop variable, which only var and parameters
        # were ever checked for.
        loop_letter = GOOD.replace("for i in range(3):", "for q in range(3):").replace(
            "total += i", "total += q")
        expect("single-letter loop variable", quiet(project(root, "loopq", loop_letter)), 1)

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
    except SystemExit as exit_request:
        # argparse raises SystemExit for `--help` too, with code 0. Catching it
        # blindly turned a successful --help into exit 2 in every gate here.
        if exit_request.code == 0:
            raise
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
