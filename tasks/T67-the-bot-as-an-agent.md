# T67 — The bot as an agent: it perceives, weighs and decides, on any map

Size: L · Prereqs: T66 · Files: `godot/game3d/botmatch/`, `godot/addons/ai_teamwork/`, `godot/addons/ai_perception/`, `godot/addons/ai_behaviour/`, `python/gameaikit/`, `spec/vectors/`, `godot/test/botmatch/`, `docs/godot/botmatch.md`, `docs/concepts/shooter-ai.md`

## Goal

The owner, during T66 (2026-10-21), in their words:

- "aqui devemos sempre trabalhar a autonomia e fazer o mínimo de if else
  fixo na demo, pra ser uma IA genérica, isso vale pra todos os exemplos";
- "lembre do conceito do aima, aqui o bot é um agente que deve perceber o
  mundo e suas acoes e decidir o que fazer pra atingir seu objetivo. entao
  este agente se eu colocar ele em outro mapa, outro contexto com outros
  modelos 3d ele deve saber se virar";
- "ai tem que ver como alinhar isso com as tecnicas de IA usadas aqui" --
  and, on the proposal below, "vamos fazer numa task separada, logo depois
  dessa wave".

T66 made the bot's choices of aim, of passage and of errands weighed
decisions, and showed the same agents playing a second map (`yards.json`)
with no line changed. What is still not an agent's, measured by reading
the code at the end of T66:

1. **The priority list** (`MatchBot.decide`): dead, reload, fall back,
   reload early, shoot, go -- a fixed `if/elif`, the largest left in the
   demo. Its order is a policy, not a weighing.
2. **The errands' scores** (`MatchSupply.weigh_*`): utilities, but written
   inside the demo, with no technique, twin or vectors of their own.
3. **Perception**: `BotMatch.sees` is the match's own cone and line, while
   `ai_perception` holds a vision cone, line of sight and hearing that the
   bot match does not use. A shot is heard by nobody.
4. **Movement**: `MatchActions` turns a step 45 and 90 degrees round a
   body by hand; `ai_steering` is unused.

## Steps

1. **Percepts.** Each bot perceives through `ai_perception` -- its cone,
   its line of sight, the shots it hears -- into one record a decision
   reads, and nothing else is read. Holds the honesty claim as it is.
2. **A selector that weighs.** The priority list becomes a choice among
   actions by utility, each action's score from what the bot perceives and
   the techniques it already asks (`AimChoice`, `PassageChoice`,
   `TacticalPositions`, the errands). In `ai_teamwork` or `ai_behaviour`,
   with a Python twin and vectors. The overlay shows every action's score.
   Read GOAP and behaviour trees in `ai_behaviour` first and say why the
   one chosen fits.
3. **Errands as a technique.** `MatchSupply`'s weighing moves into the
   addon with the selector, its numbers in `rules.json` as they are.
4. **Steering for the last metres**, if `ai_steering` serves; if it does
   not (its avoid says "not walls, not corridors"), say so and keep the
   passage choice.
5. **Portability, held.** The effects test runs on both arenas, and a
   third arena -- made by the test, random within the mirror -- is played
   with no error and every point taken.
6. **Re-measure** with `botmatch_effects.gd`, every claim with its planted
   case; `docs/godot/botmatch.md`.

## Acceptance

```bash
make test-botmatch-effects
make test-teamwork-vectors
make test-godot-some SUITES="test/botmatch test/ai_teamwork"
python3 scripts/check_readability.py
python3 scripts/check_modules.py
```

## Manual check

Play `make demo-botmatch` on both arenas (L switches). Watching a bot (V),
does every action's score explain what it does next?
