#!/usr/bin/env python3
"""Keep each documentation page honest about how long it lasts.

The rule
--------
Teaching material about games rots at three very different speeds, and mixing
them is what makes a tutorial untrustworthy: the reader cannot tell which
sentence is still true. So each page declares its own half-life, and the folder
it lives in has to agree:

    docs/concepts/   concept   730 days   why A* is optimal with an admissible heuristic
    docs/godot/      practice  182 days   how to wire the addon into a TileMapLayer
    docs/local-llm/  tool       91 days   num_ctx, model names, VRAM

Every page carries a block right under its title:

    <!-- doc-meta
    half_life: practice
    verified_on: 2026-10-12
    tier: 2
    source: https://docs.godotengine.org/... ; https://...
    invalidated_if: what would make this page wrong, in a sentence
    -->

`verified_on` is the day someone *opened* the source, not the date on the
source. The block takes no comments: everything after the colon is the value.

Why this gate exists
--------------------
A page from a year ago about an engine's API looks exactly like one from last
week. `docs/local-llm/` is *supposed* to expire every quarter; that is the
behaviour working, not a defect. What this gate prevents is a stale page going
unnoticed because nobody remembers which ones move fast.

Exit codes
----------
0   every page well-formed and still inside its half-life
1   malformed, mismatched, or expired pages (each one printed)
2   wrong usage, or a file that cannot be read

Usage
-----
    check_doc_freshness.py [--docs PATH] [--today YYYY-MM-DD]
    check_doc_freshness.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import datetime
import io
import pathlib
import re
import subprocess
import sys
import tempfile

# The three layers, and how long a claim in each is trusted without rechecking.
HALF_LIFE_DAYS = {"concept": 730, "practice": 182, "tool": 91}

# Which layer each folder holds. A page in the wrong folder is a page whose
# reader cannot tell how much to trust it.
FOLDER_LAYER = {"concepts": "concept", "godot": "practice", "local-llm": "tool"}

# Folders under docs/ that are dated records rather than living pages, and so
# carry no half-life: an ADR is amended in place, a review and a wave note are
# snapshots of a day. Anything else under docs/ is a page whose layer nobody
# declared, which is the state this gate exists to prevent.
EXEMPT_FOLDERS = {"adr", "reviews", "harness-notes", "images"}

REQUIRED_FIELDS = ("half_life", "verified_on", "tier", "source", "invalidated_if")

BLOCK_RE = re.compile(r"<!--\s*doc-meta\s*\n(.*?)-->", re.S)
FIELD_RE = re.compile(r"^\s*([a-z_]+)\s*:\s*(.*?)\s*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
VALID_SOURCE = re.compile(r"^(https://\S+|book:\S.*)$")

MIN_INVALIDATION_WORDS = 4


def parse_block(text: str) -> tuple[dict[str, str] | None, list[str]]:
    """Return the page's doc-meta fields, plus any problems with the block."""
    blocks = list(BLOCK_RE.finditer(text))
    if not blocks:
        return None, ["M1 no <!-- doc-meta ... --> block"]
    if len(blocks) > 1:
        # Only the first was ever read, so a second one -- expired, or
        # contradicting the first -- went unseen.
        return None, [f"M14 {len(blocks)} doc-meta blocks; a page declares its layer once"]
    match = blocks[0]

    fields: dict[str, str] = {}
    problems = []
    for line in match.group(1).splitlines():
        if not line.strip():
            continue
        field = FIELD_RE.match(line)
        if field is None:
            problems.append(f"M2 malformed line in doc-meta: {line.strip()!r}")
            continue
        key, value = field.groups()
        if key in fields:
            problems.append(f"M3 repeated field {key!r}")
        fields[key] = value
    return fields, problems


