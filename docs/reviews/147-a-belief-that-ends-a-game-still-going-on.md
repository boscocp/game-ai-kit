# Review: wave/147-a-belief-that-ends-a-game-still-going-on

T134 looks for why `MctsSquad._chosen` crashed in wave 136's duel on a
board its side believed already won while the game seemed to go on. The
implementer found that the belief was right. The shot just played had
destroyed the other side's last piece, and `BlueTurn.play` asked the next
waiting piece (`_decide_next`) before the match loop checked for a winner.
The fix is two lines in `BlueTurn._decide_next`: nobody is asked once
`ruleset.winner(state)` names a winner. That holds in both modes.
`squad_game_over_test.gd` replays one recorded turn. The guard in
`SearchingSquad._begin` stays, with a corrected comment, and
`docs/godot/squad.md` gains a paragraph.

A fresh context reviewed PR #99 at head 6735bcc (merge base b45a20a) in a
throwaway detached worktree. It made no commit, push or PR comment.

**Verdict: changes requested. No blocker, four should-fix findings and
three nits.** The cause is right, and I reproduced it independently. The
fix is in the right place and changes nothing visible in Advance Wars
mode. The new test fails for the right reason without the fix. The gaps
are in what is written down and in what holds the change: no tactical
test covers it, the Files line is stale, and nothing gates "the guard's
reason is never seen in play".

## What was reviewed

- `CLAUDE.md` (invariants 3, 4, 11, 12 and 13, "Readable by a person",
  the traps), the task file, and the PR body with its 3 decisions.
- The diff against the merge base: `blue_turn.gd`, `searching_squad.gd`
  (guard comment), `squad_game_over_test.gd` and its `.uid`, the
  `expecti_squad_test.gd` doc line, `docs/godot/squad.md`,
  `tasks/STATUS.md`, and the task file.
- For context: `side_view.gd`, `SearchingSquad.believe` and
  `_guessed_enemies`, `squad_victory.gd`, `tactical_victory.gd`,
  `advance_wars_ruleset.gd`, `squad_ruleset.gd`, `squad_match.gd`,
  `tactical_match.gd`, and every use of `_computer_turn` in
  `tactical.gd`.

## What was run (green at 6735bcc unless stated)

- `make worktree-setup`, then `./scripts/godot --headless --path godot
  --import`. The import exited 139 near the end of the reimport. Every
  suite ran afterwards, and nothing in this PR adds a `class_name`, so I
  did not pursue it.
- `make test-godot-some SUITES="test/tactical test/squad"`: 464 cases, 0
  failures, no `SCRIPT ERROR`.
- `make test-godot-some SUITES="test/squad/squad_game_over_test.gd"`,
  three times: 1 case, green each time.
- **Fix reverted** (the two lines at `blue_turn.gd:102-103`): the new test
  fails. `asked_on.size()` is 6 against 2 at line 64, and 4 boards fail
  `winner == NOBODY` at line 66, each with winner 0 (red). That is the
  right reason. The fix was restored afterwards.
- `make test-squad-duel`: 30 position rows, 6 matches, 0 failures, no
  `SCRIPT ERROR`.
- `make lint-tasks lint-status lint-modules lint-readability` (with
  `pipefail`): exit 0. `scripts/affected.py --base origin/main` selects
  ai_planning, game_shared, league, menu, skirmish, squad and tactical. I
  ran only the tactical and squad suites from those.
- **An independent probe** (a scratch `-s` script, deleted afterwards):
  `SquadMatch.play` with `MctsSquad.new(seed, 400)` against
  `WeighedSquad`, seeds 1 to 6, both seats. `between` counted each time
  the searcher's pending decision carried the guard's reason. With the fix
  there were **0 firings in 12 matches**. Without the fix there were **3**,
  the same count the PR reports. All 12 winners were the same in both
  runs, so the fix changes no outcome, only the questions asked after
  the end.
