# Review: wave/45-examples-that-are-fun

A planning wave. One fresh context reviewed it, in the main worktree, at
e29aa6a.

What it read: CLAUDE.md, T42, the two earlier planning records
(`games-people-already-know.md`, `43-an-evade-and-harder-levels.md`) for
form, the diff, T26, T30's references to T26, ADR 0008, STATUS, and the
code behind every line of the fun review: `main.gd` and
`skirmish_victory.gd` (the skirmish), `tactical_victory.gd`,
`rule_based_blue.gd`, `blue_controller.gd`, `tactical_scenario.gd`,
`tictactoe.gd`, `checkers.gd`, `stealth_room.gd`, `search_board.gd`,
`godot/test/search_properties.gd`, `fighting.gd`, `fight_rules.gd`
(`_winner`), `fight_clone_opponent.gd`, `cloned_player.gd`,
`learned_policy.gd`, `board_features.gd`, `unit_type.gd`,
`godot/test/opponent_levels.gd`, `data/cloning/win_rates.json`,
`next_wave.py`, `check_no_training.py`'s header, and the Makefile's
`demo-*` targets.

What it ran: `make wave-next` (T26, as intended); `python3
scripts/check_acceptance.py` (ok, 45 task files); every target of
`check-no-engine` one by one, plus `lint-disk-layout`: all exit 0 except
**`lint-docs-freshness`, which fails** (finding 1); `make test-python` (283
OK). `git diff --stat main..HEAD` touches only `docs/design/`, `tasks/T43`,
`tasks/T44` and `tasks/STATUS.md`, so the engine gates (`test-godot`,
`test-demo-overlays`, the property and replay runs) were not run. One probe,
in the scratchpad: a copy of `tasks/` and `docs/reviews/` with T40 marked
`done`, and `next_wave.py --dry-run` on it.

## What was reviewed

Commits 4153011 and e29aa6a: `docs/design/fun-review.md`,
`tasks/T43-a-fighting-ladder.md`,
`tasks/T44-the-learned-policy-plays-the-tactical-board.md`, and STATUS's
T42, T43, T44 rows and its wave 45 resuming section.

## Checked and true

- **The owner's decisions are recorded as given.** The board games (MENACE,
  checkers, the search demo, stealth) stay as they are; only the skirmish
  and the tactical board do not feel like games; picked T26 first, the
  skirmish folded into the tactical board over a capture-the-flag of its own
  and over the hold warning alone, and a fighting ladder. fun-review.md:67-80
  and STATUS's resuming section say this.
- **`make wave-next` picks T26** (`wave/45-combat-on-the-board`; the number
  becomes 46 once this record exists). T11, T12, T15 and T25 are blocked on
  T26 or on each other, T43 on T40 (finding 4), T44 on T26.
- `check_acceptance.py` passes: every acceptance block is a command.
- **True in the table:** MENACE is X and moves first, the player plays
  noughts, four ages (10 to 10,000), no score kept. Checkers: the person is
  red, white is minimax at depth 1-6, no tally. The search demo is a
  sandbox with four named boards, each with a promise check. Stealth is one
  room (`StealthRoom.default_room`), with an escaped/caught ending and no
  par. Tactical: blue walks at red's workshop, the win is provisional, and
  there is a 40-round draw. The skirmish has two units a side and the T41
  hold rule. The tactical map is written as rows of characters.
- `BlueController` does name "the learned policy T26 makes possible", and
  the `demo-skirmish` recipe's comment does say "Where the policy finally
  plays is T30's question: blue on the tactical board". T44 quotes it as
  what the target "says"; it is a Makefile comment, not the help text, but
  the words are there.
- `UnitType` (with the counter table) is in `ai_core`, so T44's features
  can be read by `ai_learning` without breaking invariant 2.
- T44 keeps invariant 6 (Python retrains; N4 already holds a fresh run of
  `weights.json`), and both new tasks keep the overlay (invariant 13).

## Findings

### Must fix

1. **`make check` is red: `docs/design/` is not a layer the freshness gate
   knows.** `python3 scripts/check_doc_freshness.py` exits 1:
   "design/fun-review.md: M15 in no declared layer -- move it under
   concepts/, godot/, local-llm/, howto/ or add the folder to
   EXEMPT_FOLDERS with a reason". `make wave-merge` runs `make check`, so
   this wave cannot be merged as it is. The commit's own claims never say
   the gate was run. *Reproduced.*
   *Fix:* either add `design` to `EXEMPT_FOLDERS` with a reason (a design
   record is dated, like `reviews/`), or give the page the front matter a
   layer needs and put it in that layer.

