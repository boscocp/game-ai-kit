# Review: wave/139, T119 -- a gate for the pt-BR glossary

T119: the glossary's rule says that an English term in italics on a pt-BR
page is in the glossary. Until now that was prose. The PR adds
`scripts/check_glossary.py` (rules G1-G4, exits 0/1/2, `--self-test`),
`make lint-glossary` in `check-no-engine`, five glossary rows and two
spellings on existing rows, and a one-word change in
`ai_rts_core.pt-BR.md` (*hash* becomes *spatial hash*). It also adds the
STATUS row.

A fresh context reviewed PR #86 at head 85f8f04, in a throwaway worktree.
It made no commit, push or PR comment.

**Verdict: changes requested, no blocker.** The gate does what it says
on today's pages. It is not green while checking nothing: no page gives
G1, an empty table gives G2, and no glossary gives exit 2. It reads all
23 pages, `README.pt-BR.md` included. The allowlist is one-way. Two
should-fix findings remain. First, a common Markdown form, an English
word in italics with a Portuguese plural `s` outside the asterisks
(`*zergling*s`), passes unseen. Second, nothing tests that the plural
rule strips only an `s`: two mutations of it survive the self-test.

## What was reviewed

- The whole diff: the gate, the Makefile hunk, the glossary rows, the
  `ai_rts_core` line and the STATUS row. Also the task file, the PR body,
  `docs/howto/parallel-batch.md`, `scripts/run_selftests.py` (does it
  find the gate by its name? It does) and the review of wave 135, for the
  format.

## What was run (green at 85f8f04 unless stated)

- `python3 scripts/check_glossary.py --self-test`: `self-test: ok`, exit 0.
- `python3 scripts/check_glossary.py`: exit 0.
- `python3 scripts/run_selftests.py`: lists `check_glossary.py ok`.
- `check_readability.py`, `check_translations_docs.py`,
  `check_modules.py`: exit 0. `make lint-tasks lint-status
  lint-docs-freshness lint-links lint-modules lint-selftests`: exit 0.
- Counted: `git ls-files '*.pt-BR.md'` gives 24, and the files on disk
  outside dot folders are the same 24. The gate reads 23 of them, every
  one except the glossary.
- A parser probe: `italic_spans(prose(...))` on 34 cases (see below).
- End-to-end probes: a copy of today's pages with one line appended to
  `ai_steering.pt-BR.md`.
- 23 mutations, each a one-line change to a copy of the script, run
  against the self-test and the real pages (`python3 -B`, so no
  `__pycache__` was written).

## The parser (focus 3)

