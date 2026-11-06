#!/usr/bin/env python3
"""Hold the glossary's rule: an English word in italics on a pt-BR page is defined.

What it holds
-------------
T119. The pt-BR pages keep in English the words a Brazilian developer says
in English (*pathfinding*, *steering*, *gate*), in italics, and
`docs/techniques/glossary.pt-BR.md` lists each one and says what it means.
That was prose: T77's review found four italic terms the glossary did not
list in 25 lines, and nothing would have caught them. This gate reads every
`*.pt-BR.md` below the root and every italic span outside code, and asks
whether the glossary defines it.

What counts as a defined term
-----------------------------
Every spelling in the first column of the glossary's table: each italic
span in that cell, and each piece of it split at `/` or `,` with the
parenthesised part dropped -- so `*ply* (*plies*)` gives two, and
`CSP (problema de satisfação de restrições)` gives `CSP`. Compared without
case, since a term opening a sentence is capitalised.

The glossary lists a term in the singular ("Um termo no plural ... está
aqui no singular"), so a span is also compared with one declared rule: a
final `s` taken off (`flow fields` -> `flow field`, `bots` -> `bot`). Only
that rule. An irregular plural is written in the glossary's row, as *plies*
is beside *ply*, rather than guessed here.

What it cannot tell, and the choice made
----------------------------------------
Whether a span is English. Italics also mark a book or game title and a
Portuguese word stressed in a sentence (*como*, *o que*), or a sentence
quoted as an example. Measured before this was written, on the pages of
2026-11-05: fourteen titles and fourteen Portuguese spans, against some
hundred and seventy defined terms. The choice is
an allowlist declared here, `TITLES` and `EMPHASIS`, not a page convention
for titles: a convention (titles in quotes, say) would rewrite pages that
follow the glossary's own sentence, "títulos ... também em itálico, ficam
como foram publicados", and would still leave emphasis to a list. Each
entry is an exact span, and an entry no page uses any more is a finding, so
the lists only shrink when a page changes. Reading them -- is each truly a
title or Portuguese emphasis? -- is the task's manual check.

Known gaps, none on a page today: HTML italics (`<em>`, `<i>`) are not
read, only Markdown's `*` and `_`. An escaped `\\*` inside a span
(*IDA\\* variant*) is read, and looked up as `*`.

The glossary page itself is not read for spans: its second column explains
a term with its expansion in italics (*Goal-Oriented Action Planning*), and
an expansion is defined by the row it sits in.

The rules, one finding each
---------------------------
  G1  no pt-BR page below the root -- a gate that checks nothing
  G2  the glossary's table has no term
  G3  an italic span the glossary does not define and no allowlist names
  G4  an allowlist entry that no page uses, or that the glossary defines

Exit codes
----------
0   every italic span defined or allowed
1   a finding
2   wrong usage, or a glossary or page that cannot be read

Usage
-----
    check_glossary.py [--root PATH]
    check_glossary.py --self-test
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

GLOSSARY = pathlib.Path("docs/techniques/glossary.pt-BR.md")
PAGE_GLOB = "*.pt-BR.md"

# Titles of books, chapters, papers, journals and games, cited in italics as
# published. Exact spans, as the pages write them.
TITLES = frozenset({
    "AI for Games",                                     # Millington's book
    "AIMA",                                             # Russell and Norvig's book, by its usual short name
    "An Introduction to Utility Theory",                # Graham's chapter in Game AI Pro
    "Artificial Intelligence for Games",                # Millington and Funge's book, the 2nd edition's title
    "Bandit Problems",                                  # AIMA's section 17.3
    "Choosing Effective Utility-Based Considerations",  # Lewis's chapter in Game AI Pro 3
    "Façade",                                           # Mateas and Stern's interactive drama
    "Game AI Pro",                                      # the book series
    "Game AI Pro 2",                                    # one volume of it
    "Game AI Pro 3",                                    # another
    "Guild Wars 2",                                     # the game
    "Human Enemy AI in The Last of Us",                 # McIntosh's chapter in Game AI Pro 2
    "Steering Behaviors for Autonomous Characters",     # Reynolds's GDC 1999 paper
    "The Computer Journal",                             # where Michie published MENACE
})

# Portuguese in italics, not English kept as a term, of three kinds: a word
# stressed (*como*, *o que*); a sentence quoted as the example of what a
# technique decides; and a Portuguese technical term in italics where its
# page defines it (*binária*, *global* and *consistente* in a CSP or a
# heuristic, *contexto* in an opponent model). A demo's title is italic as
# its pt-BR card spells it, capital included. An entry is allowed on every
# page, not only on the one it was measured on, and *global* is English
# too: a hole the size of one word, read in the task's manual check.
EMPHASIS = frozenset({
    "atacar ou recuar", "binária", "como", "consistente", "contexto",
    "Convença o guarda a abrir a porta", "escrito dentro do próprio exemplo",
    "global", "o que", "o que ela olhou", "porquê", "qual", "quanto",
    "se a distância é perto e a luz é clara, então o alarme é alarmado",
})

FENCE_RE = re.compile(r"^(```|~~~)")
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
CODE_SPAN_RE = re.compile(r"(`+).+?\1")
LINK_TARGET_RE = re.compile(r"\]\([^)]*\)")
# One `*` or `_` opening against a word and closing against one, not a `**`
# of bold and not an escaped `\*` (A\*), which may sit inside a span
# (*IDA\* variant*). A `*` may close inside a word, as CommonMark's does --
# *zergling*s is a Portuguese plural outside the asterisks -- while a `_`
# stays bounded by non-letters, as CommonMark's does too (snake_case_name).
# A span may run onto the next line, as Markdown's does inside a paragraph
# (*Game AI* at a line's end, *Pro 2* on the next), but never past a blank one.
# The `**` of bold is taken out before this runs (see `prose`), so that
# ***x*** and bold inside italics leave their italics to be read.
ITALIC_RE = re.compile(
    r"(?<![*\\\w])\*(?![*\s])((?:\\\*|[^*\n]|\n(?!\s*\n))+?)(?<![\s\\])\*(?!\*)"
    r"|(?<![_\w])_(?![_\s])((?:[^_\n]|\n(?!\s*\n))+?)(?<!\s)_(?![_\w])"
)
PARENTHESISED_RE = re.compile(r"\([^)]*\)")


class Unreadable(Exception):
    """The glossary is missing or has no table: the check failed, not the pages."""


def prose(text: str) -> str:
    """The page as a reader sees its prose, line for line.

    Code is never a term to define -- `RtsWorld` is what you type -- so
    fenced blocks and inline code are blanked, and so are HTML comments
    (the doc-meta block) and link targets, whose underscores are paths.
    Every line removed stays as an empty one, so a span's line number is
    the file's.
    """
    text = COMMENT_RE.sub(lambda match: "\n" * match.group(0).count("\n"), text)
    kept, opener = [], None
    for line in text.splitlines():
        fence = FENCE_RE.match(line)
        if fence and opener is None:
            opener = fence.group(1)
        elif fence and fence.group(1) == opener:
            opener = None
        elif opener is None:
            kept.append(LINK_TARGET_RE.sub("]", CODE_SPAN_RE.sub("", line)).replace("**", ""))
            continue
        kept.append("")
    return "\n".join(kept)


def italic_spans(text: str) -> list[tuple[int, str]]:
    """(line it opens on, span) for every italic span, its spaces made single."""
    found = []
    for match in ITALIC_RE.finditer(text):
        span = " ".join((match.group(1) or match.group(2)).replace("\\*", "*").split())
        found.append((text.count("\n", 0, match.start()) + 1, span))
    return found


def first_cell_terms(cell: str) -> set[str]:
    """Every spelling a glossary row's first cell defines, casefolded."""
    terms = {span for _, span in italic_spans(cell)}
    plain = PARENTHESISED_RE.sub("", cell).replace("\\*", "*").replace("*", "")
    terms.update(re.split(r"[/,]", plain))
    return {term.strip().casefold() for term in terms if term.strip()}


