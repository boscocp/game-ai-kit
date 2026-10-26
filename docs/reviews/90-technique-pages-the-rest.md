# Review: wave/90-technique-pages-the-rest

T75, as written. The twelve technique pages T74 left to write, each in T74's
shape, English beside pt-BR:

- the eight technique modules: `ai_adversarial`, `ai_fuzzy`, `ai_learning`,
  `ai_opponent`, `ai_perception`, `ai_planning`, `ai_rts_core`, `ai_teamwork`;
- the four techniques declared in `non_module_techniques.json`: MENACE, the
  learned checkers evaluation, behaviour cloning and the racing driver.

Each page has a minimal example, which is a file that a gdUnit case runs.
The eight modules' examples are in `godot/test/ai_*/`. The four non-module
ones are in the test folder of the module that owns their Godot half. The
wave also empties `STILL_TO_WRITE`, adds terms to the glossary, and links
each row of the README table to its page in both languages.

A fresh context reviewed PR #29 at head c0bb9c2.

**Verdict: merge after the should-fixes.** No blockers.

## What was reviewed

- Every API claim on the twelve pages against the addon code, class by
  class: constructors, argument types, typed arrays, what each method returns
  and when it refuses.
- Each page's demos against `modules/*.json` `depends_on`, and against what
  the demo's code actually uses.
- The twelve examples and their suites, by mutation, including the one
  wave 87 found for steering: does an example still work when its node is
  not at the origin?
- The gate's empty list, and the pt-BR pages against the glossary.

## Findings

1. **The racing example was not `ai_steering`'s seek** (should-fix). The
   page said it used seek, but the example wrote its own force with
   `RESPONSE = 10`, explained only in a comment. The cause:
   `Steering.towards_velocity` returns `desired - velocity`, and
   `SteeringVehicle.step` adds force × dt, so seek and arrive close the
   velocity gap with an implicit gain of 1 a second. Measured by mutation:
   - `RESPONSE = 1`: 1019 failures; the car leaves the ±30 band.
   - plain `SeekBehaviour` with the speed capped at the profile, no gain:
     the same failure.
   - `RESPONSE` 3 or 5: passes.
   - `SeekBehaviour` × `RESPONSE`: passes.
2. **The MENACE example resigned silently when moved** (should-fix).
   `MenacePlayer.load_published()` defaults to the game's path, so a copy
   placed elsewhere returned -1 on every move.
3. **The perception test could not see a local/global mix-up**
   (should-fix). Its guard was parented to a plain `Node`, where global and
   local positions are the same. With `position` swapped in for
   `global_position`, all four cases still passed.
4. **T75's acceptance left out four folders** (nit): `test/tictactoe`,
   `test/checkers`, `test/fighting`, `test/demo_racing`.
5. **"r = 0.89" had no source** (nit) on the learned-evaluation page.
6. **GRIP 300 disagreed with `max_force` 600** (nit) in the racing example,
   and nothing said which one was the limit.
7. **`settle(budget)` counts flood steps, not cells** (nit), both in the
   `ai_rts_core` knob row and in the example's `CELLS_PER_FRAME` comment
   (`flow_field.gd:30-32`).
8. **The wrong file was named as the weights loader** (nit). `ai_learning`
   named `learned_policy.gd`, but the loaders are `learned_blue.gd:111` and
   `main.gd`; `LearnedPolicy` is handed a `ModelFile`.
9. **The chosen move is pink, not blue** (nit) in checkers
   (`CHOSEN`, `checkers_view.gd:22`).
10. **The examples skipped the validation their pages recommend** (nit):
    - `ai_learning` defaulted a missing bias to 0, which `ModelFile`
      refuses;
    - `ai_fuzzy`'s `why()` crashed on an input that is not a number;
    - `ai_perception` and `ai_opponent` never called `problem()`.
11. **A STATUS follow-up was half stale** (nit). "Checkers uses none of
    `ai_learning`'s classes" no longer holds for its test folder.
12. **pt-BR wording** (nit):
    - "Path2D assado";
    - "retrato publicado";
    - the glossary's claim that nobody says "característica".

Together with the review, the owner asked (2026-10-26): code and doc
comments stay in English, only the documentation is in pt-BR, and the
English terms with no good translation go in a glossary that every pt-BR
page links.

## What was done about them

1. The racing example now uses `ai_steering`'s seek:
   `SeekBehaviour.new(aim).force(vehicle)` × `RESPONSE`, with
   `vehicle.max_speed` set to the profile's limit each frame.
   - The constant's comment and both pages' "What you implement" state the
     implicit gain of 1 a second and the measurement.
   - Re-measured: with `RESPONSE = 1`, 1019 failures; at 10, 4 of 4 pass.
   - STATUS gains a follow-up for a gain knob in `ai_steering`. The addon
     is unchanged in this wave.
2. The MENACE example has a `const BEADS` path, passes it to
   `load_published(BEADS)`, and has `has_beads()` so a game can say the file
   is missing. Both pages say where the file must sit. A new case checks
   both answers.
3. A new perception case puts the guard under a `Node2D` that is moved to
   (1000, 500) and turned a quarter. It sees what is below the parent and not
   what is to its right. With the local/global mutation applied, that case
   now fails (1 of 5).
4. The acceptance command lists all twelve folders.
5. Both languages cite the wave 33 review through
   `concepts/learned-evaluation.md`.
