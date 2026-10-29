#!/usr/bin/env python3
"""Hold the translated examples to their translation tables (T78).

What "translated" means
-----------------------
A module is translated when `godot/locale/<module>.csv` exists. That file is
its table: Godot's CSV translation format, one row a string, the first column
the key -- the English text itself, so the code still reads as English -- and
a `pt_BR` column beside it. The first cell of the header is ignored by the
engine and is written `en` here, for the reader. Two examples (and the menu)
are translated after T78, every example after T80.

The rules, for each translated module's scripts (not its tests)
---------------------------------------------------------------
L1  every word passes a translation. A string literal that says something
    -- it has a letter and a space, or it is a key of the module's table --
    must sit inside `tr()`, `atr()`, `tr_n()`, `atr_n()` or
    `TranslationServer.translate()`, or be a key into data (`card.get("x")`,
    `entry["x"]`, `{"x": ...}`, a `res://` path), or be marked on the line
    where its statement starts:
        # shown through tr()   the English is a key, translated where it is
                               shown (a rule's reason the vectors state in
                               English, a const list read as tr(NAMES[i]));
                               it must then be in the table (L2)
        # not shown            data or a comparison, never on the screen
    A literal handed to `draw_string`, `draw_multiline_string` (and their
    `_outline` forms), `set_text`, `Legend.set_entries` or assigned to a
    `.text` must be translated even when it is one word, marker or not.
    Inverted, because the words are built in helpers far from the call that
    draws them: a gate that looked only inside the drawing statement saw none
    of ninety untranslated strings (wave 88's review).
L2  a key passed to a translation call as a literal, or marked
    `# shown through tr()`, is not in the module's table, or its `pt_BR`
    is empty.
L3  a row of the table no script of the module mentions: an orphan, which
    a translator would keep translating for nothing.
L4  the table itself: a byte order mark (Godot's documentation asks for
    UTF-8 without one; some editors, and Excel's "CSV UTF-8", write one), a
    header without `en` first and `pt_BR`, a row with an empty key or a key
    over two lines, or a key twice.
L5  a `pt_BR` that does not carry exactly its key's `{named}` placeholders:
    `String.format()` would leave a hole on the screen, or a brace.
L6  a key given a `?context` in one table and none in another. Measured on
    4.7.2: a compressed table answers its key whatever context is asked, so
    the context-free row shadows the other (docs/godot/localisation.md).
L7  a key built inside the call -- `tr("wins %s" % name)`, `tr("a" + b)` --
    which no table can hold; translate the sentence, then `.format()` it.
L8  a key two tables translate differently. Every table is loaded into the
    one TranslationServer, so a key has one translation in the whole game
    and which table answers is not the reader's to choose: the stealth
    guard's "investigate" and the behaviour tree's said two things (T79).
L9  a translation call inside the arguments of `Sentence.of(...)`. A sentence
    an AI keeps is its English key and values, worded where it is shown
    (T80, T104); a key translated as it is kept makes the AI's state, and
    every overlay and test that reads it, depend on the language on screen.
    T104's review planted one in a reason no game in the tests reached. A
    translated value handed in through a variable or a helper is not seen.

What it cannot see
------------------
A one-word literal that is not a key of the table and is not handed straight
to a drawing call is taken for data (`"font_size"`, `"abcdefgh"`); a single
English word built into text elsewhere passes. Text written in a `.tscn` is
not read: the scenes here say "loading" and are filled from code. The
`?plural` column and `tr_n()`'s plural argument are not checked; nothing uses
them yet. `make test-locale-screen` opens the demos in pt-BR and looks at
what their Controls and legends show, which catches what this misses on
the screens it opens.

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
SHOWN_LATER = "shown through tr()"
NOT_SHOWN = "not shown"

# The calls that translate their first argument, and where each keeps the
# context: tr(message, context), tr_n(message, plural, n, context).
TRANSLATING_RE = re.compile(r"(?:(?<![\w.])|(?<=\.))(tr|atr|tr_n|atr_n)\s*\(|TranslationServer\.translate\s*\(")
CONTEXT_ARGUMENT = {"tr": 1, "atr": 1, "tr_n": 3, "atr_n": 3, "translate": 1}
# Where a word becomes pixels: these calls, and an assignment to `.text`.
SINK_CALL_RE = re.compile(r"\b(draw_string|draw_multiline_string|draw_string_outline|"
                          r"draw_multiline_string_outline|set_text|set_entries)\s*\(")
TEXT_ASSIGN_RE = re.compile(r"(?:\.|^[ \t]*)text\s*\+?=(?!=)", re.M)
LITERAL_RE = re.compile(r"\"@(\d+)\"")
FORMAT_RE = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z%]|\{\w*\}|\[/?\w+(?:=[^\]]*)?\]")
PLACEHOLDER_RE = re.compile(r"\{(\w+)\}")
LETTER_RE = re.compile(r"[^\W\d_]")
# A literal right after these is a key into data -- `card.get("title")`,
# `entry["value"]` -- and not a word on the screen.
LOOKUP_BEFORE_RE = re.compile(r"(?:\.get\(|[\w)\]]\[)\s*$")
# ...and a literal followed by a colon is a dictionary's key: `{"move": m}`.
LOOKUP_AFTER_RE = re.compile(r"\s*:(?!=)")
# A sentence kept to be worded later (`godot/game/sentence.gd`).
SENTENCE_RE = re.compile(r"(?<![\w.])Sentence\.of\s*\(")

# A key built at the call: the first argument goes on past its literal.
BUILT_KEY_RE = re.compile(r"\s*\"@\d+\"\s*[%+]")


@dataclasses.dataclass
class Script:
    """One .gd file with its comments gone and each string literal replaced
    by `"@<index>"`, so a regex over the code cannot match inside a string.
    `comments` keeps each comment's text by line, for the markers."""

    path: str
    code: str
    literals: list[str]
    comments: dict[int, str]

    def line_of(self, position: int) -> int:
        return self.code.count("\n", 0, position) + 1

    def line_start(self, line: int) -> int:
        position = 0
        for _ in range(line - 1):
            position = self.code.index("\n", position) + 1
        return position


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
    comments: dict[int, str] = {}
    line = 1
    index = 0
    while index < len(text):
        char = text[index]
        if char == "#":
            end = text.find("\n", index)
            end = len(text) if end < 0 else end
            comments[line] = text[index:end]
            index = end
            continue
        if char in "\"'":
            start = index
            value, index = _read_string(text, index)
            # The lines the literal spans in the source, not the newlines
            # in its value: a "\n" escape is one line of code (T80 found
            # every finding after one reported a line too far down).
            spanned = text.count("\n", start, index)
            out.append(f'"@{len(literals)}"' + "\n" * spanned)
            line += spanned
            literals.append(value)
            continue
        line += char == "\n"
        out.append(char)
        index += 1
    return Script(path, "".join(out), literals, comments)


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


