#!/usr/bin/env python3
"""Refuse an addon script that names its own `class_name` as a value in its own file.

The rule
--------
T167: in every `.gd` under `godot/addons/ai_*/`, the class the file declares
with `class_name` is named, inside that file, only as a **type**:

    -> Name                      a return type
    var x: Name, const X: Name   a member, a local or a constant
    for x: Name in ...           a typed loop variable
    func f(x: Name)              an argument, a lambda's or a signal's too
    Array[Name], Dictionary[String, Name]   inside one of the above

Anywhere else it is a value and a finding: `Name.new(...)`, any
`Name.call(...)`, `Name.CONSTANT`, `is Name`, `as Name`, an inner class
`extends Name`, or the bare name passed around. An inner class naming its
outer class counts, because it is the same file. Comments and strings are
stripped first, so a sentence that says `Name.new()` is not code.

Why this gate exists
--------------------
T162 (wave 176) measured it on 4.7.2: a script that names itself as a value
holds a reference to itself, and only the engine's walk over every script at
exit frees it. That walk can end early, and then every older script that
holds itself is "still in use at exit". Which ones leak depends on the order
the scripts were loaded in, so `check_published.py` and `library-check`'s
`kit` step, which load the kit in a few orders, see the pattern only when
the order shows it. A new self-naming script loaded last leaks nothing there
and would ship. This lint sees it in any order, with no engine.
`docs/godot/exit-leaks.md` has the measurements.

The type positions were measured harmless in T162. Everything that is not
one of them is refused, rather than a list of bad spellings, so a spelling
nobody thought of is refused too, and an allowance is a decision someone
wrote here.

What it does not read
---------------------
Game code, demos and tests: the rule is about what ships as a library. A
file with no `class_name` has no name to hold itself by. A script that
`preload`s its own path is another way to hold itself; this lint does not
look for it.

Known false positive: an argument after a default value nested two
parentheses deep, `func f(a: Vector2 = Vector2(maxf(1.0, 2.0), 0.0), b:
Name = null)`, is read as a value and refused. Put that argument first, or
move the default into the body.

Exit codes
----------
0   every addon script names its own class only as a type
1   a script names itself as a value (file, line and the line itself
    printed), or there was nothing to check: no `ai_*` script, or none with
    a `class_name`
2   wrong usage, or the addons folder or a script cannot be read

Usage
-----
    check_self_naming.py [--addons PATH]
    check_self_naming.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDONS = ROOT / "godot" / "addons"
#: The addons this kit ships. gdUnit4 lives beside them and is not ours.
ADDON_GLOB = "ai_*"

CLASS_NAME = re.compile(r"\bclass_name\s+([A-Za-z_]\w*)")
#: One piece of an argument list before the argument being read: any
#: character but a bracket, or a whole `(...)`, `[...]` (one level deeper
#: too, for `Dictionary[String, Array[int]]`) or `{...}`. A comma inside a
#: default `{1: 2, CAP: Name}` is never crossed, so the `CAP:` there is not
#: read as an argument.
ARGUMENT_PIECE = r"(?:[^()\[\]{}]|\([^()]*\)|\[(?:[^\[\]]|\[[^\[\]]*\])*\]|\{[^{}]*\})"
#: What may come just before a type: a return arrow, a declared name and its
#: colon, or an argument's name and its colon inside a `func` or `signal`.
TYPE_LEAD = (
    r"(?:->"
    r"|\b(?:var|const|for)\s+\w+\s*:"
    r"|\b(?:func|signal)\b[^(]*\((?:" + ARGUMENT_PIECE + r"*,)?\s*\w+\s*:)"
)
#: Inside a typed container: `Array[`, or `Dictionary[` with or without its key.
CONTAINER = r"(?:(?:Array|Dictionary)\[\s*(?:[\w.]+\s*,\s*)?)"
TYPE_BEFORE = re.compile(TYPE_LEAD + r"\s*" + CONTAINER + r"*$")
OPENERS, CLOSERS = "([{", ")]}"
ADVICE = ("in a static function write `new(...)`; in an instance function call a static "
          "factory of this file that does. Name the class here only as a type "
          "(T162, docs/godot/exit-leaks.md)")


def _string_end(text: str, start: int) -> int:
    """Where the string literal opening at `start` ends, one past its last quote.

    `start` is at the quote, or at a one-letter prefix (`r`, `&`, `^`) before it.
    A raw string keeps its backslashes, but GDScript still does not end it
    at a backslash and a quote (measured on 4.7.2: `r"a\\"b"` is one string),
    so a backslash before a quote or a backslash skips that character there
    too. An unclosed string runs to the end of the text.
    """
    raw = text[start] == "r"
    quote_at = start + 1 if text[start] in "r&^" else start
    quote = text[quote_at] * 3 if text.startswith(text[quote_at] * 3, quote_at) else text[quote_at]
    index = quote_at + len(quote)
    while index < len(text):
        if text[index] == "\\" and (not raw or text[index + 1:index + 2] in ("'", '"', "\\")):
            index += 2
        elif text.startswith(quote, index):
            return index + len(quote)
        elif text[index] == "\n" and len(quote) == 1:
            return index
        else:
            index += 1
    return len(text)


def strip_comments_and_strings(text: str) -> str:
    """The code with every comment removed and every string emptied, line breaks kept.

    Line breaks are kept so a finding's line number is the file's.
    """
    kept: list[str] = []
    index = 0
    while index < len(text):
        character = text[index]
        prefixed = character in "r&^" and text[index + 1:index + 2] in ("'", '"') and \
            not (index and (text[index - 1].isalnum() or text[index - 1] == "_"))
        if character == "#":
            end = text.find("\n", index)
            index = len(text) if end < 0 else end
        elif character in "'\"" or prefixed:
            end = _string_end(text, index)
            kept.append('""' + "\n" * text.count("\n", index, end))
            index = end
        else:
            kept.append(character)
            index += 1
    return "".join(kept)


def statements(code: str) -> list[tuple[int, str]]:
    """Each statement as one string, with the offset where it starts.

    A statement goes on while a bracket is open or a line ends in a
    backslash, as GDScript reads it, so a signature over three lines is one.
    """
    found: list[tuple[int, str]] = []
    depth = 0
    start = 0
    for index, character in enumerate(code):
        if character in OPENERS:
            depth += 1
        elif character in CLOSERS:
            depth = max(depth - 1, 0)
        elif character == "\n" and depth == 0 and code[index - 1:index] != "\\":
            found.append((start, code[start:index]))
            start = index + 1
    found.append((start, code[start:]))
    return found


def value_uses(code: str, name: str) -> list[int]:
    """The offsets in `code` where `name` is used as a value, not a type."""
    # Not after `.` (another class's member), `$` or `%` (a node path). The
    # `%` also skips modulo written with no space, `"%s"%Name.X`: rare, and
    # accepted rather than telling a unique node `%Name` from it here.
    pattern = re.compile(rf"(?<![\w.$%]){re.escape(name)}\b")
    offsets: list[int] = []
    for start, statement in statements(code):
        for use in pattern.finditer(statement):
            before = statement[:use.start()]
            if re.search(r"\bclass_name\s*$", before) or TYPE_BEFORE.search(before):
                continue
            offsets.append(start + use.start())
    return offsets


def findings_in(path: pathlib.Path, shown: str) -> tuple[bool, list[str]]:
    """Whether `path` declares a class_name, and each line where it names itself as a value."""
    text = path.read_text(encoding="utf-8")
    code = strip_comments_and_strings(text)
    declared = CLASS_NAME.search(code)
    if declared is None:
        return False, []
    name = declared.group(1)
    lines = text.splitlines()
    found: list[str] = []
    for offset in value_uses(code, name):
        number = code.count("\n", 0, offset) + 1
        found.append(f"{shown}:{number}: {name} names itself as a value, in its own file: "
                     f"`{lines[number - 1].strip()}`. Instead, {ADVICE}")
    return True, found


def check(addons: pathlib.Path) -> int:
    """Read every `ai_*` script under `addons`, print each finding; the exit code."""
    if not addons.is_dir():
        print(f"check_self_naming: {addons} is not a folder", file=sys.stderr)
        return 2
    scripts = sorted(addons.glob(f"{ADDON_GLOB}/**/*.gd"))
    named = 0
    problems: list[str] = []
    for script in scripts:
        base = ROOT if script.is_relative_to(ROOT) else addons.parent
        shown = script.relative_to(base).as_posix()
        try:
            has_name, found = findings_in(script, shown)
        except (OSError, UnicodeDecodeError) as error:
            print(f"check_self_naming: cannot read {shown}: {error}", file=sys.stderr)
            return 2
        named += has_name
        problems += found
    if not scripts or not named:
        problems.append(f"check_self_naming: {len(scripts)} script(s) under {addons}/{ADDON_GLOB}, "
                        f"{named} with a class_name: nothing was checked, and that is not a pass")
    for problem in problems:
        print(problem)
    if not problems:
        print(f"check_self_naming: {named} addon script(s) with a class_name, "
              f"each names itself only as a type")
    return 1 if problems else 0


def quiet_check(addons: pathlib.Path) -> tuple[int, str]:
    """`check`, with what it prints captured rather than shown: a planted finding is not news."""
    printed = io.StringIO()
    with contextlib.redirect_stdout(printed), contextlib.redirect_stderr(io.StringIO()):
        code = check(addons)
    return code, printed.getvalue()


TYPES_ONLY = '''\
## Toy.new() in a doc comment is prose, not code.
class_name Toy
extends RefCounted

signal changed(previous: Toy)

const HINT: String = "write Toy.new() elsewhere, and 'is Toy'"
const LONG: String = """Toy.make() over
two lines"""
var other: Toy
var many: Array[Toy] = []
var named: Dictionary[String, Toy] = {}
var nested: Dictionary[Toy, Array[Toy]] = {}
var toys_seen: int = 0  # Toy.CAP in a comment
const NONE: Toy = null
const RAW: String = r"a\\"b Toy.new()"


static func make() -> Toy:
	return new()


func keyed(table: Dictionary = {1: 2, 3: 4}, rows: Array[int] = [1, 2],
		deep: Dictionary[String, Array[int]] = {}, last: Toy = null) -> Toy:
	return last


func pair(left: Toy,
		right: Toy = null) -> Array[Toy]:
	var copy: Toy = left
	var sorter: Callable = func(first: Toy, second: Toy) -> bool: return first != second
	for each: Toy in [left, right]:
		toys_seen += 1
	return [copy, right] if sorter.is_valid() else []


class Inner:
	var outer: Toy
'''

#: (file stem, one line that names the class as a value).
VALUE_LINES = [
    ("plant_new", "\treturn Toy.new()"),
    ("plant_static_call", "\treturn Toy.make()"),
    ("plant_constant", "\treturn Toy.CAP"),
    ("plant_is", "\treturn thing is Toy"),
    ("plant_is_not", "\treturn thing is not Toy"),
    ("plant_as", "\treturn thing as Toy"),
    ("plant_bare_value", "\treturn Toy"),
    ("plant_spaced_dot", "\treturn Toy . new()"),
    ("plant_in_a_container_value", "\treturn thing is Array[Toy]"),
    ("plant_after_a_string", "\treturn [\"#\", Toy.new()]"),
    ("plant_after_a_raw_string", "\treturn [r\"\\\"\", Toy.new()]"),
    ("plant_typed_then_built", "\tvar built: Toy = Toy.new()\n\treturn built"),
    ("plant_typed_then_cast", "\tvar cast: Toy = thing as Toy\n\treturn cast"),
]
#: Whole functions or members whose value comes after a type, on the same
#: statement: a type lead earlier in the line does not make the rest a type.
FUNCTION_PLANTS = {
    "plant_default_argument": "func value(thing: Toy = Toy.make()) -> Variant:\n\treturn thing\n",
    "plant_one_line_return": "func value() -> Toy: return Toy.new()\n",
    "plant_exported_member": "@export var kept: Toy = Toy.new()\n",
    "plant_inside_a_default_dictionary":
        "func value(table: Dictionary = {1: 2, CAP: Toy}) -> int:\n\treturn table.size()\n",
}
PLANT_HEAD = "class_name Toy\nextends RefCounted\n\nconst CAP: int = 3\n\n\nstatic func make() -> Toy:\n\treturn new()\n\n\n"
INNER_PLANTS = {
    "plant_inner_calls_outer":
        PLANT_HEAD + "class Inner:\n\tfunc said() -> int:\n\t\treturn Toy.CAP\n",
    "plant_inner_extends_outer": PLANT_HEAD + "class Inner extends Toy:\n\tpass\n",
}


def planted_scripts() -> dict[str, str]:
    """Every refused spelling, each alone in a file named for it."""
    plants = {stem: PLANT_HEAD + "func value(thing: Object) -> Variant:\n" + line + "\n"
              for stem, line in VALUE_LINES}
    functions = {stem: PLANT_HEAD + text for stem, text in FUNCTION_PLANTS.items()}
    return {**plants, **functions, **INNER_PLANTS}


def _plant(addons: pathlib.Path, files: dict[str, str]) -> None:
    """Write `files` (path under `addons` -> text), making folders as needed."""
    for relative, text in files.items():
        target = addons / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")


def _expect(name: str, got: tuple[int, str], code: int, named: list[str]) -> int:
    """1 if the run's exit code is not `code` or its output misses one of `named`, else 0."""
    exit_code, printed = got
    missing = [word for word in named if word not in printed]
    if exit_code == code and not missing:
        return 0
    print(f"self-test: {name}: exit {exit_code}, expected {code}; not named: {missing}\n{printed}")
    return 1


