# Review: wave/94-real-time-demos-speak-portuguese

A fresh context reviewed T80 at b01b1b0 (PR #35). That head held tables
for seven more modules (demo_steering, demo_racing, racing3d, botmatch,
infiltration, rts, fighting), the demos through `tr()`, the name classes
(`BotMatchWords`, `InfiltrationWords`, `RtsWords`, `FightWords`), the
shape matchers (`RtsRefusal`, `FightWords.event`, `InfiltrationWords.eye`),
`Language.decimal`, the width check in `test-locale-screen`, and the line
number fix in `check_translations_game.py`.

**Verdict: no blockers; three should-fix and nits, applied before the
merge.**

## Findings

1. **The event test saw only the events the recorded fights make**
   (should-fix, invariant 4). `fight_words_test` replayed `data/fights/`
   and held each event it found to a shape. Three rewordings in
   `fight_rules.gd` left it green:
   - "the throws clash and both break";
   - "p%d cancels %s into %s";
   - " (caught evading, which cannot guard)".

   Only "(caught starting up)" was caught.
2. **The RTS and fighting AIs translated at decision time** (should-fix).
   - Where: `FocusFire._why`, the queues' and reflexes' wishes, the
     commander's wishes, the fighting opponents' `choice`, the learner's
     expectation, the clone's `found`.
   - The AI's state depended on the language on screen.
   - `fight_opponent_test` read the drawn option through the translated
     `choice`, which worked only because it pinned English.
   - `decision_overlay()` carried the language of the moment, although
     `BotMatchLines` says overlays keep English, and `squad.gd` keeps its
     reasons as keys.
   - The owner's rule: code and identifiers stay English, the prose is
     translated where it is shown.
3. **Known gaps had no task** (should-fix):
   - the tactical header running off the window in English;
   - the pad legend line;
   - the tactical AI, if it does the same as 2.
4. **Nits:**
   - Holes in the name lists:
     - `fight_words_test` did not hold `FightOpponent.LEVELS`,
       `FightCloneOpponent.SOURCES` or "(anything)";
     - `infiltration_words_test` made three eye reasons and did not hold
       the count;
     - `IN_ZONE_RE` dropped a zone name with a space.
   - `_past_the_edge`'s docstring did not say what it does not measure.
   - `_provoke_an_rts_refusal` passed with no worker (id -1 is refused
     anyway).
   - The 191 boilerplate markers did not say which case applied.
   - pt-BR:
     - "o lutador que ela tem menos";
     - "na zona longe";
     - the search help's "chão" against "terreno aberto";
     - "3 trabalhador".
   - `rts_refusal.gd`'s example did not match its table.
   - The squad news in the RTS overlay carried an unformatted `{size}`.
   - English got clumsier to dodge Portuguese gender: "rule: the fewest of
     its fighters, runner", "needs this first: lab", "blue team: claims
     on".

Sound, by the reviewer's reading:
- The AI's behaviour is unchanged. Logic files changed only in comments,
  and the seeded results are the same: the RTS match digest
  d306bfcebf9809ba, the replay 1078 frames with 0 differences.
- Every committed `.translation` is fresh against its CSV.
- T78's and T79's review findings did not recur.

## What was done about them

1. **The event test reads the sources.**
   - `test_every_event_the_rules_can_write_reads_in_portuguese` reads every
     whole event `fight_rules.gd` appends. It writes each verb with each
     reason in brackets (the height reasons once per height) and each miss
     `fight_boxes.gd` writes.
   - It fails an event shown unchanged, or one whose bracketed reason is
     still English.
   - The three rewordings each fail now. The cancel survived at first: a
     value could take several words, so "jab straight" matched `{from}`.
     A value is now one word with no bracket, and the mutant fails.
2. **The AIs keep keys, not words.**
   - `Sentence` (`godot/game/sentence.gd`, `game_shared`) is
     `[key, values]`. `english` writes it for logs, tests and overlays;
     `translated` writes it for the screen, wording identifiers with the
     demo's `word`.
   - The RTS keeps sentences:
     - the queue's wishes and `waiting_for`;
     - a focus's why, now one key per case instead of joined clauses;
     - a squad's news, formatted with its size.
   - `RtsThinking` words them.
   - The fighting opponents are back to their English `choice` and
     `found`, as on main. Beside them they keep identifiers: `drawn`,
     `late`, `came_out_as`, `struck_with`, `stepped_in`, `found_said`,
     `guards_instead`. `FightingPanel._drew` words them.
   - `fight_opponent_test` reads `drawn`.
   - `docs/godot/localisation.md` replaces the "T79 precedent" line.
     Tactical has the same shape, so T104 covers it.
3. **Tasks:**
   - T102: the tactical header and status fit the window, and
     `NOT_YET_FITTED` goes.
   - T103: the pad legend line speaks Portuguese.
   - T104: the tactical AI keeps its reasons as keys.

   Each has a row in STATUS.
4. **Nits:**
   - `fight_words_test` holds the levels, the clone's sources and
     "(anything)".
   - `infiltration_words_test` holds the number of reasons the addon
     writes against what it makes, and every zone's "in" reason.
   - `IN_ZONE_RE` is `^in (.+)$`.
   - The docstring says Buttons, Label3D, `draw_string` HUDs and toggled
     panels are not measured.
   - The RTS refusal fails when no worker exists.
   - The markers say which case applies: an identifier, the digest's
     English worded by `FightWords.event`, the digest's notation, a mode or
     action shown through `FightWords`, the overlay's English, a data
     refusal.
   - pt-BR:
     - the rule is "regra: menos corredores" (one key per fighter);
     - "far" is "distante";
     - the search help says "terreno aberto" (the help line drops its
       double spaces to fit);
     - counts take `RtsWords.counted` ("3 trabalhadores", "3 workers").
   - The refusal's example matches its table.
   - **English restored**:
     - per-fighter keys give "rule: fewest runners" and "goal met: more
       runners", main's English;
     - article phrases from `RtsWords` give "needs a lab first", "select a
       building that trains a runner", "click to build the lab", "a worker
       is on its way to mend the tower", "click open ground to put the
       barracks", each with a Portuguese phrase of the right gender;
     - the bot match's switches have a key per team ("blue: claims on").
   - **Left for the owner**:
     - the bot match's watched line says "(blue team)" in English, since
       checkers' "red" holds the plain key;
     - the RTS refusals keep their nouns bare in pt-BR ("laboratório:
       antes é preciso quartel"), because the English shapes put "a"
       before each placeholder.

Re-run after the fixes, under `LANG=en_US.UTF-8` and `LANG=pt_BR.UTF-8`:

| Command | Result |
|---|---|
| `check_translations_game.py` | 0 |
| `check_translations_game.py --self-test` | ok |
| `make test-locale-screen` | 15 examples, 0 failures |
| `make test-demo-overlays` | 14 examples in en and in pt_BR, 0 failures; the `free` SCRIPT ERRORs are the planted crash |
| `make test-godot-some SUITES="test/locale test/rts test/fighting test/botmatch test/infiltration"` | 307 cases, 0 failures, no SCRIPT ERROR |
| `make test-replay`, `test-rts-match`, `test-rts-budget`, `test-opponent-levels`, `test-opponent-properties` | green; RTS digest d306bfcebf9809ba, replay 1078 frames, 0 differences |
| `check_readability.py`, `make lint-modules lint-tasks lint-status`, `catalogue.py --check` | green |
