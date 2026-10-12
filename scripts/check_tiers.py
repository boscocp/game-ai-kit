#!/usr/bin/env python3
"""Keep every lesson reachable by someone with a modest machine.

The rule
--------
Invariant 5: no lesson lives only above tier 1. The tiers are in the README --
0 is reading, 1 is Python and nothing else, 2 is Godot, 3 is a GPU. A technique
explained only on a page that needs a graphics card is a technique this project
does not actually teach to the people it claims to.

How a page says what it teaches
-------------------------------
Its `doc-meta` block carries a `teaches:` field: a short topic slug, or the
literal `none` for a page that is reference rather than a lesson. The field is
required on every page above tier 1, because that is where the promise can be
broken, and `none` has to be written out -- a page that forgets the field is a
finding, not an exemption.

The check is then one sentence: every topic taught at tier 2 or 3 is also
taught by some page at tier 0 or 1.

Exit codes
----------
0   every taught topic is reachable at tier 1 or below
1   a topic only exists above tier 1, or a page is missing `teaches:`
2   wrong usage, or a file that cannot be read

Usage
-----
    check_tiers.py [--docs PATH]
    check_tiers.py --self-test
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

BLOCK_RE = re.compile(r"<!--\s*doc-meta\s*\n(.*?)-->", re.S)
FIELD_RE = re.compile(r"^\s*([a-z_]+)\s*:\s*(.*?)\s*$")

# Above this, a lesson needs hardware the reader may not have.
REACHABLE_TIER = 1

NOT_A_LESSON = "none"


def pages_with_meta(docs: pathlib.Path) -> list[tuple[pathlib.Path, dict[str, str]]]:
    """Every markdown page under docs/ that carries a doc-meta block."""
    found = []
    for path in sorted(docs.rglob("*.md")):
        block = BLOCK_RE.search(path.read_text(encoding="utf-8"))
        if block is None:
            continue
        fields = {}
        for line in block.group(1).splitlines():
            field = FIELD_RE.match(line)
            if field:
                fields[field.group(1)] = field.group(2)
        found.append((path, fields))
    return found


def check(docs: pathlib.Path) -> list[str]:
    """Report topics taught only above tier 1, and pages that do not say."""
    pages = pages_with_meta(docs)
    if not pages:
        print(f"T0 note: no pages with a doc-meta block under {docs} -- nothing to check")
        return []

    findings = []
    reachable: set[str] = set()
    high: dict[str, pathlib.Path] = {}

    for path, fields in pages:
        label = path.relative_to(docs)
        raw_tier = fields.get("tier", "")
        if not raw_tier.isdigit():
            findings.append(f"T1 {label}: tier {raw_tier!r} is not a number")
            continue
        tier = int(raw_tier)

        teaches = fields.get("teaches")
        if tier > REACHABLE_TIER and teaches is None:
            findings.append(
                f"T2 {label}: tier {tier} and no `teaches:` -- name the topic, "
                f"or write `teaches: {NOT_A_LESSON}` if the page is reference"
            )
            continue
        if teaches in (None, NOT_A_LESSON):
            continue

        if tier <= REACHABLE_TIER:
            reachable.add(teaches)
        else:
            high.setdefault(teaches, path)

    for topic, path in sorted(high.items()):
        if topic not in reachable:
            findings.append(
                f"T3 {path.relative_to(docs)} teaches {topic!r} at a tier above "
                f"{REACHABLE_TIER}, and no page teaches it at or below"
            )
    return findings


def run(docs: pathlib.Path) -> int:
    findings = check(docs)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


def page(tier: int, teaches: str | None) -> str:
    lines = [
        "half_life: practice",
        "verified_on: 2026-10-12",
        f"tier: {tier}",
        "source: https://example.org/",
        "invalidated_if: the engine changes how this works",
    ]
    if teaches is not None:
        lines.append(f"teaches: {teaches}")
    return "# A page\n\n<!-- doc-meta\n" + "\n".join(lines) + "\n-->\n\nBody.\n"


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(docs: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(docs)

    def build(root: pathlib.Path, name: str, files: dict[str, str]) -> pathlib.Path:
        docs = root / name
        for relative, text in files.items():
            path = docs / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return docs

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        # The shape the project promises: the engine page has a concept page
        # behind it, so the lesson survives without Godot.
        expect("taught at tier 0 as well", quiet(build(root, "good", {
            "concepts/astar.md": page(0, "astar"),
            "godot/astar-in-godot.md": page(2, "astar"),
        })), 0)

        # Planted: the lesson exists only where a graphics card is needed.
        expect("only above tier 1", quiet(build(root, "high", {
            "godot/astar-in-godot.md": page(2, "astar"),
        })), 1)

        # Planted: a tier-3 page with no tier-1 counterpart.
        expect("tier 3 only", quiet(build(root, "gpu", {
            "concepts/astar.md": page(0, "astar"),
            "local-llm/orders.md": page(3, "llm-orders"),
        })), 1)

        # Planted: a page above tier 1 that does not say what it teaches.
        expect("missing teaches", quiet(build(root, "silent", {
            "godot/something.md": page(2, None),
        })), 1)

        # A reference page says so, and is not a lesson owing a counterpart.
        expect("reference page", quiet(build(root, "reference", {
            "godot/addon-anatomy.md": page(2, NOT_A_LESSON),
        })), 0)

        # Tier 1 teaching a topic nothing else covers is fine: it is reachable.
        expect("taught only at tier 1", quiet(build(root, "lowonly", {
            "concepts/regression.md": page(1, "regression"),
        })), 0)

        # Planted: a tier that is not a number.
        expect("non-numeric tier", quiet(build(root, "badtier", {
            "godot/x.md": page(0, "astar").replace("tier: 0", "tier: high"),
        })), 1)

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
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(__file__).resolve().parent.parent
    docs = pathlib.Path(args.docs) if args.docs else repo / "docs"

    try:
        return run(docs)
    except OSError as error:
        print(f"check_tiers: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