def check_fields(fields: dict[str, str], folder: str, today: datetime.date) -> list[str]:
    """Validate the block's values, and report a page past its half-life."""
    problems = []

    for required in REQUIRED_FIELDS:
        if not fields.get(required):
            problems.append(f"M4 field {required!r} is missing or empty")
    if problems:
        return problems

    layer = fields["half_life"]
    if layer not in HALF_LIFE_DAYS:
        return [f"M5 half_life {layer!r} is not one of {', '.join(HALF_LIFE_DAYS)}"]

    expected = FOLDER_LAYER.get(folder)
    if expected and layer != expected:
        problems.append(f"M6 a page in {folder}/ declares half_life {layer!r}; that folder is {expected!r}")

    if not DATE_RE.match(fields["verified_on"]):
        return problems + [f"M7 verified_on {fields['verified_on']!r} is not YYYY-MM-DD"]
    verified = datetime.date.fromisoformat(fields["verified_on"])
    if verified > today:
        problems.append(f"M8 verified_on {verified} is in the future")

    # Valid through verified_on + half-life inclusive; expired the day after.
    expires = verified + datetime.timedelta(days=HALF_LIFE_DAYS[layer])
    if today > expires:
        problems.append(
            f"M9 expired: checked {verified}, {layer} lasts {HALF_LIFE_DAYS[layer]} days, due {expires}"
        )

    if fields["tier"] not in {"0", "1", "2", "3"}:
        problems.append(f"M10 tier {fields['tier']!r} is not 0, 1, 2 or 3")

    sources = [s.strip() for s in fields["source"].split(";") if s.strip()]
    if not sources:
        problems.append("M11 source lists nothing")
    for source in sources:
        if not VALID_SOURCE.match(source):
            problems.append(f"M12 source {source!r} is neither an https:// URL nor book:…")

    if len(fields["invalidated_if"].split()) < MIN_INVALIDATION_WORDS:
        problems.append(
            f"M13 invalidated_if needs at least {MIN_INVALIDATION_WORDS} words saying what would break it"
        )

    return problems


def layered_pages(docs: pathlib.Path) -> tuple[list[pathlib.Path], list[str]]:
    """Pages that must declare a half-life, plus pages in no declared layer.

    `rglob`, not `glob`, and over all of docs/ rather than three hard-coded
    folders: a review found that a page one directory deeper, or in a folder
    nobody had thought of, was simply never looked at.
    """
    pages, orphans = [], []
    for path in sorted(docs.rglob("*.md")):
        relative = path.relative_to(docs)
        top = relative.parts[0] if len(relative.parts) > 1 else ""
        if top in FOLDER_LAYER:
            pages.append(path)
        elif top not in EXEMPT_FOLDERS:
            orphans.append(
                f"{relative}: M15 in no declared layer -- move it under "
                f"{'/, '.join(FOLDER_LAYER)}/ or add the folder to EXEMPT_FOLDERS with a reason"
            )
    return pages, orphans


def layer_of(path: pathlib.Path, docs: pathlib.Path) -> str:
    """The top-level folder under docs/ that decides a page's layer."""
    return path.relative_to(docs).parts[0]


def run(docs: pathlib.Path, today: datetime.date) -> int:
    pages, orphans = layered_pages(docs)
    if not pages and not orphans:
        # An empty tree passing is the failure mode this project refuses, so an
        # absence of pages is reported rather than silently accepted.
        print(f"M0 no documentation pages under {docs}/{{{','.join(FOLDER_LAYER)}}}")
        return 1

    findings = list(orphans)
    for page in pages:
        label = page.relative_to(docs)
        fields, problems = parse_block(page.read_text(encoding="utf-8"))
        if fields is not None:
            problems += check_fields(fields, layer_of(page, docs), today)
        findings += [f"{label}: {problem}" for problem in problems]

    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


def page_text(**overrides: str) -> str:
    fields = {
        "half_life": "practice",
        "verified_on": "2026-10-01",
        "tier": "2",
        "source": "https://docs.godotengine.org/en/stable/",
        "invalidated_if": "Godot changes how addons are discovered",
    }
    fields.update(overrides)
    block = "\n".join(f"{key}: {value}" for key, value in fields.items())
    return f"# A page\n\n<!-- doc-meta\n{block}\n-->\n\nBody.\n"