2. **"T26, as it stands" does not make the tactical board a game: in T26
   nothing gives blue an attack.** fun-review.md:50-52 and :73, and
   STATUS's resuming section. T26's steps are an `Attack` type, dice, the
   counter table, shared rules and vectors, a retrained model and the tower.
   None of them adds an attack decision to `BlueController`
   (`decide_build` and `decide_move` only, blue_controller.gd:27-32) or to
   `RuleBasedBlue`, which "walks into anything" (rule_based_blue.gd:38).
   T26's manual check sends the player's runner at a mortar. So after T26
   the player's pieces can be lost only to the bolt tower. That contradicts
   the review's own reason for picking it, "until a piece can be lost, no
   other tweak gives it stakes". T26 also leaves the provisional win in
   place. `tactical_victory.gd:3-9` says "When not to use it: once T26
   lands", and T26 has no step for what replaces it. T44 step 5 measures
   "learned against rules" in combat, which needs a rules blue that
   attacks. *Read, not run: T26 is not written.*
   *Fix:* in T26, add a step for blue's attack question (an
   `decide_attack` on `BlueController`, and the rule `RuleBasedBlue`
   answers it with) drawn before it is played, and a step deciding the win
   condition once combat exists. Add `make test-demo-overlays` to T26's
   acceptance. Or record that the owner's pick needs a further task, and
   name it.

### Should fix

3. **Both new acceptance sections pass on main today.** T43:30-36 and
   T44:38-45 list only `make test-godot`, `make test-demo-overlays` and
   `make test-python`, all green before a line of either task is written.
   The real criteria are "a suite ... named here when written". That
   phrase appears in no other task file. T18 rejected a `test -f` for
   exactly this reason ("passed on main"). Invariant 4's question, "does
   this pass on an empty scene?", is answered yes. *Checked: the commands
   are green at HEAD, and nothing in godot/ changed.*
   *Fix:* name the files now: e.g. `test -f godot/test/fight_ladder_test.gd`
   plus the cases it must hold, as T26 lists its suite. For T44, a `make`
   target for the learned-against-rules games with an exit code and a bar,
   and `python3 scripts/check_no_training.py`.

4. **T43 cannot "go in between": its prerequisite T40 is `wip` and waits on
   the owner's new fights.** T43:3 has `Prereqs: T37, T18, T40`, and
   STATUS:102 says "T43 can go in between, it needs nothing new".
   `next_wave.py` takes the first `todo` whose prerequisites are all
   `done`, so `make wave` never offers T43 while T40 is wip. The probe shows
   the other side too. With T40 marked done, `make wave-next` picks **T43
   before T26**, because T43's row sits above T26's, against "T26 first".
   *Reproduced (scratch copy).*
   *Fix:* decide which is meant. If the backdash and the retuned hard,
   both merged, are all T43 needs, drop T40 from its prerequisites. Then
   move T43's row below T26 (and T44) so the table's order is the owner's
   order.

5. **The ladder's last two rungs are weaker than the third.** T43:12 and
   fun-review.md:57-59. Hard beats a frozen copy of the owner's ghost 150 or
   more times in 200 (T40, `make test-opponent-levels`). Against medium,
   the ghosts win 60 and 66 times in 100 and the clone 49
   (`data/cloning/win_rates.json`). So after hard the ladder steps down,
   and the "final" opponent is about medium. The manual check asks whether
   "wanting the next rung is there". As written, the next rung is easier.
   *Read from committed numbers.*
   *Fix:* order the rungs by measured strength, or say the last rungs are
   a different kind of opponent (one that fights like a person) and not a
   harder one. Then let the owner choose. Also name which ghost: there are
   two, `ghost: exact` and `ghost: nearest`.

6. **T43 does not say how a match ends without a knockout.**
   T43:20-21: "the fight already ends in a winner". It ends only on a
   knockout. `FightRules._winner` (fight_rules.gd:416-424) also returns
   `FightState.DRAW` on a double knockout, and the game has no clock. The
   99-second `TIME_LIMIT` exists only in `godot/test/opponent_levels.gd:45`.
   A best of three needs a rule for a drawn round. A ladder against an
   opponent that guards needs a clock, or a rung can last for ever. A
   clone that failed to load does exactly that: "nothing it can do, so it
   guards" (fight_clone_opponent.gd:95-97).
   *Fix:* a step for a drawn round and a round clock, with cases in the
   suite.

