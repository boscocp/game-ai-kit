#!/usr/bin/env python3
"""Keep the technique pages written, translated, and in step with each other.

What it holds
-------------
T74. Every technique in the kit has one short page in English,
`docs/techniques/<name>.md`, and its Brazilian Portuguese translation beside
it, `docs/techniques/<name>.pt-BR.md`. A translation is written once and then
forgotten, which is how it drifts: the English page gains a section, a knob is
renamed, and the Portuguese reader is told the old thing with full confidence.
This gate is what notices.

Which pages must exist: one per module of kind `technique` in
`modules/*.json`, the techniques that live in Python and a demo only
(`docs/techniques/non_module_techniques.json`), and `ai_core`, the kernel
every addon stands on. `board` is the examples' own kernel and has none
(ADR 0021). A page may be named in `STILL_TO_WRITE` below instead of
written -- T74 used it for the pages T75 then wrote, and T75 emptied it --
and a page named there that exists is a finding too, so the list can only
shrink.

How the two languages are compared
----------------------------------
Prose cannot be compared across languages, so three things that can be are:

  * the translation's doc-meta carries `translation_of: <sha256>` of the
    English page with its doc-meta block removed. Change the English page and
    the translation is stale until someone reads the change and updates it;
  * every heading below the title carries an explicit anchor, the same in
    both languages -- `## Quando não usar {#when-not}` -- and the sequence of
    (level, anchor) must match;
  * fenced code blocks are not translated (their comments are English, once),
    so they must match byte for byte, in order.

Every translation also opens the same way, before its first section: a
quoted line linking its English page and the glossary of the English words a
Brazilian developer keeps -- the same words on every page, so a reader who
meets *steering* on any of them knows where it is explained (the owner,
2026-10-26: what has no good translation stays in English, in a glossary).

And the page's minimal example is run, not only read: a block marked
`<!-- example: godot/test/<addon>/<file>.gd -->` must equal that file, which
a gdUnit suite beside it loads into an empty scene.

The rules, one finding each
---------------------------
  D1  no technique could be found in modules/ -- a gate that checks nothing
  D2  a technique with no English page, and not in STILL_TO_WRITE
  D3  an English page with no pt-BR page
  D4  a pt-BR page with no English page
  D5  a translation whose translation_of is missing or stale
  D6  the headings' (level, anchor) sequences differ
  D7  a heading below the title with no {#anchor}
  D8  the code blocks differ
  D9  an example block that differs from its file, or names no file
  D10 a technique page missing a section of the shape, or with no example
  D11 STILL_TO_WRITE names a page that exists, or no technique at all
  D12 a page in docs/techniques/ that no technique or rule accounts for
  D13 a non-module technique naming a path that does not exist
  D14 a translation that does not open, before its first section, with the
      line linking its English page and the glossary

Exit codes
----------
0   every page present, paired and in step
1   a finding
2   wrong usage, or a manifest or page that cannot be read

Usage
-----
    check_translations_docs.py [--root PATH]
    check_translations_docs.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import pathlib
import re
import subprocess
import sys
import tempfile

PAGES = pathlib.Path("docs/techniques")
NON_MODULE = PAGES / "non_module_techniques.json"
TRANSLATION_SUFFIX = ".pt-BR.md"

# Pages that are not a technique and still belong in the folder: the
# glossary is Portuguese only, being a list of the English words a Brazilian
# developer keeps (step 3).
GLOSSARY = "glossary.pt-BR.md"
OTHER_PAGES = {GLOSSARY}

# The kernels that get a page although they are not a technique: ai_core is
# the grid and the pathfinder port every addon stands on. `board` is not here
# on purpose -- it is the examples' kernel, not something a reader copies.
KERNEL_PAGES = ("ai_core",)

# Pages declared rather than missing. Empty since T75 wrote the last of
# them: from here a technique without a page in both languages is a finding.
# A new technique module may be named here for the wave that writes its
# page, and taken off the day it lands -- the gate says so if you forget.
STILL_TO_WRITE: tuple[str, ...] = ()

# The sections every technique page has, by anchor, in this order (step 2).
SHAPE = ("what", "when-not", "watch", "in-this-kit", "your-project", "deeper")

META_RE = re.compile(r"<!--\s*doc-meta\s*\n(.*?)-->\n?", re.S)
TRANSLATION_OF_RE = re.compile(r"^\s*translation_of\s*:\s*(\S*)\s*$", re.M)
FENCE_RE = re.compile(r"^(```|~~~)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
ANCHOR_RE = re.compile(r"\{#([a-z0-9-]+)\}$")
EXAMPLE_RE = re.compile(r"^<!--\s*example:\s*(\S+)\s*-->$")


class Unreadable(Exception):
    """A manifest or a page that cannot be read: exit 2, not a finding."""


# --- what must exist ---------------------------------------------------------


def technique_modules(root: pathlib.Path) -> list[str]:
    """The names of every module of kind `technique`, from its manifest."""
    names = []
    for manifest in sorted((root / "modules").glob("*.json")):
        try:
            module = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            raise Unreadable(f"{manifest}: {error}") from error
        if module.get("kind") == "technique":
            names.append(module["module"])
    return names


def non_module_techniques(root: pathlib.Path) -> list[dict]:
    """The techniques that live in Python and a demo only, as declared."""
    path = root / NON_MODULE
    if not path.exists():
        return []
    try:
        return json.loads(path.read_text(encoding="utf-8"))["techniques"]
    except (OSError, ValueError, KeyError) as error:
        raise Unreadable(f"{path}: {error}") from error


def missing_paths(root: pathlib.Path, techniques: list[dict]) -> list[str]:
    """D13: a declared technique pointing at something that is not there."""
    findings = []
    for technique in techniques:
        for path in [*technique.get("lives_in", []), technique.get("concept", "")]:
            if path and not (root / path).exists():
                findings.append(f"{NON_MODULE}: D13 {technique['page']} names {path}, which does not exist")
    return findings


# --- reading one page --------------------------------------------------------


def normalised(text: str) -> str:
    """The text with Windows line endings made Unix ones.

    The owner plays these on a Windows desk, where a checkout may carry CRLF,
    and a hash that changed with the line endings would call every
    translation stale. `read_text` already reads CRLF and a lone CR as `\n`
    (universal newlines), so for a file this changes nothing; it is here for
    text that did not come through it, and so the rule is written down once.
    """
    return text.replace("\r\n", "\n")


def body_hash(english: str) -> str:
    """sha256 of the English page with its doc-meta block taken out.

    The block is left out because `verified_on` moves when someone rechecks
    the sources, and that does not make the translation wrong. So are the
    trailing newlines: an editor adding or dropping one at the end of the
    file has changed nothing a reader sees.
    """
    body = META_RE.sub("", normalised(english), count=1).rstrip("\n") + "\n"
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def outside_fences(text: str) -> list[tuple[int, str]]:
    """(line number, line) for every line not inside a fenced code block."""
    found, opener = [], None
    for number, line in enumerate(text.splitlines(), start=1):
        fence = FENCE_RE.match(line)
        if fence and opener is None:
            opener = fence.group(1)
            continue
        if fence and fence.group(1) == opener:
            opener = None
            continue
        if opener is None:
            found.append((number, line))
    return found


def headings(text: str) -> list[tuple[int, int, str | None]]:
    """(line, level, anchor or None) for every heading outside code."""
    found = []
    for number, line in outside_fences(text):
        match = HEADING_RE.match(line)
        if match is None:
            continue
        anchor = ANCHOR_RE.search(match.group(2))
        found.append((number, len(match.group(1)), anchor.group(1) if anchor else None))
    return found


def code_blocks(text: str) -> list[tuple[str | None, str, str]]:
    """(example file or None, opening fence line, contents) per fenced block.

    The example file is the one named by an `<!-- example: … -->` line
    directly above the fence. The opening line is kept because it carries
    the language (```gdscript is not ```gd), and a block opened with ```
    closes only on ``` -- a ~~~ inside it is code, not the end.
    """
    blocks, lines, index = [], text.splitlines(), 0
    while index < len(lines):
        fence = FENCE_RE.match(lines[index])
        if fence is None:
            index += 1
            continue
        marker = EXAMPLE_RE.match(lines[index - 1]) if index > 0 else None
        end = index + 1
        while end < len(lines) and not lines[end].startswith(fence.group(1)):
            end += 1
        contents = "".join(line + "\n" for line in lines[index + 1:end])
        blocks.append((marker.group(1) if marker else None, lines[index], contents))
        index = end + 1
    return blocks


# --- the checks on one pair --------------------------------------------------


def glossary_note(name: str) -> str:
    """The line every translation opens with, for the page called `name`."""
    return (f"English: [{name}.md]({name}.md). Os termos que ficam em inglês "
            f"estão no [glossário]({GLOSSARY}).")


def opening_quote(text: str) -> str:
    """The first quoted block above the first section, its lines joined.

    The doc-meta block is left out, and so is anything from the first `##`
    heading on: a note further down is not where a reader looks first.
    """
    quoted: list[str] = []
    for _, line in outside_fences(META_RE.sub("", text, count=1)):
        if line.startswith("## "):
            break
        if line.startswith(">"):
            quoted.append(line[1:].strip())
        elif quoted:
            break
    return " ".join(part for part in quoted if part)


def glossary_findings(label: str, name: str, text: str) -> list[str]:
    """D14: a translation that does not open with the glossary line."""
    if opening_quote(text) == glossary_note(name):
        return []
    return [f"{label}: D14 it must open, before its first section, with the quoted line "
            f"\"{glossary_note(name)}\""]


def anchor_findings(label: str, text: str) -> list[str]:
    """D7: a heading below the title with no explicit anchor."""
    return [
        f"{label}:{line}: D7 a heading with no {{#anchor}}; translated headings are matched by it"
        for line, level, anchor in headings(text) if level > 1 and anchor is None
    ]


def example_findings(root: pathlib.Path, label: str, text: str) -> list[str]:
    """D9: an example block that is not exactly the file it names."""
    findings = []
    for example, _, contents in code_blocks(text):
        if example is None:
            continue
        path = root / example
        if not path.is_file():
            findings.append(f"{label}: D9 the example names {example}, which is not a file")
        elif normalised(path.read_text(encoding="utf-8")) != contents:
            findings.append(f"{label}: D9 the example block differs from {example}; paste the file again")
    return findings


def shape_findings(label: str, text: str) -> list[str]:
    """D10: a technique page without the shape every one shares."""
    anchors = [anchor for _, level, anchor in headings(text) if level == 2]
    findings = []
    if [anchor for anchor in anchors if anchor in SHAPE] != list(SHAPE):
        findings.append(f"{label}: D10 the ## sections must include {', '.join(SHAPE)}, in that order")
    if not any(example for example, _, _ in code_blocks(text)):
        findings.append(f"{label}: D10 no <!-- example: … --> block; the minimal example is run, not only read")
    return findings


def heading_shape(text: str) -> list[tuple[int, str | None]]:
    """The headings as (level, anchor): what two languages can share."""
    return [(level, anchor) for _, level, anchor in headings(text)]


def pair_findings(english_path: pathlib.Path, translated_path: pathlib.Path) -> list[str]:
    """D5, D6, D8: the translation against its English page."""
    english = normalised(english_path.read_text(encoding="utf-8"))
    translated = normalised(translated_path.read_text(encoding="utf-8"))
    names = f"{translated_path.name} (translating {english_path.name})"
    findings = []
    meta = META_RE.search(translated)
    claimed = TRANSLATION_OF_RE.search(meta.group(1)) if meta else None
    if claimed is None or not claimed.group(1):
        findings.append(f"{names}: D5 no translation_of in its doc-meta; it should be {body_hash(english)}")
    elif claimed.group(1) != body_hash(english):
        findings.append(
            f"{names}: D5 stale -- the English page changed since this was translated; "
            f"read the change, update the translation, then set translation_of: {body_hash(english)}"
        )
    if heading_shape(english) != heading_shape(translated):
        findings.append(f"{names}: D6 the headings' levels or anchors differ from the English page's")
    if [block[1:] for block in code_blocks(english)] != [block[1:] for block in code_blocks(translated)]:
        findings.append(f"{names}: D8 the code blocks differ; code is not translated")
    return findings


# --- the whole folder --------------------------------------------------------


def expected_pages(root: pathlib.Path) -> tuple[list[str], list[str]]:
    """(technique pages, kernel pages) that must exist, by name."""
    techniques = technique_modules(root)
    techniques += [technique["page"] for technique in non_module_techniques(root)]
    return techniques, list(KERNEL_PAGES)


def presence_findings(root: pathlib.Path, techniques: list[str], to_write: tuple[str, ...]) -> list[str]:
    """D2, D3, D4, D11, D12: which pages exist against which should."""
    folder = root / PAGES
    findings = []
    for name in to_write:
        if name not in techniques:
            findings.append(f"STILL_TO_WRITE: D11 {name} is not a technique; take it off the list")
        elif (folder / f"{name}.md").exists():
            findings.append(f"STILL_TO_WRITE: D11 {name} has its page now; take it off the list")
    for name in [*techniques, *KERNEL_PAGES]:
        if name not in to_write and not (folder / f"{name}.md").exists():
            findings.append(f"{PAGES}/{name}.md: D2 the technique {name} has no page")
    known = set(techniques) | set(KERNEL_PAGES)
    for page in sorted(folder.glob("*.md")) if folder.is_dir() else []:
        findings += page_presence(page, known)
    return findings


def page_presence(page: pathlib.Path, known: set[str]) -> list[str]:
    """D3, D4, D12 for one file in the folder."""
    if page.name in OTHER_PAGES:
        return []
    label = f"{PAGES}/{page.name}"
    if page.name.endswith(TRANSLATION_SUFFIX):
        name = page.name[: -len(TRANSLATION_SUFFIX)]
        if not page.with_name(f"{name}.md").exists():
            return [f"{label}: D4 a translation with no English page beside it"]
        return []
    name = page.stem
    findings = []
    if name not in known:
        findings.append(f"{label}: D12 no technique is called {name}; add it to OTHER_PAGES with a reason")
    if not page.with_name(f"{name}{TRANSLATION_SUFFIX}").exists():
        findings.append(f"{label}: D3 no {name}{TRANSLATION_SUFFIX} beside it")
    return findings


def content_findings(root: pathlib.Path, techniques: list[str]) -> list[str]:
    """D5 to D10 over every English page that exists, and its translation."""
    folder = root / PAGES
    findings = []
    for english in sorted(folder.glob("*.md")) if folder.is_dir() else []:
        if english.name.endswith(TRANSLATION_SUFFIX) or english.name in OTHER_PAGES:
            continue
        translated = english.with_name(f"{english.stem}{TRANSLATION_SUFFIX}")
        for page in (english, translated) if translated.exists() else (english,):
            text = normalised(page.read_text(encoding="utf-8"))
            label = f"{PAGES}/{page.name}"
            findings += anchor_findings(label, text) + example_findings(root, label, text)
        if english.stem in techniques:
            findings += shape_findings(f"{PAGES}/{english.name}", english.read_text(encoding="utf-8"))
        if translated.exists():
            findings += pair_findings(english, translated)
            findings += glossary_findings(f"{PAGES}/{translated.name}", english.stem,
                                          normalised(translated.read_text(encoding="utf-8")))
    return findings


def check(root: pathlib.Path, to_write: tuple[str, ...] = STILL_TO_WRITE) -> list[str]:
    """Every finding over the repository at `root`, in the order a reader fixes them.

    `to_write` is a parameter rather than the constant read directly, so the
    self-test can plant a list without editing this file.
    """
    techniques, _ = expected_pages(root)
    if not technique_modules(root):
        return [f"D1 no module of kind technique under {root / 'modules'}; nothing to check"]
    findings = missing_paths(root, non_module_techniques(root))
    findings += presence_findings(root, techniques, to_write)
    findings += content_findings(root, techniques)
    return findings


def run(root: pathlib.Path, to_write: tuple[str, ...] = STILL_TO_WRITE) -> int:
    """Print the findings and return the exit code: 0 clean, 1 findings, 2 unreadable.

    An unreadable manifest or page is 2, not 1, because it is the check that
    failed, not the pages -- the distinction CLAUDE.md asks of every gate.
    """
    try:
        findings = check(root, to_write)
    except (Unreadable, OSError, UnicodeDecodeError) as error:
        print(f"check_translations_docs: cannot read: {error}", file=sys.stderr)
        return 2
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


EXAMPLE_FILE = "godot/test/ai_x/example.gd"
EXAMPLE_TEXT = "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"decided\")\n"

ENGLISH = f"""# ai_x

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
-->