def glossary_terms(text: str) -> set[str]:
    """The terms the glossary's table defines: every row's first cell.

    A table row is a line opening with `|`; the header and its `|---|`
    separator are skipped by being the first two such lines.
    """
    rows = [line for line in prose(text).splitlines() if line.startswith("|")]
    terms: set[str] = set()
    for row in rows[2:]:
        cells = row.split("|")
        if len(cells) > 2:
            terms |= first_cell_terms(cells[1])
    return terms


def singular(span: str) -> str:
    """The one declared plural rule: a final `s` taken off."""
    return span[:-1] if span.endswith("s") and len(span) > 2 else span


def is_defined(span: str, terms: set[str]) -> bool:
    """Whether the glossary defines this span, as written or in the singular."""
    key = span.casefold()
    return key in terms or singular(key) in terms


def pages(root: pathlib.Path) -> list[pathlib.Path]:
    """Every pt-BR page below the root but the glossary, skipping dot folders.

    A dot folder is `.git`, a worktree under `.claude/` or the checkout's
    `.user-data/` -- never a page this repository publishes.
    """
    found = []
    for path in sorted(root.rglob(PAGE_GLOB)):
        relative = path.relative_to(root)
        if any(part.startswith(".") for part in relative.parts[:-1]):
            continue
        if relative != GLOSSARY:
            found.append(path)
    return found


