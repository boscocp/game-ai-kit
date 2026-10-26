# Review: wave/87-technique-pages

T74, as written, its "Decisions written down first" taken as stated for the
owner to confirm here: one page per technique in `docs/techniques/`, English
beside pt-BR, the first four (`ai_search`, `ai_steering`, `ai_behaviour`,
`ai_core`), a pt-BR glossary, `non_module_techniques.json`, and
`check_translations_docs.py` holding the pair in step -- the translation
pinned by the sha256 of the English body, headings matched by level and
anchor, code blocks byte for byte, each page's minimal example equal to a
file that a gdUnit case loads into an empty scene. A separate commit amends
T76 with the owner's 2026-10-26 request (the catalogue both ways, and a
generated summary in the README).

A fresh context reviewed PR #26 at head 0ebe02a.

**Verdict: merge after the should-fix.** No blockers.

## What was reviewed

- The gate's rules against the task's list of planted cases, and each rule
  branch by replacing it with `pass` and running `--self-test`.
- Twelve drifts planted into a copy of the real pages -- a stale English
  edit, a heading level, an anchor, a code line, a fence language, an
  example file changed, a missing pair, a stray page and others: all
  rejected.
- What must pass, and did: a CRLF checkout, a lone CR, and trailing space
  after an anchor.
- `make check-affected` for a docs-only change: it selects
  `lint-translations-docs`, because the target is in `check-no-engine`'s own
  list, which `check_modules.always_run` reads.
- Each page's claims against the code and the manifests: the demos named,
  the classes and knobs, what to copy.
- The three examples and their suites, and the freshness layer.

## Findings

1. **The ai_search page named demos that do not use it** (should-fix):
   `demo-tactical` and `demo-rts` (the RTS walks `ai_rts_core`'s flow
   field; tactical names Dijkstra only in a comment), and "the 3D
   examples", which suggests the racer. The manifests say `demo_search`,
   `demo_behaviour`, `stealth`, `skirmish`, `botmatch`, `infiltration`.
2. **The ai_search page never named `GridSearchGraph`** (should-fix):
   `Search.search` and `CostFlood.within` take a `SearchGraph`, and a
   `GridGraph` is not one; a reader following the table would not compile.
3. **Six rule branches had no planted case** (should-fix, invariant 4):
   with the branch replaced by `pass` the self-test still passed -- D4,
   D5 when `translation_of` is missing, D9 when the example names no file,
   D10 when there is no example block, D11 for a name that is no technique,
   D13.
4. **The arrive example teleported to the origin** (should-fix): the
   vehicle was built at `Vector2.ZERO` and its position copied to the node
   every frame.
5. **The hash went stale on a trailing newline** (nit), and `normalised`'s
   docstring did not say `read_text` already gives universal newlines.
6. **D8 dropped the fence line** (nit): ```` ```gdscript ```` against
   ```` ```gd ```` passed, and ```` ``` ```` and `~~~` closed each other.
7. **`trail()` returned the tree's live array** (nit).
8. **"across six"** in `route_example_test.gd` (nit): it is five.
9. **Five functions of the gate had no docstring** (nit): `check`, `run`,
   `good_pages`, `self_test`, `main`.
10. **STATUS described the old T76**, and T75's row said seven technique
    modules where there are eight (nit).
11. **"Prenda-o em qualquer nó"** (nit): "Anexe-o a qualquer nó".

## What was done about them

1. The watch section lists `demo-behaviour`, `demo-stealth`,
   `demo-skirmish`, and names the two 3D examples, `demo-infiltration` and
   `demo-botmatch`, in both languages.
2. "In this kit" says the demo wraps the grid in `GridSearchGraph.new(grid)`,
   the table's `CostFlood.within` row shows it, and "What you implement"
   says when a `Pathfinder` is enough and when to wrap, with the call.
3. Seven new planted cases: an orphan translation (D4), no
   `translation_of` (D5), a fence language that differs (D8), an example
   naming no file (D9), a technique page with no example (D10), a
   non-module technique naming a missing path (D13), and trailing newlines
   that must pass; plus a `STILL_TO_WRITE` naming no technique (D11). 23
   cases now. Each of the seventeen finding branches was silenced in turn
   by a script and the self-test caught every one (17/17); removing the
   `rstrip` and dropping the fence line from D8 are each caught too.
4. `_ready` seeds the vehicle from `position`; pasted into both pages. Two
   new cases: the vehicle stands where the node was placed before any
   frame, and it arrives from (500, 40). With the seeding line removed,
   the first fails.
5. The hash takes the body with its trailing newlines stripped and one put
   back; the docstring says what `read_text` already does and why the
   function stays.
6. `code_blocks` returns the opening fence line, D8 compares it with the
   contents, and a block closes only on a fence of its own kind (in
   `outside_fences` too).
7. `trail()` returns a duplicate, in the file and both pages.
8. Five.
9. Done, each saying what and why.
10. Both rows updated; T74's row counts 23 self-test cases.
11. Done.

`translation_of` was recomputed for every pair after the English edits.

Run after the fixes: `python3 scripts/check_translations_docs.py` 0 and
`--self-test` ok; `check_doc_freshness.py` 0 and `--self-test` ok;
`make lint-tasks lint-status` 0; `check_links.py`, `check_readability.py`
0; `make test-godot-some SUITES="test/ai_search test/ai_steering
test/ai_behaviour"` 65 of 65, no SCRIPT ERROR. `make check` was not run,
on the owner's instruction for this round.

Still the owner's: the decisions at the top of T74, and its manual check --
does the pt-BR read as written for a Brazilian reader, and can the
`ai_search` page alone wire the addon into a fresh project. GitHub shows a
heading's `{#anchor}` as text; that is the decision's cost, not a defect.