def built_keys(script: Script) -> list[str]:
    """L7: translation calls whose first argument is a literal and more."""
    findings = []
    for match in TRANSLATING_RE.finditer(script.code):
        spans = _arguments(script.code, match.end() - 1)[1]
        if spans and BUILT_KEY_RE.match(script.code, spans[0][0]):
            findings.append(f"L7 {script.path}:{script.line_of(match.start())}: the key is built "
                            "inside the call; translate the sentence, then .format() it")
    return findings


def worded_too_soon(script: Script) -> list[str]:
    """L9: a translation call inside `Sentence.of(...)`'s arguments."""
    findings = []
    for match in SENTENCE_RE.finditer(script.code):
        close = _arguments(script.code, match.end() - 1)[0]
        if TRANSLATING_RE.search(script.code, match.end(), close) is not None:
            findings.append(f"L9 {script.path}:{script.line_of(match.start())}: a translation inside "
                            "Sentence.of(); keep the English key, and word it where it is shown")
    return findings


def has_a_word(value: str) -> bool:
    """True when a literal says something, not only how to format a number."""
    return LETTER_RE.search(FORMAT_RE.sub("", value)) is not None


def marked(script: Script, marker: str) -> list[tuple[int, int]]:
    """The statements whose first line carries `# <marker>`."""
    regions = []
    for line, comment in script.comments.items():
        if marker in comment:
            start = script.line_start(line)
            regions.append((start, _statement_end(script.code, start)))
    return regions


def _within(position: int, regions: list[tuple[int, int]]) -> bool:
    return any(low <= position <= high for low, high in regions)


def _is_data(script: Script, position: int, end: int, value: str) -> bool:
    """A literal used as a key into data, or a path: never a word on screen."""
    line_start = script.code.rfind("\n", 0, position) + 1
    return (LOOKUP_BEFORE_RE.search(script.code, line_start, position) is not None
            or LOOKUP_AFTER_RE.match(script.code, end) is not None
            or value.startswith(("res://", "user://")))


def sink_regions(script: Script) -> list[tuple[int, int]]:
    """Where a literal goes straight to the screen."""
    regions = []
    for match in SINK_CALL_RE.finditer(script.code):
        regions.append((match.start(), _arguments(script.code, match.end() - 1)[0]))
    for match in TEXT_ASSIGN_RE.finditer(script.code):
        regions.append((match.start(), _statement_end(script.code, match.end())))
    return regions


