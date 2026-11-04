# T110 — The tactical game's news keeps its words as keys

Size: S · Prereqs: T104 · Files: `godot/game/tactical/`, `godot/test/tactical/`, `godot/locale/`, `docs/godot/localisation.md`

## Goal

T104 made the tactical match and the skirmish keep their AI's reasons as a
`Sentence` (`godot/game/sentence.gd`) -- the English key and its values --
worded where they are shown, so a language switched mid-turn rewords them.
It left one thing out, and said so in its pull request (#47): the news of
what was played. `TacticalCombat.told` ("the red runner at (3, 4) struck
the ..."), and `tactical.gd`'s `_last_event` -- "built {piece} at {cell};
it moves next turn", "{piece} waits at {cell}", "bought the forge", "taken
back", the points paid -- are still worded with `tr()` or
`TranslationServer.translate` when they happen. After a language switch
the news stays in the old language until the next event. The owner
decided on 2026-10-29 that the news follows the reasons.

## Decisions written down first

- **News is a `Sentence`, the same way as a reason.** `TacticalCombat.told`
  returns one; `_last_event` and the computer's news list keep sentences;
  a piece with its article and a side's name are nested sentences, as T104
  made them (`TacticalStatus.the_piece_sentence`, `a_piece_sentence`).
- **Worded where shown**, by `tactical.gd`, which already rebuilds the
  status on `NOTIFICATION_TRANSLATION_CHANGED`. The skirmish keeps no news of its
  own (`main.gd` names neither `told` nor `_last_event`); its towers fire
  through `turn_start.gd`, which this task reads too.
- **No table loses or gains a key's meaning**: the English keys stay the
  ones `godot/locale/tactical.csv` holds, unless the reading finds a key
  that must change shape (a list, a nested piece), as T104's `then` did.
- **The test switches language mid-turn**: an event happens in pt-BR, the
  locale goes to English before the next one, and the news on screen is
  English -- and back, both ways, for an attack, a build, a wait and a
  purchase.

## Steps

1. Read T104's record (`docs/reviews/108-the-tactical-ai-keeps-its-reasons-as-keys.md`
   and the body of PR #47), `sentence.gd`, `tactical_combat.gd`'s
   `told` and `towers_fire`, `turn_start.gd`, and every `_last_event` and
   news line in `tactical.gd`.
2. Make the news sentences; word them where shown.
3. The mid-turn switch test in `godot/test/tactical/`; the suites that
   read `_last_event` as a string (`tactical_combat_test.gd`,
   `leveled_blue_test.gd`) read its English.
4. `docs/godot/localisation.md`'s T104 section: the news is no longer the
   exception it names.

## Acceptance

```bash
python3 scripts/check_translations_game.py
make test-locale-screen
make test-demo-overlays
make test-godot-some SUITES="test/tactical test/skirmish"
python3 scripts/check_readability.py
```

## Manual check

In pt-BR, play a tactical match until the computer attacks and you build,
then switch to English before the next event: does the news line change
language at once?

## Done (wave 124) -- what the work decided, for the owner to confirm

- **One sentence a line.** `_last_event` is a list of sentences, one a
  line, not one sentence with the lines nested: a turn's opening says
  several things (the points paid, each tower's shot, the computer's
  attacks under "{side}'s attacks:"), and a joining key such as
  `"{first}\n{rest}"` would be one more shape-only key for nothing.
- **The XCOM-style mode too.** T85 merged after this task was written, and
  its shot's news (`SquadCombat.told`) went the same way, since it reaches
  the same `_last_event` through `TacticalRuleset.told`. That is outside
  the task's file list (`godot/game/squad/`, `godot/test/squad/`). Its
  turn opening says nothing, as before.
- **Two names added.** `TacticalStatus.side_word` gives a side's key
  ("red", "blue") as a value of a kept sentence; `side_name` now translates
  it. `TacticalGame.news_in_english()` is the news in English, for the
  suites that read `_last_event`.
- **No key changed**; `tactical.csv` and `squad.csv` are untouched.
- **What was measured.** `tactical_news_test.gd`: an attack, a build, a
  wait, the forge bought and a tower's shot, each in pt-BR then in
  English, the locale switched before the next event: the panel shows the
  new language and none of the old, then back again. With the news worded
  as it is kept (planted in `_tell`), the attack's case fails.
