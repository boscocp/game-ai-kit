# Review: wave/108-the-tactical-ai-keeps-its-reasons-as-keys

T104: every reason a tactical team gives, and the skirmish's learned
opponent's, is kept as a `Sentence` -- its English key and its values --
and worded where it is shown, as T80's review had the RTS and the fighting
game do. Before, T79 worded each reason with `tr()` when the team decided,
so what the AI kept, and the overlay `test-demo-overlays` reads, were in
the language on screen at that moment.

A fresh context reviewed PR #47 at head 6665f5e.

**Verdict: approve with should-fixes, no blocker.** Three should-fix
findings and five nits. Everything that called for a change was applied on
the branch.

## What was reviewed

The diff against main:

- `TacticalDecision`, `LearnedDecision` and every team that gives a reason:
  the rules, the planner, the difficulty levels, the learned policy, the
  state machine, the behaviour tree, GOAP and HTN;
- `TacticalStatus.said`, `word`, the article and list helpers, and
  `plan_lines(say)`;
- `LearnedPolicy.why_unusable` / `why_unusable_sentence`,
  `TacticalWeights.error_sentence`;
- the skirmish's panel, `PlanView.number_sentence`, the overlays;
- the tests, the pins dropped, `decision_scenarios.gd`, the CSV edits,
  `modules/league.json`, `docs/godot/localisation.md` and the STATUS row.

## What the reviewer found sound

- **The `Sentence` design.** A piece with its article is a nested sentence
  of its own key, so the article travels with the piece in Portuguese;
  `listed` and `in_order` word a list name by name. Nothing glues English
  grammar.
- **`plan_lines(say)`.** One function, the wording handed in: `said` for
  the status, `Sentence.english` for the overlay and the console.
- **`why_unusable` and `why_unusable_sentence`**: the English for the
  callers that compare it, the sentence for the screen.
  `error_sentence` keeps the W code and the source outside the key, as
  `error_shown` did.
- **Every caller updated**, the league's and the win-rate wrappers
  included; the recordings replay as before (they never held a reason).
- **The overlays are English** in any language, and `decision_scenarios`
  plays in each language with no pin.
- **The CSV edits** are the rows the change needs and no more.
- **The same seeds give the same games.** Against `origin/main`,
  `make tactical-win-rates GAMES=4` was byte-identical, and
  `make league SEEDS=1` identical but for its timings.
- **pt-BR reads naturally**, no raw key or placeholder. Samples rendered:
  "caçar depois sitiar", "constrói um aríete em (12, 0)", "ataca o escudo
  em (3, 7): p(vitória) 0.78, acima do limite de desistência 0.30".

## Findings

1. **The en/pt-BR equivalence test missed whole branches** (should-fix).
   A `tr()` planted inside both `Sentence.of(...)` calls of
   `TechniqueTeam._fall_back` left all of `test/tactical` green, in the
   default locale and with `LANG=pt_BR.UTF-8` (339 cases). The scene's game
   in `tactical_reasons_test.gd` has a red that never moves, so fall-back,
   defend, retreat and an HTN plan that "could no longer run" are never
   reached. Asked for: a red played by a controller, with the branches shown
   to be reached; and a cheap lint refusing a translation inside
   `Sentence.of(...)`, with a planted case.
2. **A stale example in `docs/godot/learning.md`** (should-fix).
   `print(decision.action, " ", decision.reason)` printed an English line;
   `reason` is an Array now, and the text below still called it "a
   sentence carrying the number".
3. **A leftover pin** (should-fix). `tactical_planner_test.gd` still pinned
   English with T79's comment; unpinned, it passes 22 of 22 in pt-BR.
4. **`TeamFacts.said()`** (nit) called `tr("nothing pressing")` at decision
   time and had no caller.
5. **Shape-only keys** (nit). `"{first}, {rest}"`, `"{step}: {reason}"`,
   `"{deed} -- {thinking}: {reason}"`, `"{code} {said}"`, `"{refusal}"`,
   `"{only}"` are deliberately not in the CSV; the docs should say so.
6. **`TacticalStatus.word` sends every string through the tables** (nit):
   plan steps, facts, GOAP goal names. "Anything else ... as it is" is true
   only while none of them is a key; a future key could collide.
7. **Left-outs to name** (nit): the state machine's arrows ("estado tomar
   o ponto, advance -> take point: ...") and GOAP's "objetivo pressure"
   stay English inside a pt-BR reason, as on main.
8. **`modules/league.json`** (nit): `tests_depend_on: game_shared` is
   honest; keep it.

## What was done about them

1. **Both.**
   - `tactical_reasons_test.gd` now has every roster controller play two
     whole seeded games against the rules, one in each seat, through a
     wrapper that writes down every decision's English and the plan's
     lines; the two languages must agree. It also fails unless some game
     gave a fall-back, a defence, a retreat and a broken HTN plan -- all
     four are reached. About 23 s.
   - Lint rule L9 in `check_translations_game.py` refuses a translation
     call inside `Sentence.of(...)`'s arguments, in every translated
     module; two planted cases (a key, a value) and a clean
     `Sentence.of` in the self-test. What it cannot see, a value translated
     through a variable or a helper, is said in its docstring and the docs.
   - The review's mutant -- `tr()` in `_fall_back`'s two sentences -- now
     fails the new test, and L9 names the line.
2. `learning.md` prints `decision.english()` and says how the reason is
   kept and worded.
3. The pin is gone; the suite passes with the engine started in pt-BR.
4. `TeamFacts.said()` is deleted, and its orphan row with it.
5. A "Keys that are only shape" bullet in `localisation.md`.
6. The doc says which strings are keys now, and that a step or fact that
   became a key of any table would be translated in every reason holding
   it.
7. Named in the docs' "Not in it" and in the PR's left-outs and manual
   check.
8. Kept.

## The reviewer's runs

- `make test-godot-some` over the tactical and skirmish suites: 374 cases,
  in the default locale and with `LANG=pt_BR.UTF-8`, 0 failures.
- `make test-decisions` in both languages; `make test-demo-overlays`;
  `make test-locale-screen`, 16 examples; the lints.
- Mutations: the overlay worded for the screen, caught; a pre-translated
  piece, caught; `tr()` in `_fall_back`, **not caught** -- finding 1.
- The branch against main: the numbers above, identical.

## Left out, with the reviewer's opinion

- **The news of what was played** (`TacticalCombat.told`, "built ...",
  points paid) is still worded when it happens and keeps its language
  until the next event. Acceptable -- it is the game's report, not a
  team's reason -- and worth a small follow-up.
- **The state machine's arrows** stay the addon's English string. Not a
  regression: main shows the same.
- **`TacticalCombat.why_refused`** still translates when called. The AI
  only compares it with LEGAL; acceptable.

## Open for the owner

Decided by the owner, 2026-10-29: as recommended -- `modules/league.json`
keeps `tests_depend_on: ["game_shared"]`. The manual check stays open.

- `modules/league.json`'s `tests_depend_on: game_shared`: the reviewer says
  keep it. It is a global path, so a wave touching it runs all of
  `make check`.
- The manual check in the PR: switch language mid-turn in both scenes.
