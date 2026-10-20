# T62 — Search over a port, not over a grid

Size: M · Prereqs: T58 · Files: `godot/addons/ai_search/`, `godot/test/ai_search/`, `spec/vectors/search/`, `docs/concepts/`

## Goal

The second technique to gain a port, after the pattern `ai_adversarial`
already follows (`AdversarialGame`: the addon owns the conversation, the game
writes the adapter -- Cockburn's "a port identifies a purposeful
conversation"). A\*, Dijkstra, breadth- and depth-first are graph
algorithms; ours take a `GridGraph`. A reader with waypoints, a navigation
mesh's polygons or a dungeon of rooms cannot use them without becoming a
grid first.

## Diagnosis (measured 2026-10-20 on `5129bfc`)

`search.gd` and its four algorithms ask a graph three things: its
neighbours (`neighbours(cell)`), the cost of entering one (`cost_at`), and
-- for A\* -- a distance to the goal. Every signature takes
`graph: GridGraph, from: Vector2i, to: Vector2i`. `Pathfinder` in `ai_core`
has the same signature, and only `ai_search` implements it.

## Steps

1. **Read the algorithm files top to bottom first.** The port is what they
   already ask, named; if a method appears that no algorithm calls, it is
   not part of the port.
2. **Decide two things, in the task file, before code:**
   - *Where the port lives.* Recommended: `SearchGraph` in `ai_search`
     (`@abstract`, like `AdversarialGame`), with `GridSearchGraph`, the
     adapter over `ai_core`'s `GridGraph`, in `ai_search` too -- so "someone
     who wants only A\* copies two folders" stays true. Putting the port in
     `ai_core` would grow the kernel T61 just shrank for a port one technique
     uses.
   - *What a node is.* Recommended: keep `Vector2i`. A waypoint graph names
     its nodes by position, and the algorithms' text -- which reads like the
     book's -- does not change. An opaque `int` id is the general answer and
     costs every reader a lookup; say so in the header's "when not to use it".
3. **The port, the adapter, the algorithms over the port.** The existing
   vectors replay unchanged through `GridSearchGraph`; that is the proof the
   refactor changed nothing.
4. **A graph that is not a grid**, in a test: a handful of waypoints with
   costs, where the shortest path by cost differs from the fewest hops, run
   through all four algorithms with what each one promises.
5. **The concept page** shows the port and the two adapters side by side.
6. Whether `Pathfinder` still earns its place in `ai_core` after this, or
   is `SearchGraph`'s caller's interface and moves -- measured by who uses
   it, decided in this task, written in T61's record if it changes the
   kernel.

## Acceptance

```bash
make check-affected BASE=origin/main
```

```bash
make test-search-vectors
```

The algorithms name no grid:

```bash
! grep -vE '^\s*#' godot/addons/ai_search/astar.gd godot/addons/ai_search/dijkstra.gd godot/addons/ai_search/breadth_first.gd godot/addons/ai_search/depth_first.gd godot/addons/ai_search/search.gd | grep -w GridGraph
```

The waypoint test lives in `godot/test/ai_search/` and runs in
`make test-godot-some`; it is the planted case for the port: a search that
silently counted hops instead of cost fails it.

## Manual check

Read `astar.gd` beside the book's pseudocode, as before: does it still read
like it?

## Out of scope

- Ports for `ai_perception` or `ai_rts_core` (both use `GridGraph`, for
  sight and flow fields, which are grid techniques).
- A navigation-mesh adapter for Godot's `NavigationServer`.
