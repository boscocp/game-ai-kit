# Review: wave/103-utility-choice-as-its-own-addon

T101: `ActionChoice` and `ErrandChoice` leave `ai_teamwork` for a new
addon, `ai_utility`, with their Python twins, their 21 vectors, their
refusal test and the fighter example. `ai_teamwork`'s page gains a minimal
example of its own. `AimChoice` and `PassageChoice` stay.

A fresh context reviewed PR #43 at head b792f30.

**Verdict: approve after two should-fixes, no blockers.** Two should-fix
findings and five nits. Every one was applied on the branch, after a rebase
onto main at 27709d0 (T86).

## What was reviewed

The diff against main:

- the moved addon files and their `.uid`s, and what is left in
  `ai_teamwork`;
- the Python packages, the split `derive.py` and both vector folders;
- the Godot and Python test suites of both addons, and the bot match's one
  changed test path;
- the manifests, the Makefile target and the regenerated catalogue;
- the technique pages in both languages, the literature table, the task
  file and the STATUS row.

## What the reviewer measured

- **Same seeds, same results.** On origin/main 4d73707 and on the branch:
  - `make test-botmatch-effects` (187 matches, 12 shards) printed the same
    lines but for the wall-clock ones;
  - `make test-infiltration` and `make test-infiltration-properties`
    printed byte-identical output.
- **The vectors moved, not changed.** Main's old teamwork `derive.py`
  writes 60 files; `diff -r` finds them equal to the union of what the two
  new `derive.py` files write.
- **The moved scripts are the same blobs.** `action_choice.gd`,
  `errand_choice.gd` and their `.uid`s keep the git blobs 957ae27, e797ab4,
  4c43287 and 1c28927.
- **The uids hold.** A fresh import with no `godot/.godot` leaves git
  clean.
- **Invariant 2 holds both ways.** A planted use of `ai_utility` in
  `ai_teamwork`, and of `ai_teamwork` in `ai_utility`, each fires A2
  (`check_addon_deps.py`) and M3 and M5 (`check_modules.py`).
- **The selector is right.** `affected.py`'s selections were checked: all
  of `make check` for this diff, because the Makefile and the manifests
  are global.
- **The manual check.** A blank Godot project holding only
  `addons/ai_utility/` and the fighter example ran it, exit 0: someone who
  wants only scored choice copies one folder.
- **Docstrings were reworded** (`gameaikit/teamwork/__init__.py`,
  `gameaikit/utility/__init__.py` and `spec/vectors/utility/derive.py`)
  because `check_modules.py` read a module path inside them as a
  dependency. The reviewer judged it an honest dodge of a false positive:
  the words named a history, not a use.

## Findings

1. **The bot match's card named no utility technique (should-fix).**
   `godot/menu/catalogue.json`'s `demo-botmatch` card listed no
   `weighed-actions`, so the regenerated catalogue and READMEs printed a
   bare "● ai_utility" for the bot match. Its panel does show every
   action's and errand's score (`botmatch_lines.gd`'s `action_line` and
   `errand_line`, from `match_bot.gd`'s `ActionChoice.choose`).
2. **`teaches: ways-to-decide` was satisfied in name only (should-fix).**
   `docs/concepts/ways-to-decide.md` never mentions utility. The tier-1 page
   that teaches it is `docs/concepts/shooter-ai.md`, whose T67 section is
   the utility choice. The page's "Deeper" link also called
   ways-to-decide "the four other ways to decide", as if utility were the
   fifth on that page.
3. **Nits.**
   - `spec/vectors/teamwork/README.md`'s file table had 32 rows for 39
     files: the T68 hiding vector and T70's search and roles vectors were
     never listed, and the kinds table lacked `search` and `roles`.
   - `ai_teamwork`'s page said `PassageChoice` weighs "how to get past a
     teammate"; it weighs getting past any body, and asking a teammate is
     one of its four ways.
   - `squad_example_test.gd`'s `_fighter(name: String, ...)` shadowed
     `Node.name`.
   - `docs/concepts/shooter-ai.md` and `docs/godot/botmatch.md` name the
     two classes without saying where they now live.
   - `AimChoice`'s home is an open question nothing tracks.

## What was done about them

1. The bot match's card gained `weighed-actions`: "the panel: every
   action, posture and pace the watched bot weighed, each with its score,
   the one taken marked, and each errand as its gain less its costs (V
   shows it while you play a bot)". Reading `botmatch.gd` showed the panel
   lists them whenever a bot is watched, and **V** shows them while a
   person plays; the `ai_utility` page said V showed them while watching,
   and now says what the code does. Catalogue and READMEs regenerated;
   `check_demos.py` and `catalogue.py --check` pass.
2. Both `ai_utility` pages say `teaches: shooter-ai`. The "Deeper" list
   links shooter-ai.md's section *The bot as an agent* for why a utility
   choice replaced a priority list, and describes ways-to-decide.md as the
   four ways the kit compared before utility. `translation_of` recomputed.
3. The nits:
   - The teamwork README lists all 39 files ("The thirty-nine") and has
     rows for the `search` and `roles` kinds.
   - Both `ai_teamwork` pages say `PassageChoice` weighs getting past a
     body in the way: wait, go round, ask a teammate, or another spot.
   - The parameter is `fighter_name`.
   - shooter-ai.md and botmatch.md say "`ai_utility`" at the first mention
     of each class.
   - T64's task file records `AimChoice`'s home as still open, for the
     owner to choose before the library ships.

## The owner's decisions, with the reviewer's opinion

- **`AimChoice` stays in `ai_teamwork`.** Agree: it is a shooter's hit
  model, not the scored choice B.6 names. Where it belongs is tracked in
  T64.
- **`PassageChoice` stays.** Agree: half of it is a teammate weighing a
  request.
- **The name `ai_utility`.** Good: it says what the folder holds.
- **Tier 2 on the pages.** Correct: both demos are 3D.
- **`squad_example.gd`.** Acceptable, not a token: it is the smallest
  runnable use of `RoleArbiter` and shows its one rule that matters,
  someone always shoots.