6. `TOP_SPEED`, `GRIP` and `BRAKING` are named for what they are: what the
   profile asks of the car. The comment says the car can do more
   (`max_force` 600), so the profile is the limit, and `grip_margin` is what
   the driver dares.
7. The constant is renamed `STEPS_PER_FRAME`, its comment says what a step
   is, and the knob row says the budget counts `FlowField.work`, in both
   languages.
8. Both pages name `main.gd` and `learned_blue.gd` as the loaders and
   `learned_policy.gd` as what they hand the file to.
9. Both languages: considered moves blue, the move it will play pink.
10. The examples now do what their pages say, each with a case where one
    was missing:
    - `model_from` refuses an entry with no bias;
    - `why()` answers `{}` and `alarm()` `NAN` for an input that is not a
      number;
    - the perception and opponent examples call `problem()` in `_ready`.
11. The STATUS clause is corrected: the checkers game uses none of
    `ai_learning`'s classes, and only its test folder does.
12. pt-BR wording:
    - "pré-calculado (*baked*)";
    - "versão publicada";
    - the glossary says "característica" and "atributo" are also used, and
      the kit keeps *feature* because it is the name in the code.

**The owner's request.**

- **(a) Every page opens the same way.** All sixteen pt-BR technique pages
  open, before their first section, with the same quoted line linking their
  English page and the glossary. They already did.
- **(b) A gate rule holds it.** `check_translations_docs.py` gains
  **D14**: a translation that does not open with that line, word for word,
  is a finding. Wrapping does not count; the quoted lines are joined before
  comparing.
  - Planted cases: the line missing, the line reworded, and the line moved
    below the first section, each rejected; the line wrapped elsewhere,
    passed.
  - Three mutants each fail the self-test: the comparison forced true, the
    stop at the first section removed, and the rule's call dropped.
- **(c) A hand sweep of the italics.** A script listed every italic term
  outside code on the sixteen pages that the glossary lacks. Seven entries
  were added: *docstring*, *softmax*, *shadow*, *baked*, *skirmish*, *easy*
  / *medium* / *hard*, and *wave*.
  - The rest were plurals of listed terms, book and article titles, and
    Portuguese emphasis.
  - The glossary now says so, and says that code and doc comments stay in
    English.
  - No gate for this: titles and emphasis are italic too, and a rule that
    could tell them apart would be the noisy one the owner did not want.

`translation_of` was recomputed after the English edits, and every example
was pasted into its pages again.

## What the reviewer found sound

- **API claims, class by class.** Constructors and their typed arguments
  were checked for every class the pages name: `FuzzySet` takes a
  `PackedFloat64Array` of three or four points, `StripsAction` takes three
  `PackedStringArray`, and `VisionCone.sees` takes a `GridGraph` and
  `Vector2i`. So were the return values: `PlanResult` tells done from
  impossible from out of budget, `ActionChoice.choose` answers -1 when
  nothing scores, and `predict_named` answers `NAN` for a missing feature.
  And so were the refusals: `ModelFile` M3-M10, `ClonedPlayer` C1-C7,
  `FuzzyRuleBase.problem` F1-F7.
- **Demos.** Every demo a page names comes from `depends_on`, and the code
  really uses the technique there. The one declared and not used
  (checkers → `ai_learning`) is said so on the page.
- **Wave 87's findings did not recur.**
  - No demo is named from memory.
  - The adapter types a reader must pass are stated: `GridGraph` for the
    flow field and the cone, a `Callable` for the line test, typed arrays
    for fuzzy.
  - The examples work anywhere: the racing car is placed off the line and
    away from the origin, and after finding 3 the perception guard sits
    under a moved, turned parent.
  - No example hands out a live internal reference.
  - Every example is a file run by a gdUnit case, and D9 holds the page
    equal to it.
- **Mutations killed.**
  - `RESPONSE = 1`: 1019 failures.
  - The perception guard reading local instead of global coordinates: 1
    failure, after finding 3.
  - Each of D14's three mutants: the self-test fails.
- **The findings of step 3** are written on the pages and in STATUS, not
  hidden behind long examples:
  - `ModelFile`'s tie to the tactical game's conventions;
  - `RtsWorld` and its rules being the kit's own RTS;
  - `RacingDriver` being tied to its track and its car.

## Run after the fixes

| command | result |
|---|---|
| `python3 scripts/check_translations_docs.py` | 0 |
| `python3 scripts/check_translations_docs.py --self-test` | ok |
| `python3 scripts/check_doc_freshness.py`, and its `--self-test` | 0 and ok |
| `python3 scripts/check_links.py` | 0 |
| `python3 scripts/check_readability.py` | 0 |
| `python3 scripts/check_tiers.py` | 0 |
| `python3 scripts/check_no_employer_refs.py` | 0 |
| `python3 scripts/check_no_training.py --skip-retrain` | no findings; exit 3, "retraining skipped" |
| `make lint-modules lint-tasks lint-status` | 0 |
| `make test-godot-some` over all twelve folders | 546 of 546, 40 suites |

The Godot run printed no `SCRIPT ERROR`. Its one engine `ERROR` line is an
existing planted case in `ai_planning`. `make check` was not run, on the
owner's instruction for this round.

Still the owner's: T75's manual check -- do two pt-BR pages read as written
for a Brazilian developer, and does each minimal example match what its demo
shows.
