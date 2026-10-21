# Review: wave/68-search-port-and-registry

A fresh context reviewed the wave at `d92cfa7`: T62, T63 and the league
page. It was not allowed to edit the checkout. It ran every acceptance
command in both task files and `make check-affected BASE=origin/main`
(which selected all of `make check`, since `scripts/` changed), read each
`SCRIPT ERROR` in that log, and planted mutations in scratch worktrees.

**Verdict: fix before merge.** It found no code defect: the semantics are
unchanged, the gates pass, and the planted cases catch what they claim.
But four passages of documentation now said something false, and one of
them was in the first algorithm file a reader opens.

## What was reviewed

- `CLAUDE.md`, both task files with their "Decided" and "Done" sections,
  and `git diff origin/main...HEAD`.
- The port: is the waypoint graph's estimate really consistent? (Yes: hops
  are an undirected breadth-first distance and every node costs at least
  the cheapest, so `h(n) <= cost(n') + h(n')`.)
- The table: does C still cycle rules, planner, learned, easy, normal,
  hard, state machine, tree, GOAP, HTN and back? (Yes, and every row's
  controller names itself as its row.)
- The league: both runs, again. The new order gives the page's new table
  exactly, and the old order put back gives `main`'s exactly.

## Findings

Each one is followed by what was done about it.

1. **`astar.gd`'s header promised Dijkstra's cost from an *admissible*
   guess.** This A\* never expands a node twice, so it needs a *consistent*
   one, which is what `SearchGraph.estimate` and the task already said. The
   reviewer showed it on six waypoints with an admissible, inconsistent
   guess: Dijkstra 7, A\* 8. *Fixed*: the header now says consistent and
   why, and that graph is a test in `waypoint_test.gd`. It is a sharper
   lesson than the overshooting guess.
2. **`PlannedBlue.verbose` was left dead.** Its only setter was the chain
   T63 removed, its comment still said "as the scene does", and
   `docs/godot/planning.md` still said the plan is printed to the console.
   *Fixed*: the flag and its `print` are gone, and the page says the plan
   is on the panel and in the overlay.
3. **`pathfinder.gd` opened with "What `ai_search` must provide"**, which is
   no longer true of `Search`. *Fixed*. The first rewrite named
   `GridPathfinder`, and `check_addon_deps.py` rejected that (A2: `ai_core`
   naming a class another addon declares). It now says `ai_search` provides
   one without `ai_core` knowing its name.
4. **`addon-anatomy.md` and `check_addon_deps.py`'s docstring showed
   `AStarSearch.find_path(...)`**, which no longer exists. *Fixed*: both use
   `AStarSearch.new().search(...)`.

Suggestions, not blocking:

5. A controller from outside the table now goes to the rules; the chain
   sent it to the planner. The game never meets one. *Done*: listed among
   T63's deliberate changes.
6. Reordering the table re-rolls the league's dice. *Done*:
   `TacticalRoster`'s "when not to use it" says so and points at the page.
7. C9 checked membership both ways, but not order or duplicates. *Done*:
   the card must list the rows in the table's order, once each, with two
   more planted cases (46 in the self-test).
8. and 9. `tactical.gd` still spelled the order out in prose, and the
   roster's header said the menu reads the table, when it is
   `check_demos.py` that does. *Fixed*.
10. Two overlong comment lines. *Fixed*.
11. `docs/godot/search.md` said every snippet was run, but the `Waypoints`
    snippet is a stub. *Fixed*: it is labelled as a sketch, with a pointer
    to the test that runs.

On the author's decisions the reviewer agreed with all of them: scoping C9
to the one card with a table, dropping `verbose`, keeping `Pathfinder` in
`ai_core` (moving it would make `tactical`'s test-only use of `ai_search` a
real dependency), naming the league's lookahead `hard`, and the hop-based
estimate.

## What was done about them

All of it went into one commit, `fe30f46`. After it, `check_readability`,
`check_addon_deps`, `check_modules` and `check_demos` (46 self-test cases)
pass. `make check-affected BASE=origin/main` passes with 1091 test cases.
Its log holds only the six planted `SCRIPT ERROR`s: two abstract
`Pathfinder` cases, one `DecisionPolicy` case, and the overlay's crashing
step three times.