- Hygiene: the PR has exactly the 8 intended files and no logs,
  `.user-data`, scratch files or other waves' files. The main checkout is
  on `main` and clean. There is one commit, authored by Adalberto Pereira,
  and neither it, the PR title nor the body carries a tooling byline. The
  branch is one commit behind `main` (b364e9f, T136). GitHub reports it
  as mergeable and clean.

## Answers to the brief

**Is the cause proven?** It is now, but by more than the PR shows. The
PR's evidence is a sample: 4 new firings (3 on counted budgets and 1 at
200 ms), each one after a winning shot. Wave 136's original 4 crashes ran
on the wall clock and cannot be replayed exactly, so "all 4 recorded
crashes" is not literally covered. The code closes the gap. A guessed
enemy can be missing from the belief only if it was seen once (it is in
`_known`) and has no `last_seen` entry now (`searching_squad.gd:320-332`).
`SideView.seen_by` drops a remembered id in two cases only
(`side_view.gd:44-50`, `_forget_the_destroyed`): when the enemy is seen
again, which puts it back in the view, or when it is no longer on the
real board. Never-seen enemies are guessed from `SquadScenario`'s fixed
roster, and the roster stays the same on built maps (T96 pins the
starts). So an enemy missing from the belief has been destroyed on the
real board. The guard's other branch, the round limit, reads
`turn_number`, which the view copies from the real board. So a belief
that says "won" means the real game is won. Fog cannot produce a false
"won", and neither can a piece believed dead but alive, or the clock. The
clock changes only which decisions are reached, not what the belief
holds. `_memory` and `_known` are cleared together in `begin_turn`, so a
reused controller is safe too. See finding 1.

**Is the fix in the right place?** Yes. Every caller of `BlueTurn`
(`tactical.gd`, `SquadMatch`, `TacticalMatch`, and the property and
recording tests) already checked the winner *between* plays. `play` asked
the next piece *inside* the call, so none of those checks could prevent
it. In the scene, `next` is read only through `_computer_thinking()` and
`step_decision`, and both test `winner == NOBODY` first
(`tactical.gd:405, 487, 760`). So in Advance Wars mode the turn order, the
end of the turn, the pink intent preview and the overlay are unchanged.
The only difference is that `RuleBasedBlue` is no longer asked a question
nobody reads. Replays and recordings are unchanged: the test/tactical
suites are green, including `tactical_recording_test`. Another benefit is
that a frame-spread search is no longer started on a finished board in
the scene's `_process`.

**Is the test deterministic?** Yes. It pins the board and the dice state,
and the controller is scripted, with no search and no clock. It was green
three times in a row and red with the fix reverted.

## Findings

1. **"In every case" reads as if wave 136's crashes were replayed
   (should-fix).** `docs/godot/squad.md:381-388`, the test header
   `godot/test/squad/squad_game_over_test.gd:3-9`, and the PR body
   ("In all 4 cases"). The four cases are wave 147's new firings. The
   four crashes of wave 136 ran on the wall clock and cannot be replayed.
   The claim is still true, but what proves it is the code, not the
   sample. Fix: say "the 4 firings wave 147 found", and add the argument
   from "Answers to the brief" to the page in two or three sentences: an
   enemy is left out of the belief only once `SideView` has seen it gone
   from the real board, so a believed win is a real one.

2. **Nothing in the tactical module holds the change (should-fix,
   invariant 4).** `godot/game/tactical/blue_turn.gd:102-103` is in the
   tactical module, and the header says it applies to both modes. Revert
   the two lines and `test/tactical` stays green, because only
   `test/squad` notices. Fix: add a case under `godot/test/tactical/` in
   which a blue attack destroys red's workshop while another blue walker
   is still waiting. Wrap `RuleBasedBlue` in a counting controller, as
   `ShootsTheLastPiece` does, and assert that `turn.finished()` is true
   right after that `play` and that nothing was asked on the won board.
   Then revert the fix once to confirm the case turns red.

