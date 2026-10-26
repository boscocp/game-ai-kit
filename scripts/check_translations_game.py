#!/usr/bin/env python3
"""Hold the translated examples to their translation tables (T78).

What "translated" means
-----------------------
A module is translated when `godot/locale/<module>.csv` exists. That file is
its table: Godot's CSV translation format, one row a string, the first column
the key -- the English text itself, so the code still reads as English -- and
a `pt_BR` column beside it. The first cell of the header is ignored by the
engine and is written `en` here, for the reader. Two modules are translated
after T78, every example after T80.

The rules, for each translated module's scripts (not its tests)
---------------------------------------------------------------
L1  a word reaches the screen without passing a translation: a string
    literal with a letter in it is handed to `draw_string`,
    `draw_multiline_string` (and their `_outline` forms), `set_text`, or
    assigned to a `.text`, outside `tr()`, `atr()`, `tr_n()`, `atr_n()` or
    `TranslationServer.translate()`. The overlays are drawn, not Controls,
    so no walk over the scene's Labels would see them; this is how they are
    seen. A literal that is only a format, a number or punctuation ("%+.2f",
    "  ·  ", "\\n") carries no word and is not a finding.
L2  a key passed to a translation call as a literal is not in the module's
    table, or its `pt_BR` is empty.
L3  a row of the table no script of the module mentions: an orphan, which
    a translator would keep translating for nothing.
L4  the table itself: a byte order mark (Godot's documentation asks for
    UTF-8 without one, and Excel writes one), a header without `en` first and
    `pt_BR`, a row with an empty key or a key over two lines, or a key twice.
L5  a `pt_BR` that does not carry exactly its key's `{named}` placeholders:
    `String.format()` would leave a hole on the screen, or a brace.
L6  a key given a `?context` in one table and none in another. Measured on
    4.7.2: a compressed table answers its key whatever context is asked, so
    the context-free row shadows the other (docs/godot/localisation.md).

What it cannot see
------------------
A key that reaches a translation call through a variable -- a rule's
reason kept in English because the rules' vectors state it in English, a
board's name -- is not checked against the table by L2; L3 still holds its
row to a literal somewhere in the module. `make test-locale-screen` opens
the demos in pt-BR and looks at what their Controls show.

Exit codes
----------
0   every translated module holds to its table
1   one or more findings above
2   wrong usage, or a manifest that cannot be read

Usage
-----
    check_translations_game.py [--repo PATH]
    check_translations_game.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import csv
import dataclasses
import io
import json
import pathlib
import re
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
LOCALE = "godot/locale"
PORTUGUESE = "pt_BR"
CONTEXT = "?context"
BOM = b"\xef\xbb\xbf"

# The calls that translate their first argument, and where each keeps the
# context: tr(message, context), tr_n(message, plural, n, context).
TRANSLATING_RE = re.compile(r"(?:(?<![\w.])|(?<=\.))(tr|atr|tr_n|atr_n)\s*\(|TranslationServer\.translate\s*\(")
CONTEXT_ARGUMENT = {"tr": 1, "atr": 1, "tr_n": 3, "atr_n": 3, "translate": 1}
# Where a word becomes pixels: these calls, and an assignment to `.text`.
SINK_CALL_RE = re.compile(r"\b(draw_string|draw_multiline_string|draw_string_outline|"
                          r"draw_multiline_string_outline|set_text)\s*\(")
TEXT_ASSIGN_RE = re.compile(r"(?:\.|^[ \t]*)text\s*\+?=(?!=)", re.M)
LITERAL_RE = re.compile(r"\"@(\d+)\"")
FORMAT_RE = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z%]|\{\w*\}")
PLACEHOLDER_RE = re.compile(r"\{(\w+)\}")
LETTER_RE = re.compile(r"[^\W\d_]")
# A literal right after these is a key into data -- `card.get("title")`,
# `entry["value"]` -- and not a word on the screen.
LOOKUP_RE = re.compile(r"(?:\.get\(|[\w)\]]\[)\s*$")


@dataclasses.dataclass
class Script:
    """One .gd file with its comments gone and each string literal replaced
    by `"@<index>"`, so a regex over the code cannot match inside a string."""

    path: str
    code: str
    literals: list[str]

    def line_of(self, position: int) -> int:
        return self.code.count("\n", 0, position) + 1


@dataclasses.dataclass
class Table:
    """One module's CSV: its rows by (context, key), and what is wrong with it."""

    path: str
    rows: dict[tuple[str, str], str]
    findings: list[str]


# --- reading GDScript --------------------------------------------------------


