# T41 — What the owner found playing the boards

Size: M · Prereqs: T29, T30, T21 · Files: `godot/demos/search/`, `godot/game/tactical/`, `godot/game/`, `godot/test/`

## Goal

The owner played the board examples on 2026-10-15 and wrote down four
things. Each is a report, not yet a diagnosis: the first step of each is to
reproduce it and say whether it is a bug, a confusing picture, or a rule
working as written that reads as a bug.

1. **A\* takes the shortest route through the mud, which costs 8.**
   `demo-search`, `MUD = 8` (`search_demo.gd:23`). Seen in A\*; the other
   three were not checked. Either the route really is the cheapest on the
   board the owner painted (and the demo fails to show the cost that proves
   it), or something prices mud as open ground -- the heuristic, a stale
   graph after `-`/`=` changes the price, or the board's costs not reaching
   the search. Reproduce on a painted board, compare against Dijkstra's
   cost, and the property check gains the case if it was a bug.
2. **The green start dot is hard to see on the grass.** `START` in
   `expansion_view.gd` is `Color(0.45, 0.85, 0.45)` on a green tile. Same
   lesson as the pink frontier (T8): pick a marker colour against the
   terrain it sits on, and check every demo that draws a start or a goal.
3. **`demo-tactical` still plays badly.** The owner won once; in another
   game blue got stuck at the bridge. Find what blue's controller does at
   the one river crossing -- units blocking each other, a route that never
   recomputes, a move refused and retried -- and reproduce it as a seeded
   headless game with an exit code.
4. **`demo-skirmish`: the owner stands on the white flag and the AI stays
   at the top, and nothing happens.** The learned attack/retreat policy
   may never be told the flag matters, or retreat may win every time
   nobody is near. Say what the policy sees, and decide with the owner
   whether holding the flag should end the game or draw the AI in.

## Steps

1. Reproduce each one and write down which kind it is.
2. Fix the bugs with a test that fails before the fix.
3. For the readability ones, change the picture and list it under the
   manual check.

## Acceptance

```bash
make test-godot
make test-demo-overlays
```

plus one new headless check per reproduced bug (the A\* board, the bridge
game, the flag), named here when written.

## Manual check

Play `demo-search` with mud on the straight line: the route goes round it
whenever round is cheaper, and the start and goal can be seen at a glance.
Play `demo-tactical` three times: blue crosses the bridge. Stand on the
white flag in `demo-skirmish`: something happens.