These hold. `*a* and *b*` gives two spans. `**bold**` gives none.
`***both***` gives `both`. A span inside link text is read, and the link
target is not. An asterisk in a code span, or in a fenced block, is not
read. `snake_case_name` gives nothing, and `_real_` gives `real`.
`* item` at the start of a list gives nothing. `A\*` gives nothing.
`un*frigging*believable` gives nothing (see finding 1). A span over two
lines is read; a span past a blank line is not. Unicode works
(*Façade*). A ```` fence with an inner ``` reads the inner lines, but
that is a false positive, so it is harmless.

These fail. Each is a false negative, appended to a real page, and each
gave exit 0:

| appended line | rendered | gate |
|---|---|---|
| `Dois *zergling*s.` | *zergling*s | passes (finding 1) |
| `Um *IDA\* variant* aqui.` | *IDA\* variant* | passes (finding 6) |
| `Um <em>zergling</em> aqui.` | *zergling* | passes (finding 6) |

For comparison, these give a G3 as they should: `*arrived*` (a defined
term plus `d`), `*zergling*` as the text of a link, and `*seek, zergling*`.

## The plural rule (focus 5)

Dropping a final `s` makes no wrong match today. No glossary term `t`
has a `t + "s"` that means something else. `bias` matches as written,
before the rule runs, so it never becomes `bia`, and `class` is no term.
The `len > 2` guard keeps `as` from becoming `a`. A term `a` exists
because the cell `A\*` loses its star. The rule itself is right. What it
lacks is a test (finding 2).

## The allowlist (focus 4)

It is one-way. If the `is_defined` branch or the unused branch of
`allowlist_findings` is taken out, the self-test fails. The matching is
exact and case-sensitive.

## Mutation round

| mutation | self-test | real pages |
|---|---|---|
| `singular` strips any last character | **survives** | 0 |
| `singular` is `rstrip("s")` | **survives** | 0 |
| link targets not blanked | **survives** | 0 |
| `**` not removed | **survives** | 0 |
| first cell split on `/` only, not `,` | **survives** | 0 |
| allowlist compared without case | **survives** | 0 |
| plural rule off | killed | 1 |
| no casefold | killed | 1 |
| README skipped | killed | 1 (G4) |
| dot folders read | killed | 0 |
| G4 "defined" branch off | killed | 0 |
| G4 "unused" branch off | killed | 0 |
| code spans kept | killed | 1 |
| fences kept | killed | 0 |
| comments kept | killed | 0 |
| underscore italics off | killed | 0 |
| a span over two lines not read | killed | 1 |
| G1 off | killed | 0 |
| G2 off | killed | 0 |
| parenthesised part kept | killed | 0 |
| the header row read as a term | killed | 0 |
| the glossary read as a page | killed | 1 |
| allowlist ignored for G3 | killed | 1 |

## Findings

1. **should-fix** -- `scripts/check_glossary.py:117`. The `*` closer
   refuses a letter after it (`(?![*\w])`). CommonMark lets `*` emphasis
   close inside a word, so `os *zergling*s` renders *zergling* in
   italics and the gate never sees it. A Portuguese plural written
   outside the asterisks is exactly the form a pt-BR writer reaches for.
   Fix: make the closer `(?!\*)` for the `*` form only, and keep `_`
   word-bounded, which is what CommonMark does. Then plant
   `Dois *zergling*s.` as a G3 case. Measured: with the closer changed,
   the real pages still exit 0, the self-test stays ok, and
   `*zergling*s` gives `zergling`. The unescaped `A*` in
   `catalogue.pt-BR.md` still opens no span.
2. **should-fix** -- `scripts/check_glossary.py:321-339`. No planted case
   holds the plural rule to a final `s`. `span[:-1]` with no `s` test, and
   `rstrip("s")`, both survive. Fix: plant `*arrived*` (`arrive` is
   defined; the gate must say G3), and `*seekss*` for the rstrip.
3. **nit** -- `scripts/check_glossary.py:145` and `:294`. Link-target
   blanking is untested. `GOOD_PAGE`'s link `docs/a_b_c.md` has no
   underscore that could open a span, so taking out `LINK_TARGET_RE`
   survives. Fix: make the planted link's target `docs/_steering_.md`.
4. **nit** -- `scripts/check_glossary.py:112-113` and `:145`. "Bold is
   removed before this runs" reads as if the regex needed it. The regex
   already refuses `**`. The removal matters only for `***x***` and for
   bold inside italics, and no planted case has either, so taking it out
   survives. Fix: plant `***steering***` as a G3, and say in the comment
   which case the removal is for.
5. **nit** -- `scripts/check_glossary.py:164`. The split on `,` is
   untested, because every comma-separated spelling in `GOOD_GLOSSARY`
   is also italic, and so is caught by `italic_spans` first. Fix: add a
   row whose plain first cell has a comma, such as `PID, LQR`, and use
   *LQR* on the good page.
6. **nit** -- `scripts/check_glossary.py:116-119` and the docstring. An
   italic span that contains `\*` is not found (`*IDA\* variant*`). HTML
   `<em>`/`<i>` is not read. No page has either today. Fix: allow `\\\*`
   in the `*` body, and turn `\*` into `*` before the lookup. Name `<em>`
   in the docstring's "what it cannot tell", or read it.
7. **nit** -- `scripts/check_glossary.py:99-106`. The comment says
   `EMPHASIS` is "a word stressed, or a sentence quoted". But *binária*,
   *global*, *consistente* and *contexto* are Portuguese technical terms,
   in italics where they are defined (`ai_constraints.pt-BR.md:21-22`,
   `ai_search.pt-BR.md:56`, `ai_opponent.pt-BR.md:20`). Also, an entry is
   allowed on every page, and *global* is English too. Fix: add that
   third kind to the comment. Optionally, key the list by
   `(page, span)`, so an entry clears only the page it was measured on.
8. **nit** -- `docs/techniques/glossary.pt-BR.md:81`. The *stand-in* row
   ends "antes das do dono". A reader of a public glossary does not know
   who "o dono" is. *Stand-in* is also not a word Brazilian developers
   say in English, and the task's step 3 allows removing the italics
   instead. Fix: on `ai_bandit.pt-BR.md:51`, write "os jogadores escritos
   em código do T18" and drop the row. Or, if the row stays, end it with
   "antes das lutas gravadas por uma pessoa".
9. **nit** -- `docs/techniques/glossary.pt-BR.md:70`. "volta direto à
   variável que causou o conflito": in AIMA 6.3.3, backjumping goes back
   to the most recent variable in the conflict set, and there can be
   several. Fix: "volta direto à mais recente das variáveis que causaram
   o conflito, e não só à anterior".
10. **nit** -- `Makefile:123`. The gate is added to the shared
    `check-no-engine:` list line. `docs/howto/parallel-batch.md` has each
    new name stand on its own line, beside its own rule, so that two
    waves never rewrite the same line (`check: test-rts-clock-limits`).
    Neither sibling branch (137, 138) touches the Makefile, so nothing
    conflicts today. Fix: `check-no-engine: lint-glossary` under the
    `.PHONY: lint-glossary` line, with line 123 left as it was.

The rows for *exploration*/*exploitation*, *rush*, *min-conflicts*, *arm*
and *epsilon* are real definitions in good pt-BR. They follow the
glossary's form, which is the term in italics and then what it is, with
translated names in parentheses. *spatial hash* is the right fix on
`ai_rts_core.pt-BR.md:40`: the glossary defines it, the page means it,
and "do *spatial hash*" agrees in gender.

## The owner's decisions

1. **Titles and emphasis as an allowlist in the gate.** Agree. G4 keeps
   it honest in both directions. A per-page key (finding 7) would be a
   cheap tightening, and it can wait.
2. **The glossary page is not read for spans.** Agree. Its second column
   holds expansions, defined by their own row. The mutation that reads
   it finds 2+ "findings" that are all expansions.
3. **One plural rule, a final `s`.** Agree. Today it makes no wrong
   match. It needs the planted case in finding 2, so that it stays only
   that rule.
4. **The reverse rule (English without italics) is not checked.** Agree.
   It would need a dictionary, and it belongs to review.
5. **CLAUDE.md's gate table unchanged.** Agree. The invariants table does
   not name the glossary rule, and the task's step 4 says to add a row
   only if it does.

## What was done about them

All applied on the branch, in one commit after 85f8f04 and a merge of
main at 2374de1.

1. **Applied.** The `*` closer is `(?!\*)`, so a `*` closes inside a
   word as CommonMark's does; `_` stays bounded. `Dois *zergling*s.` is a
   planted G3 case. The real pages still exit 0.
2. **Applied.** `*arrived*` and `*seekss*` are planted G3 cases. The two
   mutations of `singular` (any last character, `rstrip("s")`) are now
   killed by the self-test.
3. **Applied (nit).** The good page's link is `docs/_steering_.md`;
   keeping link targets is killed.
4. **Applied (nit).** `O ***steering***.` is a planted G3 case, and the
   comment says the `**` removal is for `***x***` and bold inside
   italics. Keeping the `**` is killed.
5. **Applied (nit).** The planted glossary has a plain row `PID, LQR`, and
   the good page uses *LQR*; splitting on `/` only is killed.
6. **Applied (nit).** An escaped `\*` inside a `*` span is read, and
   looked up as `*` (`*IDA\* variant*` is a planted G3). HTML `<em>` and
   `<i>` are named in the docstring as a known gap, not read.
7. **Applied (nit), comment only.** The `EMPHASIS` comment names the third
   kind, a Portuguese technical term in italics where its page defines
   it, and says an entry holds on every page and that *global* is also
   English. The list is not keyed by page; that is left as a note in the
   PR.
8. **Applied (nit).** `ai_bandit.pt-BR.md:51` says "os jogadores escritos
   em código do T18", without italics, and the *stand-in* row is gone.
9. **Applied (nit).** The *backjumping* row says it goes back to the most
   recent of the variables that caused the conflict.
10. **Applied (nit).** `check-no-engine: lint-glossary` stands on its own
    line beside the rule; the shared list line is as it was on main.

Measured after the changes: the seven mutations named in findings 1-6
were each applied to a copy of the script, and each is killed by the
self-test.

Two quoted Markdown links in the record above (in "The parser" and in
finding 3) were reworded as plain text with the same meaning, because
`lint-links` reads a link inside backticks too, and their targets do not
exist.
