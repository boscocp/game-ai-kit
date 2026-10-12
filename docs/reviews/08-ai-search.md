# Review: wave/08-ai-search

Reviewed 2026-10-12 by a context that did not write the code, against
`361e3a1`, with instructions not to trust the planted cases — they were written
by the same context as the algorithms, which is the symmetry the apparatus
exists to break.

This wave was reviewed three times by three contexts, and the two earlier ones
were reviewing `ai_core`, which wave 7 merged on an incomplete review. Their
findings are fixed here rather than in a wave of their own: A\* is wrong on a
board with a negative terrain cost, and that board was buildable.

## What was reviewed

`main..361e3a1`: the four searches in `godot/addons/ai_search/`, `SearchResult`,
the conformance vectors and their runner, the 300-board property check, the
demo under `godot/demos/search/`, and the T2 code they rest on.

Method: 19 mutations against all three gate commands — `make test-godot`, `make
test-vectors`, and the property script — because they have separate exit codes
and a rule can be held by one and not the others; 17 probe cases; instrumented
counters on two branches; and a read of each file against the claim in its own
header. One mutation was known in advance to **hang** rather than fail, so every
run was given a timeout.

## Findings

**Twelve confirmed, and the first is the one worth reading.**

1. **`dijkstra.gd` carried a branch that cannot execute, and its header called
   that branch "the line worth reading them for".** The textbook improvement
   test — a cell already seen is still worth improving — fired **0 times in 250
   random boards**, against 165 for A\* on the same boards. The reason is the
   frontier: `_cheapest` scans it and reads `g` as it is *now*, so the cell
   taken off is always the globally cheapest and its cost is already final.

2. **The duplicate-expansion guard beside it was dead for the same reason, and
   its seven-line comment was a byte-for-byte copy of A\*'s** — citing A\*'s
   "300 random boards, 14 of them" measurement as though it were Dijkstra's.

3. The O(V²) claim was right and its stated reason was not: one of the "two
   linear scans" never runs.

4. **A claim with no planted case, which measurement then showed to be false.**
   `astar.gd` said a stale `f` "would send the search the wrong way". Freezing
   `f` at its first value across 241 random boards changed neither the cost
   returned nor the number of cells expanded, not once.

5. Two comments that were simply untrue: `pop_front` versus `pop_back` is not
   "a single character", and `depth_first.gd` called its stack "the queue".

6. **No search validated its start.** `from = (-1, 2)` on a 5×5 board returned
   `reached`, cost 3, with a path that walked in from nowhere — and the
   conformance runner accepted it, because every individual *step* was legal.

7. – 9. **The conformance runner had three holes and no planted case for any of
   its rules.** Ragged `costs` rows were padded or truncated in silence and the
   vector still "conformed"; a `from` outside the board was never rejected; and
   one assertion could never fire. `lint-selftests` could not have caught this:
   it finds gates by the name `scripts/check_*.py`, and this one is GDScript.

10. The demo's `COLUMNS` and `ROWS` read as adjustable beside a hardcoded start,
    goal and mud row. Change either and it silently showed "no route" with its
    markers drawn off the board.

11. **The demo hid the thing it exists to show.** Expansion rectangles at full
    tile size and 0.85 alpha buried the mud band — so *why* Dijkstra goes round
    disappeared exactly when the picture was complete.

12. A doc bullet in `pathfinder.gd` narrating its own revision history.

**Eight mutations survived**, four of them in rules the review then showed were
dead (1 and 2 above). The four that mattered: depth-first turning into
breadth-first with nothing going red — the demo's entire lesson ungated —
`_cost_of` skipping the first cell of a path, which only the vectors caught,
and two of the runner's own checks.

**One suspicion, handed over as a suspicion.** `Search._rebuild` crashes with
"invalid key" if the chain of parents is broken. Unreachable today.

**What held up.** A\*'s admissibility: both `GridGraph` constructors clamp,
`duplicate_graph` copies clamped data, Manhattan is consistent, and the
closed-set skip is therefore safe — an inadmissible heuristic is caught by the
property script. Breadth-first and depth-first differ by exactly the pop.
`nothing_found`'s `-1` is unambiguous now that costs clamp at 1. Boards of 0×0,
1×1 and all-walls return cleanly, with no hang and no crash.

## What was done about them

All twelve are fixed in `a68860e`, with four tests closing the survivors that
were not dead code. The pop-site comments discussed at the end of this section
landed in the same commit as this record.

(The first version of this paragraph cited a commit hash for those comments.
The hash did not exist — it was written before the commit was made and never
checked. It is corrected here rather than quietly dropped, because a plausible
identifier that resolves to nothing is worse than no identifier at all.)

Dijkstra lost both inert rules, and its header now says the thing worth knowing:
it does not revisit **here** because of how this frontier is built, and a binary
heap keyed at insertion brings both straight back. That is the trade, and it is
why the heap is not a free upgrade.

The stale-`f` claim is withdrawn in place with the measurement that killed it.
The line stays, because A\* is defined to order by the current best estimate and
the implementation should not quietly depend on an accident of those boards —
which is a different reason from the one that was there.

The start check lives once, in `search.gd`. A start that is merely *blocked*
still gets through: cost is paid on entering a cell, and something may well have
put a unit in a wall. Both halves have a test, so that "guard the start" does
not quietly become "refuse anything awkward".

The runner's rules moved into `SearchVector`, where a test suite hands them
broken vectors and watches them object — ragged rows, an end off the board, and
a cost of `0` that `GridGraph` would have clamped to `1`, leaving the vector
pinning an answer nobody wrote down.

**One finding was answered with an argument rather than a change.** The reviewer
noted that `_cheapest` — the one operation distinguishing Dijkstra and A\* from
breadth-first — lives in `search.gd`, so a reader of `astar.gd` must jump files
to see it. The function stays shared, because duplicating it would put the same
six lines in two files and tie a reader's understanding to noticing they are
identical. What changed is that neither file now needs the jump: the pop site in
each says what `_cheapest` does and why it is written elsewhere.

**What this record cannot claim.** The fixes above were not reviewed by a fresh
context; they were written by the session that received the findings. Three
reviews have now each found real defects in work the previous one had passed
over or never reached, which is the argument for the rule rather than against
it. The next wave should start by reviewing this one.