7. **T43's reason for step 4 is wrong.** T43:24-25: "the owner's recordings
   are not committed everywhere". The ghosts and the clone read one file,
   `godot/addons/ai_learning/clone_weights.json`, which is tracked. So are
   the recordings under `data/fights/`, and the game does not read them.
   A missing file already does not crash: `ClonedPlayer` refuses with C1,
   and the opponent guards. The step is still worth having (someone copying
   the folders can lose the file), but the stated cause would send the
   implementer looking for an untracked path that does not exist.
   *Fix:* "if `clone_weights.json` is missing or refused
   (`ClonedPlayer.is_loaded()` false), skip the rung", which also closes
   the guard-for-ever case in 6.

8. **Two lines in the fun review contradict the code they describe.**
   - fun-review.md:30 says "nothing on screen warns the player it is
     close". The skirmish's status already prints "blue holds the node at
     (x, y): 2 of 3 turns" (`SkirmishVictory.progress`, main.gd:275-277).
     What is missing is a mark on the board itself, which is what item 6
     proposes. The table should say that.
   - fun-review.md:30 and :56: "no combat until T10", "Combat is T10". T10
     is done, and it deferred combat to T26 (ADR 0008, T10's STATUS row).
     The line comes from a stale comment, `skirmish_victory.gd:8`, which
     has the same mistake.
   *Fix:* "T26" in both places. Correct the comment when T44 touches the
   file, or delete it with the skirmish.

9. **T44 lets its implementer drop a lesson the README advertises.**
   T44:21-22: "say what replaces it, or drop it and say why". The capture
   model is the kit's only linear regression. README:23 lists it as half of
   `ai_learning` ("linear regression -- which target is closer to
   falling"), shown in `make demo-skirmish`. Removing the only place it is
   seen is the owner's call, not a commit message's. Step 4 also leaves
   T41's flag and contest rules to "the commit says which".
   *Fix:* bring both to the owner before T44 starts, or name a home for the
   capture model on the tactical board (e.g. "which red piece falls
   first").

10. **T44 repeats T26's retraining, and leaves a known routing bug out.**
    T26 step 4 already rebuilds `combat.py` from the game's rules and
    retrains. T44 step 2 does it again with different features (unit types,
    counter table), so it is a second dataset. Say so, and say whether
    T26's retrain is the four-feature model kept for comparison. STATUS's
    T11 row records "`ai_learning` still routes on `state.graph`, wrong for
    a wader". T44's walking "as the rules do" has to route by type, and it
    does not mention this.

### Could fix

11. fun-review.md:44-46. "`search_properties.gd` has never seen it happen
    in 300 boards" understates the claim. The file asserts that A\* never
    expands more than Dijkstra, and its header says why it **always**
    holds: Manhattan distance is consistent on cells costing at least one,
    and the search board's costs are 1 to 9. As a puzzle it cannot be
    solved. Not picked, so it costs nothing now. But the design record
    should not say it is open.
12. fun-review.md:31: "or their own ghost". The ghosts imitate the owner's
    recordings, through `clone_weights.json`. Another player meets the
    owner's ghost unless they record and run `make train-clone`.
    fun-review.md:54: "its own flag". Skirmish nodes belong to nobody.
13. fun-review.md:76-77: "the warning (6 above) goes with it" can be read
    as "is dropped with the skirmish" or as "comes along into T44". T44 has
    no step for it. Say which.
14. T44's Files misses what removing `demo-skirmish` touches: the
    `Makefile`, `scripts/check_demos.py`'s count of seven examples,
    `README.md` (lines 21, 23, 74, 124), `docs/godot/examples.md` and the
    learning pages. T43's misses the `Makefile`, whose `demo-fighting`
    help says "Training mode".
15. The wave 45 resuming section has no "Not proven" paragraph, which the
    earlier ones have. Here it would be: the fun review's lines were not
    checked by playing every example (the page says so), and the
    screenshots it cites were not committed.

## Not proven

- The screenshots of the search demo and the skirmish "taken on
  2026-10-17" (fun-review.md:17-18) are not in the repository. The lines
  that rest on them were checked against the code instead.
- That T44's learned blue can beat or match the rules once combat exists.
  Nothing can measure that before T26.
- The engine gates were not run, on the grounds that nothing under
  `godot/` changed.

## Verdict

**Not as is.** Finding 1 alone blocks the merge: `make check` fails on the
new page's folder. Finding 2 is the one that matters for the plan. The
owner picked T26 to give the tactical board stakes, but T26 as written lets
only the player attack, so it needs a step or a sibling task before it is
started. 3 to 7 are about the two new tasks being startable and checkable
as written. 8 to 10 correct the record.
