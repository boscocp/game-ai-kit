# Fun review (T42)

The owner, 2026-10-15: the examples teach the technique, and playing them
is not yet something a person wants to do twice. This is one line per
example -- what a player does, what would bring them back, what is missing
-- and the smallest change that adds a goal, pressure or a surprise without
hiding the decision overlay (invariant 13). The owner picks; each pick
becomes its own task.

**Where the lines come from.** Each example's code and tests, the owner's
four reports in T41, and screenshots of the search demo and the skirmish
taken on 2026-10-17. Not from a person playing every example through: that
is the owner's half, and a line that reads wrong after a game should be
corrected here.

The standing asks still hold: games people already know, against the AI,
low-friction input, scenarios a person can edit. And two invariants bound
every proposal: nothing trains at game time (6), and the decision stays on
screen (13).

## The examples

| example | what the player does | what is missing |
|---|---|---|
| tic-tac-toe vs MENACE | plays noughts against a matchbox machine of a chosen age | nothing carries over from one game to the next: no score, no reason to try the older machine |
| checkers | plays red against minimax at depth 1-6 | a depth is a number to set, not a step to climb; the game is long and has no shorter form |
| search | paints a board and watches four searches | no goal at all: a sandbox, which is the right tool for the lesson and not a game |
| stealth | crosses one hall without being caught | one room; a win is a win however it was done, so there is no second, better run |
| tactical | moves an army at blue's workshop | no combat until T26, so nothing is ever lost: easy to win, or stalled by a parked piece (T41) |
| skirmish | moves two units, holds a flag (since T41) | no combat until T10; blue can win a hold now, but nothing on screen warns the player it is close |
| fighting | fights a dummy, one of three levels, or their own ghost | a training room: no ladder, no "next opponent", no ending |

## The smallest change for each

1. **MENACE, a ladder of ages.** Win or draw against the 10-game box to face
   the 100-game one, and so on to 10,000; a tally for the session. Every
   age is already trained in Python, so nothing learns at game time.
2. **Checkers, a ladder and puzzles.** Beat depth 2 to unlock depth 3, the
   tally on screen. And **puzzles**: positions from a text file -- "red to
   move and win in 4" -- against depth 6, which are short, editable by
   hand, and a classic form of the game.
3. **Search, challenges on the same board.** A line of puzzles beside the
   sandbox: "with 8 walls, make depth-first's route cost three times
   Dijkstra's", "make A\* expand more than Dijkstra" (`search_properties.gd` has
   never seen it happen in 300 boards -- the puzzle that asks why). The board's own
   promise check already measures the answer.
4. **Stealth, rooms and par.** Rooms from text files, rows of characters
   as the search boards and the tactical map are written, a par in turns and a mark for a run with no
   alert. A second run has something to beat.
5. **Tactical, combat first.** T26 is the change that makes it a game:
   until a piece can be lost, no other tweak gives it stakes. Then a par in
   rounds.
6. **Skirmish, pressure on screen.** Blue's hold count shown on the board
   itself, over the flag, and blue walking at its own flag when nothing
   else is in reach -- which it already does, so the change is mostly the
   warning. Combat is T10.
7. **Fighting, an arcade ladder.** Easy, medium, hard, then the owner's
   ghost and the clone, best of three each, with an ending. Every opponent
   already exists; this is a menu and a score.

## Cheapest first

By what already exists: 7 (all opponents exist), 1 (all ages trained), 3
(the checks exist), 2 (depth is a key already; puzzles need a loader), 4
(rooms need a loader), 6, then 5 (T26 is a task of its own, size L).