def page_findings(root: pathlib.Path, page: pathlib.Path, terms: set[str],
                  allowed: frozenset[str], used: set[str]) -> list[str]:
    """G3 for one page; every allowed span it uses is added to `used`."""
    findings = []
    label = page.relative_to(root)
    for number, span in italic_spans(prose(page.read_text(encoding="utf-8"))):
        if span in allowed:
            used.add(span)
        elif not is_defined(span, terms):
            findings.append(f"G3 {label}:{number}: *{span}* is in italics and the glossary does not define it")
    return findings


def allowlist_findings(allowed: frozenset[str], used: set[str], terms: set[str]) -> list[str]:
    """G4: an entry no page uses, or one the glossary now defines."""
    findings = []
    for span in sorted(allowed):
        if is_defined(span, terms):
            findings.append(f"G4 allowlist entry {span!r} is defined in the glossary; take it off the list")
        elif span not in used:
            findings.append(f"G4 allowlist entry {span!r} is used by no page; take it off the list")
    return findings


def check(root: pathlib.Path, allowed: frozenset[str] = TITLES | EMPHASIS) -> list[str]:
    """Every finding over the pages below `root`.

    `allowed` is a parameter so the self-test can plant its own lists
    without the real ones turning stale in a planted repository.
    """
    glossary = root / GLOSSARY
    if not glossary.is_file():
        raise Unreadable(f"no glossary at {glossary}")
    terms = glossary_terms(glossary.read_text(encoding="utf-8"))
    found = pages(root)
    if not found:
        return [f"G1 no {PAGE_GLOB} page below {root}; nothing to check"]
    if not terms:
        return [f"G2 {GLOSSARY} has a table with no term in it"]
    findings, used = [], set()
    for page in found:
        findings += page_findings(root, page, terms, allowed, used)
    return findings + allowlist_findings(allowed, used, terms)


def run(root: pathlib.Path, allowed: frozenset[str] = TITLES | EMPHASIS) -> int:
    """Print the findings and return the exit code: 0 clean, 1 findings, 2 unreadable."""
    try:
        findings = check(root, allowed)
    except (Unreadable, OSError, UnicodeDecodeError) as error:
        print(f"check_glossary: cannot read: {error}", file=sys.stderr)
        return 2
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


GOOD_GLOSSARY = """# Glossário

<!-- doc-meta
teaches: none
-->

Um termo no plural está aqui no singular: *ignored here*.

| termo | o que é |
|---|---|
| *pathfinding* | achar um caminho |
| *ply* (*plies*) | a jogada de um jogador |
| CSP (problema de satisfação) | um problema, *expanded here* |
| *seek*, *arrive* / *flow field* | comportamentos |
| PID, LQR | dois controladores |
"""

GOOD_PAGE = """# ai_x

<!-- doc-meta
source: *Not A Term* in a comment
-->

O *pathfinding* acha, e *Pathfinding* abre a frase. Duas *plies*, *CSP*, *flow
fields*, *seek*, **negrito**, A\\* e o *Livro*, *como* ênfase, e o *LQR*.
`*code_span*` e [um link](docs/_steering_.md) e `x_y_z`.

```gdscript
var name := "*undefined_in_code*"
```
"""

