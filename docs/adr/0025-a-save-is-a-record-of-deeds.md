# 0025 — A save is a record of deeds, not a model of the player

Status: accepted · 2026-11-11 (T163, wave 171; the owner accepted it with
the recommended decisions on 2026-11-11, "segue com o recomendado").
Amends ADR 0016 and ADR 0022.

## Context

Every example in the kit forgets when it closes. ADR 0016 lets three
components count during play -- the n-gram opponent (N9), the bandit
(N13), the bot match's player model (N14) -- and refuses "any count that
survives the fight". N14 refuses a player model read back from `user://`,
because a profile outlives the match.

On 2026-11-10 the owner asked for a karma system: the player's deeds have a
visible effect on the world and its people, and they persist between
sessions like a save. From a research brief the owner chose this design:
the valley remembers what the player did to **places**, and the player's
standing, read from those deeds, sets prices and doors. It has no combat
and no opponent, and it is 2D and turn-based (T164-T166).

So something must survive between sessions for the first time. This record
says exactly what, before any code that uses it.

## Decision

**The rule.**

> Only a record of deeds may persist between sessions. The record is
> appended to and never edited, it has a schema version, and one class of
> the example writes it. Nothing derived is saved. The world is rebuilt
> each session by applying the record, in order, to fixed, authored rules,
> and a test rebuilds it twice and compares. The player's standing is a
> sum of fixed, authored weights over the deeds: the weights never change,
> and its value changes only when a deed is added. It is rebuilt from the
> record, never saved, never fitted to the player, never an estimate of
> skill, and it never sets difficulty. No deed has a person as its target.
> Nothing about a person is saved. No villager reads another villager's
> state; the only thing about the player a villager may read is the
> standing, rebuilt from the record. The game has an erase button, which
> removes the file and starts again from the first day.

What each part is for:

- **A deed is `{day, verb, place}`.** Its verbs act on places: burn,
  repair, pull down the bridge, build a footbridge, divert the water,
  plant, dig a well, open or close a gate (T164). A deed with a person as
  its target would turn the record into a log of what the player did to
  whom, and that is a record about people. The schema has no field for
  one.
- **Appended, never edited, with a schema version.** The record is the
  only truth; a record that can be edited is a model that can be tuned.
  The version lets a later example refuse a file it does not understand
  rather than misread it. It lives in the record's first line, a header
  `{"version": 1}`, and every line after it is one deed. N20 also lets a
  deed line carry `version`, so a record that repeats it on each line is
  not refused; it is the record's key, never a person.
