# Review: wave/188-main-green-t165-done

PR #147. It marks T117's `push_error` in `godot/game/squad/mcts_squad.gd:122`
`# not shown: for the log`, so `lint-translations-game` passes again on
main; marks T165 `done` in `tasks/STATUS.md` after the owner's manual
check; and words one coin as one in the valley merchant's line, with a
pt-BR row in `godot/locale/valley.csv`, the regenerated
`valley.pt_BR.translation`, and `test_one_coin_is_worded_as_one`.

A fresh context reviewed the branch's head (`7ccc16c`) against
`origin/main`, in a throwaway worktree that was removed afterwards.

**Verdict: correct, merge after two small edits (findings 1 and 2). No
blocker.**

## What was reviewed

- **Main's red.** `gh run view --log-failed` on main's last run (#146):
  the only failure printed is L1 on `mcts_squad.gd:122`, in
  `lint-translations-game`. The marker matches the repository's: the
  maze's three `push_error` lines (`maze_rules.gd:126`,
  `mdp_pac_man.gd:65`, `:190`) carry exactly `# not shown: for the log`.
  `check_translations_game.py` exits 0 on the branch.
- **The singular key reaches pt-BR.** The valley table is wired as every
  other: `res://locale/valley.pt_BR.translation` is in `project.godot`'s
  list, and the `.translation` is committed (`.gitignore`, T78).
  Re-importing the branch from scratch (`--import`, fresh `.godot/`) wrote
  a byte-identical `valley.pt_BR.translation`: the committed one is
  current. A probe script with `TranslationServer.set_locale("pt_BR")`
  printed `pede 1 moeda, 2 de costume` for 1 and `pede 2 moedas` /
  `pede 5 moedas` / `pede 0 moedas` for 2, 5, 0.
- **The test against a plant.** `make test-godot-some SUITES="test/valley"`:
  36 cases, 0 failures. With `valley_panel.gd` restored to main's,
  `test_one_coin_is_worded_as_one` fails at line 224 (`asks 1 coin, 2 as
  a rule` not contained), 1 failure. With the new CSV row deleted,
  `check_translations_game.py` refuses with L2 and exit 1.
- **Other "{n} coins".** Only `manner_words` formats a count of coins.
  The greetings in `manners.json` ("Four coins across", "A loaf for a
  coin", "Two coins a loaf") are authored per rule and already agree
  with their number; `{usual}` carries no unit. The ferryman's prices are
  8, 2, 4 and never 1.
- **The STATUS row and the PR body**, against the commit message and
  T165's `## Manual check`.
- **The PR's CI**: `gates` passed; `python` and `godot` were pending at
  review time.

## Findings

1. **STATUS's resuming section still says T165 is waiting.** Under
   "Waiting for the owner", "T165's manual check ... (T165 stays `wip`
   until then)"; under "Next", "Main's `make check` first" and "T166: its
   prereq T165 is built and merged but `wip` until the owner's manual
   check ... whether to wait for it is the owner's call; ask." Only the
   table row was changed, so the next session's prompt contradicts it.
   Drop the T165 bullet, and say T166 is unblocked and main is green
   (after this PR's CI).
2. **The test says "in either language" and checks only English.** Its
   comment reads "one coin is worded as one, in either language", but it
   never sets a locale, so the pt-BR wording the owner saw is held only
   by the CSV row and L2, not by a test: a pt-BR cell typed as "pede
   {price} moedas" would pass both. Five suites already switch to
   `pt_BR` and back (`rts_words_test.gd`, `fight_words_test.gd`, ...);
   either assert `pede 1 moeda,` there, or drop "in either language".
3. **Note, not for this PR: main's CI hid what came after.** `make`
   stops at the first failing target, so on main #144-#146 nothing after
   `lint-translations-game` ran in CI. This PR's `check-affected`
   (squad, valley, menu, locale) covers T117's modules, so the risk is
   small; the first green main run after merge is the real confirmation.
4. **Nit.** The STATUS row says the bridge was "pulled down"; T165's
   manual check says "burn". Both are fine if the game has both deeds;
   the row could name the deed the save recorded, for the next reader.
5. **Note, pre-existing.** With no bread the merchant still "asks 0
   coins, 2 as a rule" -- grammatical in both languages, but the
   greeting says there is nothing to price. Not this PR's.

## What was done about them

1. The resuming section no longer lists T165 as waiting; "Next" records
   wave 188, the owner's four decisions of 2026-11-11 and the order of
   the waves that follow.
2. The test now switches to pt_BR and asserts "pede 1 moeda, 2 de
   costume" and "pede 2 moedas, 2 de costume", then back to en.
3. Noted: the first green CI run on main after this merge is the
   confirmation; nothing to change on the branch.
4. The STATUS row says the task's word was burn and the bridge's deed is
   pull_down.
5. Pre-existing ("asks 0 coins" with no bread): left as a follow-up, not
   this wave's.
