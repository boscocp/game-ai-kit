# Review: wave/58-one-team-per-technique

One fresh context reviewed it at its first commit (af15bc7), in a worktree
of its own. It wrote nothing in the repository; its probes and mutation
script lived in a scratch folder, and the tree was clean.

**Verdict: do not merge yet** -- one high finding and four medium. The four
teams kept their headers' claims where the tests pinned them, and no move
was refused; but the recorder wrote the wrong seed, the runner went green on
no games, and the page's "three groups" did not follow from its own rule.

## What was reviewed

- `CLAUDE.md`, T25, the whole diff.
- Run: `league_test` 11/11, `tactical_recording_test` 6/6,
  `check_readability.py`, `league_runner.gd -- 1` (56 games, the shape of
  the published table), `league_runner.gd -- 0` (green on nothing).
- Two probes -- a scene-style recording replayed, and a walker beside a
  point the enemy holds -- and 15 mutations, of which 11 survived.

## Findings

1. *high* -- a recording from the scene did not replay: it kept the board's
   seed at the end of the game, and every attack moves the seed on.
   Replayed, the board refused decision 229 of 500. The tests passed the
   starting seed in by hand, and the scene test never replayed its file.
2. *medium* -- a point the enemy stood on counted as free, and the walker
   sent to it held "no walk brings it nearer" every turn: three of the four
   teams could stand idle all game, round T45's never-idle rule.
3. *medium* -- `league_runner.gd -- 0` played no games and exited 0.
4. *medium* -- "every game ends", "no decision refused" and the work budget
   had no planted case, though the header said each did; the work budget
   held nothing in practice (only the planner and GOAP count worlds); the
   seat check re-checked the schedule, not the seats the runner used.
5. *medium* -- the intervals are differences from the rules, so overlap
   between two other teams is not a test, and the page's own rule
   contradicted its "three groups".
6. *low* -- GOAP leaves a siege it could strike for a fight it must walk to
   (hunt 1 against at least 3); at a tie the point wins. Neither said.
7. *low* -- `_read_prey` said "the cell nearest home" and takes the first
   found; the rules' "same question, same answer" is inherited by the
   machine and the HTN, which keep memory.
8. *low* -- "over 44,000 decisions" had no command behind it.
9. *low* -- `replans` said "replanning, not planning" and both counters
   count the first plan; `MeteredTeam` did not pass `work_done` or
   `replans` through.
10. *nit* -- doc comments that repeat the code in `MeteredTeam`; the planted
    unseeded team could, by luck, play one game twice.

Surviving mutations: the calm margin at 0, the strongest prey, the tree
hunting before a siege in reach, the MM weight, the interval's top as the
maximum, claims ignored, falling back to the most strikers, GOAP's siege
cost at 0, and a wait, an attack or the computer writing no row.

## What was done about them

- 1: the scene keeps the seed the game began with. A new test plays a scene
  game to its end -- blue's rules attack and win -- keeps the file, replays
  it and gets the same winner with nothing refused; planting the old seed
  back turns it red.
- 2: a point anyone else stands on is not free -- an enemy on it is a fight,
  which is a hunt -- and a walker with no walk nearer its point takes the
  rules' walk instead of holding. Tested on a board for the three teams.
- 3, 4: the runner asserts it played every game it scheduled, and more than
  none; seats are read off the teams that sat in them; the work budget is
  held for the teams that count worlds and the page says only those. Each
  assertion now has a planted case: a refusing team, an unended game, a
  league of none, a decision over 2000 worlds. The unrepeatable team
  differs by construction, not by luck.
- 5: the rating's header and the page say what an interval can say --
  told apart from the rules, or not -- and no more.
- 6, 7, 9, 10: said in the headers; the counters' contract reads "plans
  made, the first included"; `MeteredTeam` passes both through.
- 8: the runner prints each team's decision count, and the page quotes it.
- Mutations: tests for the margin, the weakest prey, the tree's siege, the
  claims and an enemy on a point, the fewest strikers, the MM fit against a
  hand-worked answer, GOAP's tie and its equal fixed prices, a wait's row
  and the computer's rows. Six of the survivors -- the margin, the strongest
  prey, claims ignored, the most strikers, the siege cost, the MM weight --
  and the two defects of findings 1 and 2 were planted again, and each now
  turns a test red. The tree's siege, a wait's row and the computer's rows
  have tests and were not planted again. The interval's top as the maximum, and an
  attack in the scene writing no row, still have no test of their own; the
  scene game above holds that a kept file has attacks in it, through the
  computer's rows.

The fixes changed how the teams play, so the league was run again and the
page and T25's record quote the new table. They were not reviewed again.
