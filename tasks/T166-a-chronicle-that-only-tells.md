# T166 — A chronicle that only tells: story sifting

Size: M · Prereqs: T165 · Files: `godot/addons/ai_sifting/`, `godot/test/ai_sifting/`, `python/gameaikit/sifting/`, `python/tests/`, `spec/vectors/sifting/`, `modules/ai_sifting.json`, `godot/game/valley/`, `docs/techniques/`, `Makefile`

## Goal

A simulation's output becomes a story only once something picks the
moments worth telling. That is story sifting: patterns matched over an
event log, as in Felt (Kreminski et al., 2019) and Winnow (Kreminski et
al., 2021). It is the kit's one new technique for the karma system. The
valley gets a chronicle, for example "the third time the bridge came
down, the east village stopped waiting for bread". The chronicle only
tells; it changes nothing in the world.

## Decisions written down first

_The owner asked for a karma system on 2026-11-10: the player's actions and choices have a visible impact on the world and its people, and they persist between sessions like a save. The owner chose this design from a research brief: the valley remembers what the player did to **places**, and the player's standing, read from those deeds, sets prices and doors. It has no combat and no opponent, and it is 2D and turn-based. The owner approves the ADR (T163), and that approval gates T164-T166. The other decisions below are this session's proposal, and the wave confirms them._

- **A new addon, `ai_sifting`**, depending only on `ai_core`
  (invariant 2), at tier 1. It has a Python twin and shared vectors. It
  trains nothing (invariant 6).
- **Events are plain data.** The sifter takes an `Array` of
  `Dictionary` events, never the valley's `DeedLog`, so the addon names
  nothing outside itself and `ai_core` (invariant 2). This task creates
  `make test-sifting-vectors`, with `test-vectors: test-sifting-vectors`
  beside the rule.
- **Felt-style first:** a pattern is a small query over events, with
  shared variables and order constraints. The sifter returns every
  match with the events that made it. Incremental matching, as in
  Winnow, is a later task.
- **Read-only, by test:** the sifter takes the record and returns
  matches. A planted sifter that writes to the record, or to the world,
  fails.
- **The chronicle's voice is templates first.** `ai_llm` behind its
  validator, at tier 3 with a recorded tier 2, is a possible later
  task, not this one.
- **The name** `ai_sifting` is this session's proposal; the owner may
  rename it.
- **Taught:** a technique page in English and pt-BR, and glossary entries.

**The owner's decisions, 2026-11-11.** The addon's name stays
`ai_sifting`. The chronicle's voice is templates, with no language model.
Every other decision above is confirmed as proposed.

**What wave 189 decided while building it.**

- The events are derived, never saved: `ValleyChronicle.events` replays
  the record day by day with `ValleyRules` -- each night's changed facts as
  `{day, kind: "night", place, fact, value}`, then that day's deeds as
  `{day, kind: "deed", verb, place}` -- every time the chronicle is told.
  `ValleyGame` keeps the last answer until a deed is kept or the day
  changes.
- A pattern also has `unless`, Felt's negation: an event that must not lie
  between two found ones, or before or after one. Without it "the third
  time" and "the repair that answered the burning" cannot be said.
- The six patterns live in `godot/game/valley/chronicle.json`; their
  sentences are a constant in `ValleyPanel` marked `# shown through tr()`,
  so `lint-translations-game` holds them without a new data rule.
- C turns the right-hand panel to the chronicle and back: the panel had no
  room for both. The `make demo-valley` help line, the menu card and the
  in-game key line name it.
- After review 189: a night's change carries the deed behind it, followed
  back through the rules, and `no-bread` / `no-travellers` join on it, so a
  line names the cause rather than the last deed; an `unless` is looked for
  as soon as its bounds and variables are known, and ends the search for an
  event when no later one could pass (26 ms at 120 days of deeds, from
  2.8 s); an `unless` never matches a found event, pinned by a vector and
  stated on the pages.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_sifting"
make test-sifting-vectors
make test-python
make lint-addon-deps
make lint-tiers
```

## Manual check

- The chronicle in the valley names moments a person would retell, and
  the overlay shows which events each line matched.

## Sources

- Kreminski, Dickinson, Wardrip-Fruin, "Felt: A Simple Story Sifter", ICIDS 2019 [S].
- Kreminski, Dickinson, Mateas, "Winnow: A Domain-Specific Language for Incremental Story Sifting", AIIDE 2021 [S]. Code: https://github.com/mkremins/winnow
- Ryan, *Curating Simulated Storyworlds*, PhD thesis, UC Santa Cruz, 2018 [S].
