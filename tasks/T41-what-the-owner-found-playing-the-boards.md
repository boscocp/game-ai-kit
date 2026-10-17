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

plus one new headless check per reproduced bug, named under "What each one
was": `tactical_bridge_test.gd` (the bridge game), `skirmish_flag_test.gd`
(the flag), and, for the two that were pictures, `search_demo_test.gd`'s
status case and `marker_contrast_test.gd`. All run in `make test-godot`.

## Manual check

Play `demo-search` with mud on the straight line: the route goes round it
whenever round is cheaper, and the start and goal can be seen at a glance.
Play `demo-tactical` three times: blue crosses the bridge. Stand on the
white flag in `demo-skirmish`: something happens.

## What each one was (2026-10-17)

1. **A confusing picture, not a bug.** The owner's screenshot settled it:
   the status read `breadth-first · cost 98`. The demo opens on
   breadth-first, which counts steps and never looks at cost, and the
   board's own line -- "Dijkstra goes round the mud breadth-first wades
   through" -- sat right under its route. Measured before deciding: 400
   boards painted at random through the demo's own API (mud, walls, ground,
   `-`/`=`, start and goal dragged) gave A\* the same cost as Dijkstra every
   time the goal was reachable, and on the named board A\* goes round for 21
   against breadth-first's 98. The fix is the picture: the status names
   what each search's route is the least of -- "breadth-first (fewest steps,
   blind to what a cell costs)" -- and the legend says the line is the
   chosen search's route. The owner agreed: depth- and breadth-first have no
   weights. Check: `search_demo_test.gd`,
   `test_the_status_says_breadth_first_never_looks_at_cost`.
2. **Readability, and the stealth exit had it too.** Grass averages
   (0.43, 0.72, 0.21) and the start dot was (0.45, 0.85, 0.45). The start is
   now yellow and the goal a strong red, both ringed in near-black; the
   stealth exit, a green square on the same grass, is cyan with a dark edge.
   No other example draws a start or a goal. Check:
   `marker_contrast_test.gd` measures each marker against the average of
   every tile it can sit on, and first rejects the old green (0.28 apart;
   the bar is 0.5).
3. **A bug.** Reproduced: red parks one runner on the bridge, or in front
   of it, and does nothing else. Nothing moves a piece until T26, so the
   bridge is shut; blue's route ignored who stood on it, so it built a
   shield a turn, piled 24 behind the river saying "no walk this turn brings
   it nearer", and drew at round 40. The water was open to the wader it
   never built. Now both of blue's rules count red's pieces as walls: a
   walker with no way through says "red's pieces stand on every way", and
   the workshop builds only types that can still reach red's workshop -- and
   one that beats nothing when no walker of blue's can. Against a random red
   it still wins 40 of 40. Check: `tactical_bridge_test.gd`, two whole games
   (`test_blue_wins_when_red_parks_a_runner_on_the_bridge`,
   `..._in_front_of_the_bridge`) that ended in a draw before the change.
4. **A missing rule, decided with the owner: holding a node ends the
   game.** The policy sees, per node, four numbers -- its nearest unit's
   distance, the two unit counts, the terrain on the way -- and never who
   stands on it; and no rule gave a node a meaning. `SkirmishVictory`: a side
   that starts `HOLD_TURNS` (3) of its turns in a row with a unit on a node
   and no enemy beside it wins, and the screen states the rule and the count.
   The policy walks first at a node an enemy stands on -- `LearnedDecision`
   `contest`, said as "a rule, not the model", so nothing was retrained.
   R starts again. Check: `skirmish_flag_test.gd`; with the contest rule
   switched off, two of its four cases fail.

**Seen, not only measured.** On this machine a windowed run *can* read the
viewport back (`get_texture().get_image()` returns the frame), unlike
`--headless`. The screenshots taken that way showed the new markers and
status, and blue walking at the held flag. They are not a gate: CI has no
display.
