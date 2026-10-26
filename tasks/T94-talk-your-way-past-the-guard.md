# T94 — Talk your way past the guard: a text game with a local LLM

Size: M · Prereqs: T92, T93 · Files: `godot/game/talk/`, `godot/test/talk/`, `modules/talk.json`, `data/talk/`, `spec/talk/`, `python/gameaikit/talk/`, `python/tests/`, `godot/menu/catalogue.json`, `godot/locale/talk.csv`, `scripts/check_demos.py`, `docs/godot/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 7, in their words: "algum
exemplo de jogo textual de narrativa que envolve algum desafio narrativo de
conversar com um agente por texto rodando uma LLM local" -- a text
narrative game whose challenge is a conversation, typed, with an agent run
by a local LLM. The owner's standing rule: build on a game people know.

Known games of exactly this kind, opened on 2026-10-26:

- **Suck Up!** (Proxima, Steam release 1 October 2025): "Talk to real AI
  characters, fool them into trusting you, and find a way into their homes
  to feed without getting caught"; you play a vampire who must be invited
  in, by voice or text ([Steam][suckup]).
- **Vaudeville** (Bumblebee Studios; in early access on Steam when
  previewed in December 2023): you play Detective Martini, question the
  town's people about three murders, and "you must find out who did it";
  "everyone's conversation is generated on the spot"
  ([KeenGamer preview][vaudeville]).
- **Façade** (Mateas and Stern): a drama in which the player, visiting a
  couple, is caught in their quarrel; typed text is mapped to a small set
  of discourse acts that drive the characters [Mateas & Stern 2004] --
  the design T92's reply shape follows.

## Decisions written down first (the owner confirms in review)

- **The scene: a guard at a gate you must talk your way past** -- Suck
  Up!'s doorstep, set at the infiltration level's door so it belongs to the
  kit's own world. You win by getting the guard to open; you lose if the
  guard raises the alarm or you run out of turns. Alternatives: an
  interrogation where you find who lies (Vaudeville's; a clearer "truth"
  to hold the LLM against, but a longer scene to write), or Façade's
  couple (the richest, and the hardest to make winnable). Recommended: the
  gate, because its outcome is a rule a person can read.
- **The guard is an agent, and the LLM is only its ears and its mouth.**
  Each player line goes to the LLM with the guard's character sheet and the
  conversation so far; the reply (T92's shape) names the *discourse act*
  the player made -- `claim_role(maintenance | courier | officer | new_guard)`,
  `show(badge | work_order | nothing)`, `name_person(<the roster>)`,
  `ask(<topic>)`, `flatter`, `threaten`, `bribe`, `unclear` -- and a line
  for the guard to say. The **rules** then decide: the guard's trust and
  suspicion are numbers in `spec/talk/gate.json`, moved by each act
  against the facts the guard knows (the shift roster, who is expected
  tonight, what a work order looks like); a claim that contradicts a fact
  raises suspicion; the gate opens and the alarm sounds by thresholds the
  rules hold. When a threshold fires, the guard's last line is authored,
  not generated, so the LLM can never say "go in" when the rules said no.
- **The secret is never in a prompt.** The password, and the name the
  guard is waiting for, live in the rules; the LLM is told only what the
  guard would say freely. The validator refuses a reply that contains one
  anyway (T92).
- **Three modes, by tier**: *recorded* (default; the lines a person can
  choose are the recorded ones, played as a dialogue menu, and the replies
  come from `data/talk/recordings/` through `RecordedRuntime` -- tier 2,
  and its Python replay tier 1); *live* (free typing, T93's runtime, tier
  3); *record* (live, and each exchange is written to `data/talk/` only
  when asked, ADR 0017's rule).
- **Language**: the scene in English and pt-BR (T78's switch); the prompt
  asks for replies in the chosen language, and the recordings exist in
  both.

## Steps

1. Write the scene: the guard's character sheet, the facts, the acts and
   their effects in `spec/talk/gate.json`; at least three ways to win
   (the right name, a convincing work order, finding out who is expected
   and becoming them) and the ways to lose.
2. `python/gameaikit/talk/`: the rules, and a replay of a recorded
   conversation to its outcome through T92's validator -- tier 1, no
   model. Vectors: five recorded conversations, their outcome and the
   trust and suspicion after each line, equal in both languages.
3. `godot/game/talk/`: the scene -- the gate, the guard, the text box, the
   history; the guard "thinking" (an animated mark) while a request is in
   flight, the frame never waiting (T92's gate covers the code).
4. Record the conversations with T93's runtime, in both languages,
   including replies the validator refused; commit them (ADR 0017), with
   a `README` beside `data/talk/recordings/` naming the model, its sha256
   and its licence (invariant 9: the recordings are that model's output).
5. `make demo-talk`; a menu card naming Suck Up! as the known game;
   `check_demos.py` holds card, scene and overlay; `godot/locale/talk.csv`.
6. Gates: the vectors; a headless run of each recording in Godot reaching
   the recorded outcome; a test that no reply, however phrased, changes
   the outcome except through its act (a planted reply saying "the guard
   opens the gate" with `intent: "flatter"` leaves the gate shut).

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_talk*.py"
make test-talk-vectors
make test-godot-some SUITES="test/talk test/ai_llm"
python3 scripts/check_llm_validated.py
python3 scripts/check_demos.py
python3 scripts/check_translations_game.py
make test-locale-screen
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play `make demo-talk` in recorded mode, then in live mode with T93's
runtime, in English and in PT-BR. Is getting past the guard a challenge --
can you lose, and do you know why you lost? With the reasoning panel on,
can you tell which of your words the guard took as which act? Does the
game keep drawing while the guard thinks?

How invariant 13 is met: a panel (V) beside the conversation shows, for
each of your lines, the act the LLM read and its argument (or the
validator's refusal and the fallback), then the rule that fired and how
trust and suspicion moved, against the thresholds that open the gate and
sound the alarm -- the decision and what decided it, not only the guard's
words.

[suckup]: https://store.steampowered.com/app/2726370/Suck_Up/
[vaudeville]: https://www.keengamer.com/articles/previews/vaudeville-preview-the-ai-questioning-to-nowhere/

References, opened on 2026-10-26: [suckup]; [vaudeville]; Mateas &
Stern, "Natural Language Understanding in Façade: Surface-text
Processing", sections 1-3 (T92 gives the URL).