def self_test() -> int:
    failures = []
    today = datetime.date(2026, 10, 12)

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(docs: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(docs, today)

    def docs_with(root: pathlib.Path, name: str, folder: str, text: str) -> pathlib.Path:
        docs = root / name
        (docs / folder).mkdir(parents=True)
        (docs / folder / "page.md").write_text(text)
        return docs

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        expect("well-formed page", quiet(docs_with(root, "ok", "godot", page_text())), 0)

        # Planted: an empty docs tree. A gate that passes on nothing is useless.
        empty = root / "empty"
        empty.mkdir()
        expect("no pages at all", quiet(empty), 1)

        # Planted: no metadata block.
        expect("missing block",
               quiet(docs_with(root, "noblock", "godot", "# A page\n\nBody.\n")), 1)

        # Planted: a tool-layer page sitting in the practice folder.
        expect("layer/folder mismatch",
               quiet(docs_with(root, "mismatch", "godot", page_text(half_life="tool"))), 1)

        # Planted: past its half-life. 2026-04-01 + 182 days = 2026-09-30.
        expect("expired page",
               quiet(docs_with(root, "stale", "godot", page_text(verified_on="2026-04-01"))), 1)

        # The day it is due is still valid; the day after is not.
        expect("due today, still valid",
               quiet(docs_with(root, "edge-ok", "godot", page_text(verified_on="2026-04-13"))), 0)
        expect("one day past due",
               quiet(docs_with(root, "edge-bad", "godot", page_text(verified_on="2026-04-12"))), 1)

        # A concept page lasts two years, so the same date is fine there.
        expect("concept page not expired",
               quiet(docs_with(root, "concept", "concepts",
                               page_text(half_life="concept", verified_on="2025-06-01",
                                         source="book:AIMA 4th edition, chapter 3"))), 0)

        # Planted: a date that is not YYYY-MM-DD.
        expect("loose date",
               quiet(docs_with(root, "baddate", "godot", page_text(verified_on="12/10/2026"))), 1)

        # Planted: a date in the future.
        expect("future date",
               quiet(docs_with(root, "future", "godot", page_text(verified_on="2027-01-01"))), 1)

        # Planted: an invalidated_if too short to say anything.
        expect("thin invalidated_if",
               quiet(docs_with(root, "thin", "godot", page_text(invalidated_if="it changes"))), 1)

        # Planted: a source that is neither a URL nor a book.
        expect("bad source",
               quiet(docs_with(root, "badsource", "godot", page_text(source="someone told me"))), 1)

        # Planted: a tier outside 0-3.
        expect("bad tier", quiet(docs_with(root, "badtier", "godot", page_text(tier="9"))), 1)

        # Planted: a page one directory deeper. `.glob` never saw it.
        nested = root / "nested"
        (nested / "godot" / "deep").mkdir(parents=True)
        (nested / "godot" / "deep" / "page.md").write_text("# No metadata\n")
        expect("page in a nested folder", quiet(nested), 1)

        # Planted: a page in a folder nobody declared a layer for.
        unknown = docs_with(root, "unknown", "godot", page_text())
        (unknown / "tutorials").mkdir()
        (unknown / "tutorials" / "intro.md").write_text("# No metadata\n")
        expect("page in an undeclared folder", quiet(unknown), 1)

        # A dated record is exempt and must not be a finding.
        records = docs_with(root, "records", "godot", page_text())
        (records / "adr").mkdir()
        (records / "adr" / "0001-a.md").write_text("# 0001 - A decision\n")
        expect("ADR without doc-meta", quiet(records), 0)

        # Planted: two doc-meta blocks, the second expired. Only the first was
        # ever read.
        doubled = page_text() + "\n<!-- doc-meta\nhalf_life: tool\n" \
            "verified_on: 2020-01-01\ntier: 2\nsource: https://x.example/\n" \
            "invalidated_if: this never stops being wrong\n-->\n"
        expect("two doc-meta blocks", quiet(docs_with(root, "doubled", "godot", doubled)), 1)

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
    parser.add_argument("--docs", default=None)
    parser.add_argument("--today", default=None)
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

    docs = pathlib.Path(args.docs or pathlib.Path(__file__).resolve().parent.parent / "docs")
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.date.today()
    except ValueError:
        print(f"check_doc_freshness: --today must be YYYY-MM-DD", file=sys.stderr)
        return 2

    try:
        return run(docs, today)
    except OSError as error:
        print(f"check_doc_freshness: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