3. **The task's Files line and decisions no longer describe the wave
   (should-fix).** `tasks/T134-a-belief-that-ends-a-game-still-going-on.md:3`
   still lists `side_view.gd` and omits `godot/game/tactical/blue_turn.gd`,
   where the fix is. The section "Decisions written down first" (lines
   20-25) still says the fix goes "in `believe`'s bookkeeping or in
   `SideView`'s memory". Fix: put `blue_turn.gd` on the Files line and
   drop `side_view.gd`, which is unchanged. Add a line under the
   decisions or in Notes saying that the state was made in `BlueTurn`,
   and that the owner is asked to confirm this (PR decision 1).

4. **"The guard's reason should never be seen in play" has no command
   (should-fix, invariant 3).** Task step 3 and `## Manual check`, and the
   PR's "Measured" section, which admits the runner cannot show it. My
   probe shows it can be measured cheaply: `SquadMatch.play`'s `between`
   sees the searcher's pending reason after every question. Fix: have
   `squad_duel_runner.gd` (or `SquadMatch`) count decisions whose reason
   is "believes no enemy is left, and holds", and report any count above 0
   as a failure. Plant `expecti_squad_test.gd`'s `BelievesNoEnemy` as the
   case it must reject. If the owner prefers to keep this wave small, open
   it as a follow-up task, and say so in the task's Notes.

5. **The recorded dice state is unexplained (nit).**
   `godot/test/squad/squad_game_over_test.gd:8,19`. The header says "dice
   seed 4", but the board is given `RECORDED_DICE = 190567314`. A reader
   cannot tell how one becomes the other. Fix: one comment line saying
   this is `dice_seed` as it stood at turn 16 of the seed-4 match, with
   red as MCTS at 400 iterations, so someone could record it again.

6. **"it" in the guard's comment (nit).**
   `godot/game/squad/searching_squad.gd:251-252`: "since T134 it asks
   nobody". The "it" is `BlueTurn`, but the sentence's subject so far was
   the searcher. Fix: "since T134 `BlueTurn` asks nobody once a game is
   over".

7. **One commit behind `main` (nit).** b364e9f (T136) landed after the
   branch was cut. GitHub reports it mergeable and clean. Rebase, then
   rerun `make lint-status` before `make wave-merge`, since both waves
   edit `tasks/STATUS.md` rows next to each other.

## What was done about them

Applied on the same branch, rebased on origin/main at b364e9f (T136).

1. **Fixed.** `docs/godot/squad.md` and the test's header now say "the 4 firings wave 147 found", note that wave 136's crashes cannot be replayed, and give the structural argument (an enemy leaves the belief only once `SideView` has seen it gone from the real board; the round limit reads the real turn number). The PR body says the same.
2. **Fixed.** `tactical_combat_test.gd` gains `test_once_the_workshop_falls_nobody_is_asked_about_the_won_game`: `RuleBasedBlue`, wrapped to count questions on a won board, takes red's workshop with walkers still waiting. With the two lines reverted it fails at line 180, 4 questions asked on a won board, against 0.
3. **Fixed.** The task's Files line names `blue_turn.gd` and the tactical test, and drops `side_view.gd`. A new line under "Decisions written down first" says the decision changed and asks the owner to confirm it.
4. **Fixed, in this wave.** `SearchingSquad` counts the questions it held on a game it believed over (`held_on_a_game_over`). `SquadDuel.match_row` puts both searchers' count in the row as `held`, the runner uses it, and `wrong_match` fails a row whose count is above 0. Both make targets already run the runner through `scripts/godot_checked.py`. `squad_duel_test.gd` plants `BelievesNoEnemy` in a whole match and checks that `wrong_match` refuses it, and checks that a sound MCTS match counts 0.
5. **Fixed.** A comment beside `RECORDED_DICE` says it is `dice_seed` as it stood at the shot, on turn 16 of the match begun on dice seed 4, and how to record it again.
6. **Fixed.** The comment now reads "since T134 `BlueTurn` asks nobody once a game is over".
7. **Fixed.** Rebased on b364e9f. `make lint-status` is green after the rebase.
