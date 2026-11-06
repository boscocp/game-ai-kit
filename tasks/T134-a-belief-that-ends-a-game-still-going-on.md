# T134 — A belief that ends a game still going on

Size: S · Prereqs: T88 · Files: `godot/game/squad/searching_squad.gd`, `godot/game/squad/side_view.gd`, `godot/test/squad/`, `docs/godot/squad.md`

## Goal

In wave 136's duel, under the wall clock at 200 ms, `MctsSquad._chosen`
crashed four times in 40 matches against the weighed enemy. The cause was
a search root with no answer, on a board its side believed already won
or lost, while the real game went on. T88 added a guard in
`SearchingSquad._begin`: such a board is not searched, and the piece
holds, saying "believes no enemy is left, and holds". The guard has a
test. How the belief got there was not found. The review of wave 136
(`docs/reviews/136-expectiminimax-faces-mcts.md`, finding 6) probed 12
seeded matches at 30 iterations and found no case.

A side that is still asked to act has an enemy alive, because the end of
a game is announced. A belief with none contradicts that, and the side
could detect it.

## Decisions written down first (the owner confirms in review)

- Find the state first, then fix it where it is made: in `believe`'s
  bookkeeping or in `SideView`'s memory, not in the search.
- If the cause cannot be closed, `believe` falls back: when its belief
  would end a game that is still going on, it keeps every enemy it knows
  of at its last cell. This is the review's second option.

## Steps

1. Reproduce. Replay the duel's 200 ms matches on the clock, recording
   each side's `_known`, `last_seen` and the believed board whenever the
   guard fires. Then replay that turn on counted budgets.
2. Fix the cause, or apply the fallback. Add a test that builds the state
   from the recorded turn.
3. Run `make measure-squad-duel MS=200 GAMES=20` and read its output for
   `SCRIPT ERROR` and for the guard's reason.

## Acceptance

```bash
make test-godot-some SUITES="test/squad"
make test-squad-duel
make lint-tasks lint-status
```

## Manual check

None beyond the squad's own: the guard's reason should never be seen in
play.

## Notes

- Opened by wave 136 (T88), decision 9 of PR #87, with the review's
  additions.