def bare_words(script: Script, keys: set[str]) -> list[str]:
    """L1: literals that say something and pass no translation."""
    translated = [(start, end) for start, end, _, _ in translation_calls(script)]
    excused = marked(script, SHOWN_LATER) + marked(script, NOT_SHOWN)
    sinks = sink_regions(script)
    findings = []
    for literal in LITERAL_RE.finditer(script.code):
        value = script.literals[int(literal.group(1))]
        if not has_a_word(value) or _within(literal.start(), translated):
            continue
        if _is_data(script, literal.start(), literal.end(), value):
            continue
        to_screen = _within(literal.start(), sinks)
        says_something = to_screen or " " in value.strip() or value in keys
        if says_something and (to_screen or not _within(literal.start(), excused)):
            findings.append(f"L1 {script.path}:{script.line_of(literal.start())}: {value!r} passes "
                            f"no tr(); translate it, or mark it `# {SHOWN_LATER}` or `# {NOT_SHOWN}`")
    return findings


def keys_shown_later(script: Script) -> list[tuple[int, str]]:
    """The literals marked `# shown through tr()`: each a key the table must hold."""
    found = []
    for start, end in marked(script, SHOWN_LATER):
        for literal in LITERAL_RE.finditer(script.code, start, end):
            value = script.literals[int(literal.group(1))]
            if has_a_word(value) and not _is_data(script, literal.start(), literal.end(), value):
                found.append((literal.start(), value))
    return found


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


def _keys_used(script: Script) -> list[tuple[int, str, str]]:
    """Every key the script names: literal translation calls, and marked literals."""
    used = [(start, key, context) for start, _, key, context in translation_calls(script) if key is not None]
    return used + [(start, key, "") for start, key in keys_shown_later(script)]


def check_module(repo: pathlib.Path, module: str, owners: dict[str, tuple[str, ...]],
                 table: Table) -> list[str]:
    """L1, L2, L3, L7 and L9 for one translated module."""
    keys = {key for _, key in table.rows}
    findings = list(table.findings)
    mentioned: set[str] = set()
    for script in scripts_of(repo, module, owners):
        findings += bare_words(script, keys) + built_keys(script) + worded_too_soon(script)
        mentioned |= set(script.literals)
        for start, key, context in _keys_used(script):
            if (context, key) not in table.rows:
                findings.append(f"L2 {script.path}:{script.line_of(start)}: {key!r} is not in {table.path}")
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


def disagreeing(tables: dict[str, Table]) -> list[str]:
    """L8: one key, two translations, in two tables."""
    said: dict[tuple[str, str], dict[str, str]] = {}
    for table in tables.values():
        for row, portuguese in table.rows.items():
            said.setdefault(row, {})[table.path] = portuguese
    return [f"L8 {key!r} is {' and '.join(repr(text) for text in sorted(set(where.values())))} "
            f"in {', '.join(sorted(where))}: one key has one translation in the whole game"
            for (_, key), where in sorted(said.items()) if len(set(where.values())) > 1]


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
    findings += shadowed(tables) + disagreeing(tables)
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
const NAMES: Array[String] = ["breadth-first"]  # shown through tr()
const FINDS: Array[String] = [  # shown through tr()
	"the cheapest route",
]

func _ready() -> void:
	_legend.set_entries([[Color.RED, tr("red dot: goal")]] as Array[Array])

func _draw() -> void:
	draw_string(font, Vector2.ZERO, tr("left-drag: paint {brush}").format({brush = tr(NAMES[0])}))
	draw_string(font, Vector2.ZERO, "%+.2f" % value)  # a format, not a word
	$Label.text = "  ·  ".join([tr("cost {cost}").format({cost = 3}), str(4)])
	$Heading.text = card.get("title", "") + entry["name"]
	var overlay: Dictionary = {"route": path, "board name": name}
	var waiting: String = TranslationServer.translate(
			"white has not moved yet.")
	if evaluation == "hand written":  # not shown
		load("res://game/some file.gd")
	var finds: String = tr(FINDS[0])
	var bold: String = "[b]%s[/b] -- %s" % [first, second]
	var kept: Array = Sentence.of("cost {cost}", {cost = 3, then = Sentence.of("red dot: goal")})  # shown through tr()
	var worded: String = tr("cost {cost}").format({cost = Sentence.english(kept)})