def masked(path: str, text: str) -> Script:
    """`text` with comments removed and string literals swapped for tokens."""
    out: list[str] = []
    literals: list[str] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char == "#":
            while index < len(text) and text[index] != "\n":
                index += 1
            continue
        if char in "\"'":
            value, index = _read_string(text, index)
            out.append(f'"@{len(literals)}"' + "\n" * value.count("\n"))
            literals.append(value)
            continue
        out.append(char)
        index += 1
    return Script(path, "".join(out), literals)


def _read_string(text: str, start: int) -> tuple[str, int]:
    """The value of the literal opening at `start`, and where it ends.

    A raw prefix (`r"..."`) was already copied as code; its escapes are kept
    as written, which is what the engine does too -- close enough for keys.
    """
    quote = text[start] * 3 if text.startswith(text[start] * 3, start) else text[start]
    index = start + len(quote)
    value: list[str] = []
    escapes = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
    while index < len(text) and not text.startswith(quote, index):
        if text[index] == "\\" and index + 1 < len(text):
            value.append(escapes.get(text[index + 1], "\\" + text[index + 1]))
            index += 2
            continue
        value.append(text[index])
        index += 1
    return "".join(value), index + len(quote)


def _arguments(code: str, open_paren: int) -> tuple[int, list[tuple[int, int]]]:
    """Where the call opened at `open_paren` closes, and its top-level arguments."""
    depth = 0
    spans = []
    start = open_paren + 1
    for index in range(open_paren, len(code)):
        char = code[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                spans.append((start, index))
                return index, [span for span in spans if code[span[0]:span[1]].strip()]
        elif char == "," and depth == 1:
            spans.append((start, index))
            start = index + 1
    return len(code), spans


def _statement_end(code: str, start: int) -> int:
    """The end of the logical line that `start` is in: brackets and `\\` join lines."""
    depth = 0
    index = start
    while index < len(code):
        char = code[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "\n" and depth <= 0 and code[index - 1] != "\\":
            return index
        index += 1
    return index


def _literal_of(script: Script, span: tuple[int, int]) -> str | None:
    """The literal an argument is, when it is one literal and nothing more."""
    match = LITERAL_RE.fullmatch(script.code[span[0]:span[1]].strip())
    return script.literals[int(match.group(1))] if match else None


def translation_calls(script: Script) -> list[tuple[int, int, str | None, str]]:
    """Each translation call: its span, its literal key (or None), its context."""
    calls = []
    for match in TRANSLATING_RE.finditer(script.code):
        name = match.group(1) or "translate"
        close, spans = _arguments(script.code, match.end() - 1)
        key = _literal_of(script, spans[0]) if spans else None
        where = CONTEXT_ARGUMENT[name]
        context = (_literal_of(script, spans[where]) or "") if len(spans) > where else ""
        calls.append((match.start(), close, key, context))
    return calls


def has_a_word(value: str) -> bool:
    """True when a literal says something, not only how to format a number."""
    return LETTER_RE.search(FORMAT_RE.sub("", value)) is not None


def bare_words(script: Script) -> list[str]:
    """L1: literals with a word in them that reach the screen untranslated."""
    translated = [(start, end) for start, end, _, _ in translation_calls(script)]
    regions = []
    for match in SINK_CALL_RE.finditer(script.code):
        regions.append((match.start(), _arguments(script.code, match.end() - 1)[0]))
    for match in TEXT_ASSIGN_RE.finditer(script.code):
        regions.append((match.start(), _statement_end(script.code, match.end())))
    findings = []
    for start, end in regions:
        for literal in LITERAL_RE.finditer(script.code, start, end):
            inside = any(low <= literal.start() <= high for low, high in translated)
            lookup = LOOKUP_RE.search(script.code, start, literal.start()) is not None
            value = script.literals[int(literal.group(1))]
            if not inside and not lookup and has_a_word(value):
                findings.append(f"L1 {script.path}:{script.line_of(literal.start())}: {value!r} "
                                "reaches the screen without tr()")
    return sorted(set(findings))


# --- reading the tables --------------------------------------------------------


def read_table(repo: pathlib.Path, module: str) -> Table:
    """The module's CSV, parsed the way Godot's importer reads it."""
    relative = f"{LOCALE}/{module}.csv"
    raw = (repo / relative).read_bytes()
    table = Table(relative, {}, [])
    if raw.startswith(BOM):
        table.findings.append(f"L4 {relative}: starts with a byte order mark; save it as UTF-8 without one")
        raw = raw[len(BOM):]
    try:
        records = list(csv.reader(io.StringIO(raw.decode("utf-8"), newline="")))
    except (UnicodeDecodeError, csv.Error) as error:
        table.findings.append(f"L4 {relative}: cannot be read as UTF-8 CSV: {error}")
        return table
    header = records[0] if records else []
    if not header or header[0] != "en" or PORTUGUESE not in header:
        table.findings.append(f"L4 {relative}: the header must be `en`, then `{PORTUGUESE}` "
                              f"(and `{CONTEXT}` if needed); it is {header}")
        return table
    for number, record in enumerate(records[1:], start=2):
        _read_row(table, header, record, number)
    return table


def _read_row(table: Table, header: list[str], record: list[str], number: int) -> None:
    cells = dict(zip(header, record + [""] * len(header)))
    key = record[0] if record else ""
    context = cells.get(CONTEXT, "")
    portuguese = cells.get(PORTUGUESE, "")
    where = f"{table.path}:{number}"
    if not key or "\n" in key:
        table.findings.append(f"L4 {where}: a key must be one line of text, and not empty")
        return
    if (context, key) in table.rows:
        table.findings.append(f"L4 {where}: {key!r} is already a row")
    table.rows[(context, key)] = portuguese
    if portuguese and set(PLACEHOLDER_RE.findall(portuguese)) != set(PLACEHOLDER_RE.findall(key)):
        table.findings.append(f"L5 {where}: {key!r} and its {PORTUGUESE} do not name the same "
                              "{placeholders}")


# --- the modules ---------------------------------------------------------------


def load_owners(repo: pathlib.Path) -> dict[str, tuple[str, ...]]:
    """Each module's `owns`, read from modules/*.json."""
    owners = {}
    for path in sorted((repo / "modules").glob("*.json")):
        manifest = json.loads(path.read_text(encoding="utf-8"))
        owners[manifest["module"]] = tuple(manifest["owns"])
    return owners


def owner_of(path: str, owners: dict[str, tuple[str, ...]]) -> str | None:
    """The module whose `owns` covers `path` most closely, as check_modules says."""
    found = [(len(prefix), name) for name, owns in owners.items() for prefix in owns
             if path == prefix or (prefix.endswith("/") and path.startswith(prefix))]
    return max(found)[1] if found else None


def scripts_of(repo: pathlib.Path, module: str, owners: dict[str, tuple[str, ...]]) -> list[Script]:
    """The module's own .gd files under godot/, its tests left out."""
    scripts = []
    for prefix in owners[module]:
        if not prefix.startswith("godot/") or prefix.startswith("godot/test/"):
            continue
        base = repo / prefix
        files = sorted(base.rglob("*.gd")) if base.is_dir() else [base] if base.suffix == ".gd" else []
        for file in files:
            relative = file.relative_to(repo).as_posix()
            if owner_of(relative, owners) == module:
                scripts.append(masked(relative, file.read_text(encoding="utf-8")))
    return scripts


def check_module(repo: pathlib.Path, module: str, owners: dict[str, tuple[str, ...]],
                 table: Table) -> list[str]:
    """L1, L2 and L3 for one translated module."""
    scripts = scripts_of(repo, module, owners)
    findings = list(table.findings)
    mentioned: set[str] = set()
    for script in scripts:
        findings += bare_words(script)
        mentioned |= set(script.literals)
        for start, _, key, context in translation_calls(script):
            if key is None:
                continue
            where = f"{script.path}:{script.line_of(start)}"
            if (context, key) not in table.rows:
                findings.append(f"L2 {where}: {key!r} is not in {table.path}")
    for context, key in sorted(table.rows):
        if not table.rows[(context, key)]:
            findings.append(f"L2 {table.path}: {key!r} has no {PORTUGUESE}")
        if key not in mentioned:
            findings.append(f"L3 {table.path}: {key!r} is in no script of {module}")
    return findings


def shadowed(tables: dict[str, Table]) -> list[str]:
    """L6: a key with a context in one row and none in another."""
    without = {key for table in tables.values() for context, key in table.rows if not context}
    return [f"L6 {table.path}: {key!r} has the context {context!r}, and a row without "
            "one would answer for it"
            for table in tables.values() for context, key in sorted(table.rows)
            if context and key in without]


def check(repo: pathlib.Path) -> list[str]:
    """Every finding for every translated module."""
    owners = load_owners(repo)
    tables = {module: read_table(repo, module) for module in sorted(owners)
              if (repo / LOCALE / f"{module}.csv").is_file()}
    if not tables:
        print(f"L0 note: no module has a table under {LOCALE}/ -- nothing is translated")
    findings = []
    for module, table in tables.items():
        findings += check_module(repo, module, owners, table)
    findings += shadowed(tables)
    for stray in sorted((repo / LOCALE).glob("*.csv")) if (repo / LOCALE).is_dir() else []:
        if stray.stem not in owners:
            findings.append(f"L4 {LOCALE}/{stray.name}: names no module")
    return findings


def run(repo: pathlib.Path) -> int:
    try:
        findings = check(repo)
    except (OSError, ValueError, KeyError) as error:
        print(f"check_translations_game: cannot read the manifests: {error!r}", file=sys.stderr)
        return 2
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -----------------------------------------------------------------

CLEAN_SCRIPT = '''extends Node2D
const NAMES: Array[String] = ["breadth-first"]

func _draw() -> void:
	draw_string(font, Vector2.ZERO, tr("left-drag: paint {brush}").format({brush = tr(NAMES[0])}))
	draw_string(font, Vector2.ZERO, "%+.2f" % value)  # a format, not a word
	$Label.text = "  ·  ".join([tr("cost {cost}").format({cost = 3}), str(4)])
	$Heading.text = card.get("title", "") + entry["name"]
	var waiting: String = TranslationServer.translate(
			"white has not moved yet.")
'''
CLEAN_TABLE = ("en,pt_BR\n"
               "left-drag: paint {brush},arrastar: pinta {brush}\n"
               "breadth-first,busca em largura\n"
               "cost {cost},custo {cost}\n"
               "white has not moved yet.,as brancas ainda não jogaram.\n")


def build(root: pathlib.Path, name: str, script: str = CLEAN_SCRIPT, table: str | bytes = CLEAN_TABLE,
          extra: dict[str, str] | None = None) -> pathlib.Path:
    """A repository with one translated module, `demo`, and one that is not."""
    repo = root / name
    files: dict[str, str | bytes] = {
        "modules/demo.json": json.dumps({"module": "demo", "owns": ["godot/demo/", "godot/locale/demo.csv"]}),
        "modules/other.json": json.dumps({"module": "other", "owns": ["godot/other/"]}),
        "godot/demo/demo.gd": script,
        "godot/locale/demo.csv": table,
        # Not translated: a bare literal there is not this gate's business yet.
        "godot/other/other.gd": 'func _ready() -> void:\n\t$Label.text = "Hello"\n',
    }
    files.update(extra or {})
    for relative, content in files.items():
        path = repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content, encoding="utf-8")
    return repo


def self_test() -> int:
    failures = []

    def expect(label: str, repo: pathlib.Path, want: int, rule: str = "") -> None:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            got = run(repo)
        if got != want or rule not in output.getvalue():
            failures.append(f"{label}: expected exit {want} naming {rule or 'nothing'}, "
                            f"got {got}:\n{output.getvalue()}")

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        expect("clean", build(root, "clean"), 0)
        expect("bare draw_string", build(root, "draw", CLEAN_SCRIPT.replace(
            '"%+.2f" % value', '"wins"')), 1, "L1")
        expect("bare .text", build(root, "text", CLEAN_SCRIPT.replace(
            "\t$Label.text", '\t$Status.text = "your move" if mine else "white thinks"\n\t$Label.text')), 1, "L1")
        expect("bare set_text", build(root, "set_text", CLEAN_SCRIPT + '\t$Label.set_text("Play")\n'), 1, "L1")
        expect("missing key", build(root, "missing", CLEAN_SCRIPT + '\tprint(tr("not in the table"))\n'), 1, "L2")
        expect("empty pt_BR", build(root, "empty", table=CLEAN_TABLE.replace(
            "busca em largura", "")), 1, "L2")
        expect("orphan key", build(root, "orphan", table=CLEAN_TABLE + "nobody says this,ninguém diz isto\n"),
               1, "L3")
        expect("byte order mark", build(root, "bom", table=BOM + CLEAN_TABLE.encode("utf-8")), 1, "L4")
        expect("header", build(root, "header", table=CLEAN_TABLE.replace("en,pt_BR", "keys,pt_PT")), 1, "L4")
        expect("key twice", build(root, "twice", table=CLEAN_TABLE + "breadth-first,largura\n"), 1, "L4")
        expect("placeholder lost", build(root, "placeholder", table=CLEAN_TABLE.replace(
            "custo {cost}", "custo")), 1, "L5")
        expect("context shadowed", build(root, "context", extra={
            "modules/menu.json": json.dumps({"module": "menu", "owns": ["godot/menu/"]}),
            "godot/menu/menu.gd": 'func _ready() -> void:\n\t$Button.text = tr("breadth-first", "a card")\n',
            "godot/locale/menu.csv": "en,?context,pt_BR\nbreadth-first,a card,largura\n"}), 1, "L6")
        expect("a comment is not code", build(root, "comment", CLEAN_SCRIPT + '\t# draw_string(font, p, "words")\n'), 0)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run([sys.executable, str(script), "--unknown-flag"], capture_output=True)
        if extra.returncode != 2:
            failures.append(f"unknown flag: expected exit 2, got {extra.returncode}")

    for failure in failures:
        print(f"FAIL {failure}")
    print(f"check_translations_game self-test: {'FAILED' if failures else 'ok'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", type=pathlib.Path, default=REPO)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    return self_test() if args.self_test else run(args.repo)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