## What it decides {{#what}}

It decides.

## When not to use it {{#when-not}}

Rarely.

## Where to watch it {{#watch}}

`make demo-x`.

## In this kit {{#in-this-kit}}

A table.

## In your own project {{#your-project}}

<!-- example: {EXAMPLE_FILE} -->
```gdscript
{EXAMPLE_TEXT}```

## Deeper {{#deeper}}

Links.
"""


def translation_of(english: str, claimed: str | None = None) -> str:
    """A faithful pt-BR page for `english`: every heading and block kept."""
    digest = claimed if claimed is not None else body_hash(english)
    text = english.replace("verified_on: 2026-10-26", f"verified_on: 2026-10-26\ntranslation_of: {digest}")
    text = text.replace("-->\n", f"-->\n\n> {glossary_note('ai_x')}\n", 1)
    for before, after in (("It decides.", "Decide."), ("Rarely.", "Raramente."),
                          ("What it decides", "O que decide"), ("Deeper", "Mais fundo")):
        text = text.replace(before, after)
    return text


def build(root: pathlib.Path, name: str, pages: dict[str, str], example: str = EXAMPLE_TEXT) -> pathlib.Path:
    """A tiny repository: one technique module, ai_core, and these pages."""
    repo = root / name
    (repo / "modules").mkdir(parents=True)
    (repo / PAGES).mkdir(parents=True)
    for module, kind in (("ai_x", "technique"), ("ai_core", "kernel")):
        (repo / "modules" / f"{module}.json").write_text(json.dumps({"module": module, "kind": kind}))
    (repo / EXAMPLE_FILE).parent.mkdir(parents=True)
    (repo / EXAMPLE_FILE).write_text(example)
    for page, text in pages.items():
        (repo / PAGES / page).write_text(text)
    return repo


def good_pages(english: str = ENGLISH) -> dict[str, str]:
    """A folder the gate must pass: the technique pair and ai_core's pair.

    Every planted case is one change to this, so a case that fails names
    exactly the drift it planted.
    """
    kernel = "# ai_core\n\n## The grid {#grid}\n\nCells.\n"
    kernel_pt = ("# ai_core\n\n<!-- doc-meta\ntranslation_of: " + body_hash(kernel) + "\n-->\n\n> "
                 + glossary_note("ai_core") + "\n\n## A grade {#grid}\n\nCélulas.\n")
    return {"ai_x.md": english, "ai_x.pt-BR.md": translation_of(english),
            "ai_core.md": kernel, "ai_core.pt-BR.md": kernel_pt}


def without(pages: dict[str, str], name: str) -> dict[str, str]:
    """The same pages, one left out."""
    return {page: text for page, text in pages.items() if page != name}


def self_test_cases(root: pathlib.Path) -> list[tuple[str, pathlib.Path, int, str]]:
    """(label, repository, expected exit, finding it must print) per case."""
    pages = good_pages()
    stale = dict(pages, **{"ai_x.pt-BR.md": translation_of(ENGLISH, "0" * 64)})
    moved = dict(pages, **{"ai_x.pt-BR.md": pages["ai_x.pt-BR.md"].replace("## Mais fundo", "### Mais fundo")})
    renamed = dict(pages, **{"ai_x.pt-BR.md": pages["ai_x.pt-BR.md"].replace("{#deeper}", "{#mais}")})
    edited = ENGLISH + "\n```\nprint(1)\n```\n"
    code = dict(good_pages(edited), **{"ai_x.pt-BR.md": translation_of(edited).replace("print(1)", "print(2)")})
    unanchored = ENGLISH.replace(" {#deeper}", "")
    return [
        ("a faithful pair", build(root, "good", pages), 0, ""),
        ("no modules at all", root / "empty", 1, "D1"),
        ("a technique with no English page", build(root, "no-english", without(pages, "ai_x.md")), 1, "D2"),
        ("an English page with no pt-BR", build(root, "no-pt", without(pages, "ai_x.pt-BR.md")), 1, "D3"),
        ("a stale translation_of", build(root, "stale", stale), 1, "D5"),
        ("a heading level that differs", build(root, "level", moved), 1, "D6"),
        ("an anchor that differs", build(root, "anchor", renamed), 1, "D6"),
        ("a code block that differs", build(root, "code", code), 1, "D8"),
        ("an example that differs from its file",
         build(root, "example", pages, example=EXAMPLE_TEXT.replace("decided", "changed")), 1, "D9"),
        ("a heading with no anchor", build(root, "unanchored", good_pages(unanchored)), 1, "D7"),
        ("a page outside the shape",
         build(root, "shape", good_pages(ENGLISH.replace("{#watch}", "{#look}"))), 1, "D10"),
        ("a stray page", build(root, "stray", dict(pages, **{"notes.md": "# Notes\n"})), 1, "D12"),
        *more_cases(root, pages),
    ]


def more_cases(root: pathlib.Path, pages: dict[str, str]) -> list[tuple[str, pathlib.Path, int, str]]:
    """The planted cases the review found missing: one per rule branch."""
    translated = pages["ai_x.pt-BR.md"]
    no_claim = dict(pages, **{"ai_x.pt-BR.md": "\n".join(
        line for line in translated.splitlines() if not line.startswith("translation_of:")) + "\n"})
    other_fence = dict(pages, **{"ai_x.pt-BR.md": translated.replace("```gdscript", "```gd")})
    gone = ENGLISH.replace(EXAMPLE_FILE, "godot/test/ai_x/gone.gd")
    unmarked = ENGLISH.replace(f"<!-- example: {EXAMPLE_FILE} -->\n", "")
    trailing = dict(pages, **{"ai_x.md": ENGLISH + "\n\n"})
    nowhere = build(root, "non-module", dict(pages, **{"ai_y.md": "", "ai_y.pt-BR.md": ""}))
    (nowhere / NON_MODULE).write_text(json.dumps({"techniques": [{"page": "ai_y", "lives_in": ["python/gone/"]}]}))
    return [
        ("a translation with no English page",
         build(root, "orphan", dict(pages, **{"notes.pt-BR.md": "# Notas\n"})), 1, "D4"),
        ("a translation with no translation_of", build(root, "no-claim", no_claim), 1, "D5"),
        ("a code block whose language differs", build(root, "fence", other_fence), 1, "D8"),
        ("an example naming no file", build(root, "gone", good_pages(gone)), 1, "D9"),
        ("a technique page with no example", build(root, "unmarked", good_pages(unmarked)), 1, "D10"),
        ("a non-module technique naming a missing path", nowhere, 1, "D13"),
        *glossary_cases(root, pages),
        # Not a drift: an editor adding newlines at the end changes nothing.
        ("trailing newlines added to the English page", build(root, "trailing", trailing), 0, ""),
    ]


def glossary_cases(root: pathlib.Path, pages: dict[str, str]) -> list[tuple[str, pathlib.Path, int, str]]:
    """D14's planted cases: the line missing, reworded, moved below a section."""
    translated = pages["ai_x.pt-BR.md"]
    note = f"> {glossary_note('ai_x')}\n"
    missing = dict(pages, **{"ai_x.pt-BR.md": translated.replace(note, "")})
    reworded = dict(pages, **{"ai_x.pt-BR.md": translated.replace("[glossário]", "[vocabulário]")})
    moved = dict(pages, **{"ai_x.pt-BR.md": translated.replace(note, "").replace(
        "Raramente.", "Raramente.\n\n" + note)})
    wrapped = dict(pages, **{"ai_x.pt-BR.md": translated.replace(
        "Os termos que ficam", "Os termos\n> que ficam")})
    return [
        ("a translation with no glossary line", build(root, "no-glossary", missing), 1, "D14"),
        ("a glossary line in other words", build(root, "reworded", reworded), 1, "D14"),
        ("a glossary line below the first section", build(root, "low-glossary", moved), 1, "D14"),
        # Not a drift: the same line wrapped differently reads the same.
        ("the glossary line wrapped elsewhere", build(root, "wrapped", wrapped), 0, ""),
    ]


