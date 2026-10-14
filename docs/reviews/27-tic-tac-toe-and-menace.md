# Review: wave/27-tic-tac-toe-and-menace

Two fresh contexts reviewed it, each in its own git worktree. One read the
Python, the GDScript twin, the gate and the vectors, measured the strength
criterion over ten seeds, and ran forty mutations across both languages. The
other never read the code: it played the scene through screenshots against
the 10-game and the 10,000-game machine.

## What was reviewed

Commit 3af744d on this branch:
- `python/gameaikit/menace/`: the board and its symmetries, the matchboxes,
  the two opponents, training, and the report that publishes the beads;
- `godot/game/tictactoe/`: the board's twin, the bead player, the solver, the
  scene, its view and its panel, and `menace_beads.json`;
- N5 and N6 in `scripts/check_no_training.py`, `spec/vectors/menace/`, the
  tests on both sides, and `docs/concepts/menace.md`;
- the change to the strength criterion, made by the owner during the wave.

## Findings

### Must fix

- **The new strength criterion was measured on one seed.** The owner chose
  it on the strength of the published seed. Over ten seeds:
  - against perfect play the 10,000-game machine loses nothing on nine, and
    on the tenth a box drains and it resigns all 1,000 games;
  - "a tenth as often against a random player" held on six seeds of ten.

  The concept page's explanation was wrong at both ends. "A trap move that
  wins four in five" had never been measured: the real case is a move that
  wins three in four, locked in over one that wins every time. And the top of
  "0 to 77 losses" was resignations, not traps.
- **N5 missed the bead store this code actually has.** The beads lived in
  `_snapshots[age][box][square]`. `player._snapshots[10][box][4] += 100`
  passed the gate and changed the bead. So did twenty other spellings, among
  them:
  - other names, such as `counts[square] += 1`;
  - replacing or clearing a box;
  - anything after `var x := 0;` on the same line;
  - writing the bead file itself.

  A packed array returned by `beads_for` was the stored one, so a copy
  written to changed MENACE.
- **The vectors did not pin the symmetry order where two turns tie.**
  Swapping the two quarter turns in the GDScript table alone left everything
  green, and the two languages then played different squares.
- **The panel lied in three states:**
  - after the age was changed, it named a square the new box would not give;
  - on the forced last move it reported a draw from a box of zero beads;
  - after a win it showed the finished board's empty "box".
- **From the play review:**
  - "drew 0.70 of the way along its beads" could not be checked, because the
    list was sorted best first and the beads are counted out by square;
  - "perfect play would take the top left" on an empty board where every
    square draws made MENACE's centre look wrong;
  - in a lost position it recommended a move that did not even block;
  - "perfect play" sometimes framed a square that showed only "same move as".

### Could be better

- No winning line drawn; the perfect-play line stale after a game ended; the
  M overlay not saying whose result it shows; a box about to resign looking
  like any other; "0%" for 45 beads; "same move as" never explained; "1
  beads"; "10000" beside "10,000".
- Starting beads beyond the first box, resignation as a loss in training and
  when measuring, the favourite's tie-break, and the GDScript forced move were
  held by nothing, or only by N6.
- `train.py` said N5 for N6; the loss rate was quoted three different ways.

## What was done about them

Fixed on this branch:

- **The criterion, and what the page says about it.**
  - `python3 -m gameaikit.menace.report --seeds 10` prints the ten-seed
    table, and the page quotes it, the drained box and the lock-in included.
    The lock-in was re-measured before it was written: in the published
    machine's box, 191 beads sit on a move that wins 75% against a random
    player, and 56 on one that wins 100%.
  - "A tenth as often" became "fewer", which holds on all ten seeds.
  - The task file records the change and why.
  - The tests say they hold the published seed, and point at the table.
- **The beads are read-only in the engine.** Every box is a read-only
  `Array[int]` inside read-only Dictionaries. Measured on 4.7.2, any write --
  an index, `+=`, a copy of the reference, a replaced box, `clear()` -- is
  refused and changes nothing. A test holds that every level is read-only.
- **N5 rewritten.**
  - Two meshes: `bead` anywhere; `bead`, `box`, `snapshot` and `count`
    inside the noughts-and-crosses game.
  - Searched statement by statement, so `;` and one-line `if` are seen.
  - `obj.set("_snapshots", ...)` is read off the raw line.
  - N2 refuses writing the bead file.
  - Every evasion the review listed is a planted case. So are the reads
    that must stay legal.
- **A fourth vector**, `two-turns-tie.json`. The quarter-turn swap now fails
  it in GDScript and in Python.
- **The panel.**
  - Beads are listed in the order they are counted out, each move with its
    run of bead numbers. The draw is reported as "bead 12 of 26", and a test
    checks that the bead is in the run of the square played.
  - The last draw is shown only beside the box and the age it came from.
  - A forced move says "forced". A finished game shows the box it was drawn
    from, and no perfect-play line.
  - Perfect play names every best square, or says "every move draws" when
    they all do, and says for whom. The frames follow.
- **The rest.**
  - A winning line is drawn.
  - The status warns before an empty box resigns.
  - Small chances read "<1%", and "1 bead" is singular.
  - The legend explains "same move as".
  - Tests now cover the starting beads, resignation in training and when
    measuring, the tie-break, the draw's end, the forced move, beads on a
    turned board, and the legend and panel fitting the screen.

Mutations re-run after the fixes:
- the quarter-turn swap (vectors);
- `squares_for` not mapped to the real board (gdUnit);
- starting beads, the tie-break, and the draw's fallback (Python tests).

Every N5 evasion listed in the review is now a planted case it rejects.

Not fixed, on purpose:
- **Michie's rules themselves.** The lock-in and the drained box are what
  his machine does. The page explains both, and the owner chose to keep it.
- **A rule that cannot be evaded.** N5 is a net for spellings. The guarantee
  is the read-only store, and the gate says so.

The fixes were not re-reviewed by a third context. They were re-screenshotted
and every gate is green.