- **One class writes it** (`ValleySave`, T164's name). One writer is one
  place to read when asking what the game keeps.
- **Nothing derived is saved.** Not the world, not the standing, not a
  cache of either. Each session rebuilds them from the record and the
  authored rules, so what the player sees is always explainable from what
  the player did. A derived value on disk would drift from its record the
  first time a rule changed.
- **Time moves only while the player plays.** A day is a turn of the game,
  never the wall clock, so a session is deterministic and a test can
  replay it.

### Why the standing is not ADR 0016's player model

ADR 0016's player model (N14) estimates how well the person plays and turns
the estimate into the opponents' knobs. That is why it must forget when the
match ends: a model of the person that survives is a profile. The standing
is a different thing, on three counts:

1. **Its weights are fixed and authored.** `standing.json` (T164) holds one
   weight per verb and place for each virtue, each with a `why` a designer
   wrote. Nothing at game time changes a weight, by a step or otherwise.
2. **It estimates no skill.** It is a sum over deeds, not a reading of how
   well the person plays. Two players who did the same deeds have the same
   standing, however they played.
3. **It sets no difficulty.** It sets *consequences*, never a challenge.

The two words, defined:

- **Difficulty** is a parameter of how hard the game makes a challenge: an
  opponent's strength or aim, a timing window, a search depth. The valley
  has none.
- **A consequence** is what an authored weight does in the world: a price,
  a door, a greeting. The consequence keys are listed in `standing.json`,
  and those are the only things the standing may set.

N14 is unchanged, and this record neither widens nor weakens it: the bot
match's player model still starts empty, is never saved, and is never
loaded. The standing is not a fourth ADR 0016 component either: it counts
nothing during play beyond adding a deed to the record.

### What N20 refuses

`check_no_training.py` gains **N20**. Its targets are every file under
`godot/game/valley/` and every GDScript naming `DeedLog`, `ValleySave`,
`ValleyRules`, `ValleyWorld` or `Standing`. Like N9, N13 and N14, it is a
net for the common spellings, not a proof. It refuses, each with a planted
case (invariant 4):

1. **A save written by any other file**: a file write, an erase, or a line
   naming the save (`user://`, `deeds.json`, `ValleySave.PATH`) in any game
   file but `valley_save.gd`. Reading the save back from another file is
   refused too: the record reaches the world through the class that keeps
   it.
2. **Derived state written beside the record**: `valley_save.gd` names no
   world, rules, standing or virtue.
3. **An authored weight changed at game time**: N13's step towards a target
   (in `standing.gd`, any scaled `+=`); in `standing.gd`, any write into a
   weight outside `_load_weights`, the function that reads
   `standing.json`; elsewhere, a weight written through a standing
   (`standing._weights[...] =`). A path's `edge_weight` for A\* is not an
   authored weight and passes.
4. **A deed whose target is a person**: a deed literal -- a dictionary
   naming `verb` -- with a key beyond `day`, `verb` and `place` (and the
   header's `version`), quoted or in `key = value` form, on one line or
   one key per line; a key or field written into a deed
   (`deed["target"] =`, `deed.target =`, `deeds[0]["target"] =`); and any
   merge into a deed.
5. **The record or the standing read to set difficulty**: in the valley's
   folder, difficulty, accuracy, aim or skill named at all; a search depth
   anywhere, and those words outside the folder, on a line that also names
   the record or the standing. A villager's plan bound (`MAX_DEPTH`) is
   not the player's difficulty, and a villager's `reaction` read off the
   standing is the consequence this record allows: both pass.

**What a test may do.** A test under `godot/test/` that names the valley
must reach a save, plant a person to see it refused, and clean up after
itself. So there N20 holds only three refusals: it names no real save
(`user://valley`, `ValleySave.PATH`), steps no value, and sets no
challenge from the record or the standing. It may hand `ValleySave` a path
of its own under `user://tmp/`, write and erase it, and build a deed with
a planted key. Planted both ways: those three lines pass in a test; the
same `user://tmp/` line in a game file is still refused, and a test naming
the real save is refused.

What N20 cannot see, and what holds it instead:

- **that the record is appended to and never edited**: `valley_save.gd`
  may open its file with `FileAccess.WRITE` and truncate it. A T164 test
  appends a deed to a record and reads the first deed back unchanged;
- **that the record carries its version**: a T164 test loads a record with
  an unknown version, and with none, and sees both refused by name;
- **that the world and the standing rebuild the same from the record**,
  twice, and that a record cut at day n gives day n (T164's tests);
- **that a villager reads only the standing** (T165's review);
- **the spellings its net misses**: a `ConfigFile` saved through a
  parameter (`cfg.save(p)`, a gap every rule in the gate shares), a deed's
  key set through a renamed copy, a deed nested inside another literal.

### Where the save lives

Read in the 4.7 documentation and measured on 4.7.2, in
`docs/godot/user-data.md`:

- **In the checkout**, `user://` is `.user-data/` (ADR 0022), and the save
  is `user://valley/deeds.json` there. **This amends ADR 0022's
  consequence** that nothing under `.user-data/` is meant to survive: the
  valley's save is meant to survive between sessions. `git clean -fdx`
  still deletes it, and that is accepted -- a checkout is a working copy,
  and deleting the save is the erase button. Tests never write the real
  save: they hand `ValleySave` a path of their own under `user://tmp/`.
- **In an exported build**, `user://` is the player's data folder:
  `~/.local/share/godot/app_userdata/game-ai-kit/` on Linux,
  `%APPDATA%\Godot\app_userdata\game-ai-kit\` on Windows. That is where a
  game's save belongs, and it stays there.

**Invariant 8 does not cover an exported build run by a player.** It is
about what this repository installs or writes on the machine that
develops it: the toolchain, the caches, the checkout's runs. Every run the
repository makes goes through `scripts/godot`, and `export.py` starts the
exported binary under the same redirect, so the repository's own runs never
reach the home. A player who runs the exported game is running a game, and
a game keeps its save in that player's data folder. `check_disk_layout.py`'s
D1 keeps flagging this project's `user://` in the developer's home: on the
author's machine, a save there means something bypassed the wrapper.

`application/config/use_custom_user_dir` stays off. It would move the
exported save to `~/.local/share/game-ai-kit/`, but it moves the
checkout's too, and D1, `scripts/godot` and `make valley-erase` all read the
default layout. Nothing is gained that is worth that.

### Erasing

The game has an erase button, with a confirmation (T165). `make
valley-erase` does the same for the checkout: it asks `scripts/godot` where
`user://` is, refuses anything outside the checkout's `.user-data/` -- and
a `.user-data/`, or any folder below it, that is a symbolic link, since a
link resolved first lies wherever it points -- and removes `valley/`
there.

## Alternatives considered

- **Save the world's state, not the deeds.** Smaller to load, and opaque: a
  state on disk cannot say why it is what it is, and drifts from the rules
  the first time one changes. Rejected.
- **Save the standing beside the record, as a cache.** Derived, and the
  one number that looks most like a profile. Rejected.
- **Let the standing learn its weights from the player.** That is a
  player model fitted at game time, kept across sessions -- what ADR 0016
  and invariant 6 exist to refuse. Rejected.
- **Deeds on people as well as places.** The obvious karma design, and a
  record of what the player did to whom. Rejected: the valley remembers
  places; a person's reaction is read off the standing, not off a deed
  aimed at them.
- **Keep everything per session, as every other example does.** It keeps
  the rule simple and loses the owner's request, which is persistence.
  Rejected.

## Consequences

- The first file the kit keeps between sessions. One class writes it, one
  rule (N20) watches the common ways around that, and the erase button
  removes it.
- ADR 0016: its sentence "any count that survives the fight" still refuses
  every count; a record of deeds is not a count, and the standing is
  rebuilt, not kept. The note at the end of 0016 points here.
- ADR 0022: the valley's save is the one thing under `.user-data/` meant
  to survive. The note at the end of 0022 points here.
- Invariant 6's row in `CLAUDE.md` names N20.
- T164, T165 and T166 build on this record. The owner's acceptance on
  2026-11-11 means they no longer wait on a separate approval of it.