def self_test() -> int:
    """Run every planted case; 0 when each is rejected or passed as it must be.

    Invariant 4: a gate that only knows how to go green is the most expensive
    defect, so each rule has a case it must reject.
    """
    failures = []
    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        (root / "empty" / "modules").mkdir(parents=True)
        for label, repo, want, code in self_test_cases(root):
            failures += expect_run(label, repo, want, code, ())
        # Planted: a page still declared to write after it was written, and a
        # name on the list that is no technique at all.
        failures += expect_run("a written page still on the list", root / "good", 1, "D11", ("ai_x",))
        failures += expect_run("a list naming no technique", root / "good", 1, "D11", ("ai_gone",))
        # The same page, missing and declared: allowed while it is on the list.
        repo = build(root, "declared", {key: value for key, value in good_pages().items() if "ai_x" not in key})
        failures += expect_run("a missing page on the list", repo, 0, "", ("ai_x",))
    script = pathlib.Path(__file__).resolve()
    unknown = subprocess.run([sys.executable, str(script), "--unknown-flag"], capture_output=True)
    if unknown.returncode != 2:
        failures.append(f"unknown flag: expected exit 2, got {unknown.returncode}")
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def expect_run(label: str, repo: pathlib.Path, want: int, code: str, to_write: tuple[str, ...]) -> list[str]:
    """One case: the exit code it must give, and a finding it must name."""
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        got = run(repo, to_write)
    if got != want:
        return [f"{label}: expected exit {want}, got {got}: {output.getvalue().strip()!r}"]
    if code and f"{code} " not in output.getvalue():
        return [f"{label}: expected a {code} finding, got {output.getvalue().strip()!r}"]
    return []


def main(argv: list[str]) -> int:
    """Parse the command line and run the gate or its self-test.

    `--help` keeps argparse's exit 0; any other usage error is 2, which every
    gate here returns for wrong usage.
    """
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--root", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    if args.self_test:
        return self_test()
    return run(pathlib.Path(args.root or pathlib.Path(__file__).resolve().parent.parent))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