'''
CLEAN_TABLE = ("en,pt_BR\n"
               "left-drag: paint {brush},arrastar: pinta {brush}\n"
               "breadth-first,busca em largura\n"
               "the cheapest route,a rota mais barata\n"
               "cost {cost},custo {cost}\n"
               "red dot: goal,ponto vermelho: objetivo\n"
               "white has not moved yet.,as brancas ainda não jogaram.\n")
# The real shapes wave 88's review planted, each one a line added to the clean
# script: words built in a helper, a legend, a variable handed to draw_string.
PLANTED_L1 = {
    "a legend entry": '\t_legend.set_entries([[Color.RED, "red dot: goal"]] as Array[Array])\n',
    "a helper's line": '\treturn "\\n".join([tr("cost {cost}"), "Edit the board"])\n',
    "a status line": '\tvar line: String = "1-4 choose  ·  space steps"\n',
    "through a variable": '\tvar words := "you lose"\n\tdraw_string(font, p, words)\n',
    "a one-word key": '\tvar shown: String = "breadth-first"\n',
    "bare draw_string": '\tdraw_string(font, p, "wins")\n',
    "bare .text": '\t$Status.text = "Play" if mine else "Wait"\n',
    "bare set_text": '\t$Label.set_text("Play")\n',
    "a marker on a sink": '\t$Label.text = "your move"  # not shown\n',
}


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
        "godot/other/other.gd": 'func _ready() -> void:\n\t$Label.text = "Hello there"\n',
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


def _table_cases(root: pathlib.Path, expect) -> None:
    expect("missing key", build(root, "missing", CLEAN_SCRIPT + '\tprint(tr("not in the table"))\n'), 1, "L2")
    expect("marked key missing", build(root, "marked", CLEAN_SCRIPT
           + '\tvar reason: String = "no such reason here"  # shown through tr()\n'), 1, "L2")
    expect("empty pt_BR", build(root, "empty", table=CLEAN_TABLE.replace("busca em largura", "")), 1, "L2")
    expect("orphan key", build(root, "orphan", table=CLEAN_TABLE + "nobody says this,ninguém diz isto\n"),
           1, "L3")
    expect("byte order mark", build(root, "bom", table=BOM + CLEAN_TABLE.encode("utf-8")), 1, "byte order mark")
    expect("header", build(root, "header", table=CLEAN_TABLE.replace("en,pt_BR", "keys,pt_PT")), 1, "L4")
    expect("key twice", build(root, "twice", table=CLEAN_TABLE + "breadth-first,largura\n"), 1, "L4")
    expect("placeholder lost", build(root, "placeholder", table=CLEAN_TABLE.replace(
        "custo {cost}", "custo")), 1, "L5")
    expect("context shadowed", build(root, "context", extra={
        "modules/menu.json": json.dumps({"module": "menu", "owns": ["godot/menu/"]}),
        "godot/menu/menu.gd": 'func _ready() -> void:\n\t$Button.text = tr("breadth-first", "a card")\n',
        "godot/locale/menu.csv": "en,?context,pt_BR\nbreadth-first,a card,largura\n"}), 1, "L6")
    expect("two translations", build(root, "two", extra={
        "modules/menu.json": json.dumps({"module": "menu", "owns": ["godot/menu/"]}),
        "godot/menu/menu.gd": 'func _ready() -> void:\n\t$Button.text = tr("breadth-first")\n',
        "godot/locale/menu.csv": "en,pt_BR\nbreadth-first,largura\n"}), 1, "L8")
    expect("key built with %", build(root, "percent", CLEAN_SCRIPT + '\tprint(tr("cost %d" % 3))\n'), 1, "L7")
    expect("key built with +", build(root, "plus", CLEAN_SCRIPT + '\tprint(tr("cost " + str(3)))\n'), 1, "L7")
    expect("a key translated as it is kept", build(root, "kept", CLEAN_SCRIPT
           + '\tvar why: Array = Sentence.of(tr("cost {cost}"), {cost = 3})\n'), 1, "L9")
    expect("a value translated as it is kept", build(root, "value", CLEAN_SCRIPT
           + '\tvar why: Array = Sentence.of("cost {cost}", {  # shown through tr()\n'
           + '\t\tcost = TranslationServer.translate("breadth-first")})\n'), 1, "L9")


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
        for number, (label, line) in enumerate(PLANTED_L1.items()):
            expect(label, build(root, f"l1_{number}", CLEAN_SCRIPT + line), 1, "L1")
        expect("a comment is not code", build(root, "comment", CLEAN_SCRIPT + '\t# draw_string(font, p, "a b")\n'), 0)
        # A "\n" escape is not a line of code: the finding names the line it is on.
        escaped = CLEAN_SCRIPT + '\tvar joined: String = "\\n".join([])\n\tvar shown: String = "Edit the board"\n'
        expect("the line after a \\n escape", build(root, "escape", escaped), 1,
               f"demo.gd:{escaped.count(chr(10))}: 'Edit the board'")
        _table_cases(root, expect)

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