def self_test() -> int:
    """Each planted folder gets the exit code it must, naming what it must; 0 if all do."""
    failures = 0
    with tempfile.TemporaryDirectory() as scratch:
        root = pathlib.Path(scratch)
        clean = root / "clean" / "addons"
        _plant(clean, {"ai_toy/toy.gd": TYPES_ONLY, "ai_toy/no_name.gd": "extends Node\n",
                       "other/game_toy.gd": "class_name GameToy\nfunc a() -> Object:\n\treturn GameToy.new()\n"})
        failures += _expect("a script naming itself only in types", quiet_check(clean), 0, ["1 addon script"])
        for stem, text in planted_scripts().items():
            folder = root / stem / "addons"
            _plant(folder, {"ai_toy/toy_types.gd": TYPES_ONLY.replace("Toy", "Other"),
                            f"ai_toy/deeper/{stem}.gd": text})
            failures += _expect(stem, quiet_check(folder), 1, [f"{stem}.gd:", "write `new(...)`"])
        empty = root / "empty" / "addons"
        (empty / "ai_toy").mkdir(parents=True)
        failures += _expect("an empty addons folder", quiet_check(empty), 1, ["nothing was checked"])
        unnamed = root / "unnamed" / "addons"
        _plant(unnamed, {"ai_toy/script.gd": "extends Node\n"})
        failures += _expect("addon scripts, none with a class_name", quiet_check(unnamed), 1,
                            ["nothing was checked"])
        failures += _expect("a missing addons folder", quiet_check(root / "missing"), 2, [])
    print(f"check_self_naming self-test: {failures} failure(s)")
    return 1 if failures else 0


def main() -> int:
    """Parse the arguments and run the check or its self-test."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    parser.add_argument("--addons", type=pathlib.Path, default=ADDONS)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    if arguments.self_test:
        return self_test()
    return check(arguments.addons)


if __name__ == "__main__":
    sys.exit(main())
