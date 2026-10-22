# Review: wave/81-the-literature-and-a-roadmap

A fresh context reviewed T73 at `d61e80f`:
`docs/concepts/the-literature-and-the-kit.md` -- AIMA's and the game-AI
literature's techniques in tables against what the kit has, a roadmap,
and the owner's questions in Portuguese and English -- and
`scripts/check_literature_table.py`, which holds each row's kit cell to
a module or path that exists. It was not allowed to edit the worktree. It
ran the gate and its self-test, `check_readability`,
`check_doc_freshness`, `check_no_employer_refs`, `lint-tasks`,
`lint-status` and `lint-selftests`, all green, and opened six of the
sources itself: the Game AI Pro index, AIMA's contents, Yannakakis and
Togelius's table of contents, Booth's Left 4 Dead slides, Smith's GAP2
chapter and Orkin's paper -- each said what it was cited for.

**Verdict: fix before merge.**

## What was reviewed

- `CLAUDE.md` (invariants 1, 3, 4, 5, 6, 7 and the rule that a source is
  cited only once opened), T73's task, the page, the gate and its wiring.
- Every module, path and demo the table names, against the repository.
- Each roadmap entry against invariants 6 and 7 and ADR 0016's scope.
- The gate, by planting rows it should refuse.
- That the questions are answerable and no follow-up task was written.

## Findings

1. **A.8 read invariant 6 wrongly** (high): a per-session player model
   was said to need no new decision; ADR 0016 covers only
   `ai_opponent`'s n-gram table.
2. **A.2 tested the director by saving, not fitting** (medium).
3. **The RTS's own influence map was missing** (medium):
   `godot/game/rts/rts_influence.gd`, so "today there are two" was false.
4. **Two holes in the gate** (medium): a hyphenated name in backticks and
   a demo without backticks both passed; a table losing its "In the kit"
   column was skipped silently.
5. **The Tier column disagreed with the pages' own tiers**, and the LLM
   row's tier 3 put a lesson above tier 1 (low).
6. **Rows missing what the kit has** (low): difficulty in fighting and
   the RTS, fuzzy in infiltration, the role arbiter, the 2D racer's
   lookahead and the rubber band it refuses, the RTS's fog of war.
7. **AIMA ch. 2, 7-10 and 26 had no row** (low).
8. **AIMA 18.3 cited for team coordination** (low): it is cooperative
   game theory.
9. **Provenance** (low): Halo 2 is named only in the BT chapter's
   conclusion, not the introduction read; the edition and year were not
   on the page cited.
10. **"Seven tables"** where there were eight (low).

## What was done about them

All ten in `1e9e72e`: any player model, and bandits, need the owner to
extend ADR 0016 on its three conditions, and Q3 and Q4 ask exactly that;
the director stays inside invariant 6 while every number it uses is
fixed; the influence row and B.5 name all three maps; the gate flags any
backticked name that is not a module or path (L3), requires the demo
cell to be `--` or backticked targets (L5), and refuses a table without
the column (L6), each with a planted case -- nine in all; tiers follow
each page's `tier:`, the LLM row is tier 1 with live use at tier 3; the
missing rows and a table for AIMA's framing chapters were added; 18.1
only; the BT chapter is marked as its introduction and Halo 2 dropped
from the table; the edition is quoted from gameaibook.org's home page;
48 rows in nine tables, matching the status row and the Done note. The
gate and its self-test, `run_selftests.py`, `check_readability`,
`check_doc_freshness`, `check_no_employer_refs`, `check_tiers`,
`lint-tasks` and `lint-status` pass; the full `make check-affected` ran
green before the rebase, and the changes since touch only the page, the
tasks and the gate, which its self-test covers.