GOOD_ALLOWED = frozenset({"Livro", "como"})


def build(root: pathlib.Path, name: str, glossary: str | None, page_texts: dict[str, str]) -> pathlib.Path:
    """A planted repository: the glossary (if any) and pages at their paths."""
    repo = root / name
    (repo / GLOSSARY.parent).mkdir(parents=True)
    if glossary is not None:
        (repo / GLOSSARY).write_text(glossary, encoding="utf-8")
    for path, text in page_texts.items():
        (repo / path).parent.mkdir(parents=True, exist_ok=True)
        (repo / path).write_text(text, encoding="utf-8")
    return repo


def with_page(text: str) -> dict[str, str]:
    """The good pages with one more line of prose in the technique page."""
    return {"docs/techniques/ai_x.pt-BR.md": GOOD_PAGE + text, "README.pt-BR.md": "# Leia\n\n*seek*\n"}


# Lines that must each give a G3, appended one at a time to the good page.
UNDEFINED_LINES = {
    "an undefined English term": "O *steering*.",
    "the plural of an undefined term": "Os *bots*.",
    "a term running onto the next line": "O *steering\nbehaviour*.",
    "an underscore italic": "O _steering_.",
    "a Portuguese plural outside the asterisks": "Dois *zergling*s.",
    "a defined term with a final d, not s": "O *arrived*.",
    "a defined term with two final s": "Os *seekss*.",
    "bold and italic at once": "O ***steering***.",
    "an escaped star inside a span": "Um *IDA\\* variant* aqui.",
}


def self_test_cases(root: pathlib.Path) -> list[tuple[str, pathlib.Path, int, str]]:
    """(label, planted repository, exit code it must give, finding it must name)."""
    cases = [("the good pages", build(root, "good", GOOD_GLOSSARY, with_page("")), 0, "")]
    for number, (label, line) in enumerate(UNDEFINED_LINES.items()):
        cases.append((label, build(root, f"undefined-{number}", GOOD_GLOSSARY, with_page(f"\n{line}\n")), 1, "G3"))
    return cases + [
        ("a term in the README", build(root, "readme", GOOD_GLOSSARY,
                                       {**with_page(""), "README.pt-BR.md": "# Leia\n\n*gate*\n"}), 1, "G3"),
        ("a code span is not prose", build(root, "code", GOOD_GLOSSARY, with_page("\n`*steering*`\n")), 0, ""),
        ("no page at all", build(root, "empty", GOOD_GLOSSARY, {}), 1, "G1"),
        ("a glossary with no row", build(root, "no-rows", "# Glossário\n\n| termo | o que é |\n|---|---|\n",
                                         with_page("")), 1, "G2"),
        ("no glossary", build(root, "no-glossary", None, with_page("")), 2, ""),
        ("a page in a dot folder is not read", build(root, "dot", GOOD_GLOSSARY,
                                                     {**with_page(""), ".claude/x.pt-BR.md": "*steering*\n"}), 0, ""),
    ]


def self_test() -> int:
    """Run every planted case; 0 when each is rejected or passed as it must be.

    Invariant 4: a gate that only knows how to go green is the most
    expensive defect, so each rule has a case it must reject, and the empty
    page set is one of them.
    """
    failures = []
    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        for label, repo, want, code in self_test_cases(root):
            failures += expect_run(label, repo, want, code, GOOD_ALLOWED)
        good = root / "good"
        failures += expect_run("an allowlist entry no page uses", good, 1, "G4", GOOD_ALLOWED | {"Gone"})
        failures += expect_run("an allowlist entry the glossary defines", good, 1, "G4", GOOD_ALLOWED | {"seek"})
        failures += expect_run("a title without its allowlist entry", good, 1, "G3", frozenset({"como"}))
    script = pathlib.Path(__file__).resolve()
    unknown = subprocess.run([sys.executable, str(script), "--unknown-flag"], capture_output=True)
    if unknown.returncode != 2:
        failures.append(f"unknown flag: expected exit 2, got {unknown.returncode}")
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def expect_run(label: str, repo: pathlib.Path, want: int, code: str, allowed: frozenset[str]) -> list[str]:
    """One case: the exit code it must give, and a finding it must name."""
    output = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
        got = run(repo, allowed)
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
