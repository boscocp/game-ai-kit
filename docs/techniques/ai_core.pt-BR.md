# ai_core — a grade sobre a qual todo addon se apoia

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: the kit's GridGraph or Pathfinder signatures change, or ADR 0021 moves what the kernel holds
teaches: none
translation_of: 1ec835c07bfde9f704f4c8270e3c6e375f5c46d4ac11262d6ef7075c9ae3b04e
-->

> English: [ai_core.md](ai_core.md). Os termos que ficam em inglês estão no
> [glossário](glossary.pt-BR.md).

`ai_core` não é uma técnica. É o núcleo compartilhado: dois tipos e nenhum
algoritmo, para que todo addon fale do mesmo tabuleiro sem depender de outro
addon (invariante 2, ADR 0021).

## O que ele contém {#holds}

- `GakGridGraph` -- uma grade quadrada de custos: quanto custa **entrar** em
  cada célula. Um é terreno aberto, mais é terreno difícil,
  `GakGridGraph.BLOCKED` é parede; nada custa menos que um. `neighbours(cell)`
  devolve as quatro células vizinhas em que se pode entrar, numa ordem fixa.
- `GakPathfinder` -- a porta: um método abstrato, `find_path(graph, from, to)`,
  uma rota que deixa `from` de fora e inclui `to`. O `GridPathfinder` do
  `ai_search` é um; o seu jogo pede um `GakPathfinder` e nunca cita o addon que
  responde.

## Quando você precisa dele {#when}

Copie `godot/addons/ai_core/` junto com qualquer addon cuja página peça --
hoje `ai_search`, `ai_perception`, `ai_rts_core`. Um addon que não raciocina
sobre uma grade (`ai_steering`, `ai_behaviour`) não precisa dele.

## Quando não usar {#when-not}

Um tabuleiro hexagonal, uma malha de navegação, qualquer coisa cuja célula
não seja uma coordenada inteira: `GakGridGraph` é uma grade quadrada e diz
isso. As buscas continuam funcionando ali pela porta delas, `GakSearchGraph` --
veja [ai_search](ai_search.pt-BR.md).

## Para ir mais fundo {#deeper}

- Por que o núcleo guarda tipos e nenhuma lógica (em inglês):
  [ADR 0021](../adr/0021-the-board-is-the-examples-kernel.md).
- Como um addon daqui é montado (em inglês):
  [godot/addon-anatomy.md](../godot/addon-anatomy.md).
