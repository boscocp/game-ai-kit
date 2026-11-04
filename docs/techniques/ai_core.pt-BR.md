# ai_core — a grade sobre a qual todo addon se apoia

<!-- doc-meta
half_life: practice
verified_on: 2026-11-04
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: the kit's GridGraph, Pathfinder or Xorshift signatures change, or ADR 0021 moves what the kernel holds
teaches: none
translation_of: 63b5e6f41e159f7936b16b7bb6d3913fac872f32149911dcd3f1b14e263e6cc2
-->

> English: [ai_core.md](ai_core.md). Os termos que ficam em inglês estão no
> [glossário](glossary.pt-BR.md).

`ai_core` não é uma técnica. É o núcleo compartilhado: dois tipos, um
gerador com semente e nenhum algoritmo, para que todo addon fale do mesmo
tabuleiro, e sorteie os mesmos números, sem depender de outro addon
(invariante 2, ADR 0021).

## O que ele contém {#holds}

- `GakGridGraph` -- uma grade quadrada de custos: quanto custa **entrar** em
  cada célula. Um é terreno aberto, mais é terreno difícil,
  `GakGridGraph.BLOCKED` é parede; nada custa menos que um. `neighbours(cell)`
  devolve as quatro células vizinhas em que se pode entrar, numa ordem fixa.
- `GakPathfinder` -- a porta: um método abstrato, `find_path(graph, from, to)`,
  uma rota que deixa `from` de fora e inclui `to`. O `GridPathfinder` do
  `ai_search` é um; o seu jogo pede um `GakPathfinder` e nunca cita o addon que
  responde.
- `Xorshift` -- o xorshift de 32 bits de Marsaglia (2003), com semente:
  `next()`, `index(count)` (escolher entre um não gasta sorteio) e
  `uniform()`. Escrito de novo em Python como `gameaikit.core.Xorshift`,
  para que a mesma semente sorteie os mesmos números nas duas linguagens --
  o que o `RandomNumberGenerator` do Godot e o `random` do Python não
  prometem. `spec/vectors/core/` confere um com o outro. Ele não decide
  nada; a busca de Monte Carlo, o filtro de partículas, o bandit e os
  fantasmas do labirinto dizem cada um o que um sorteio significa (T109).

## Quando você precisa dele {#when}

Copie `godot/addons/ai_core/` junto com qualquer addon cuja página peça --
hoje `ai_search`, `ai_perception`, `ai_rts_core`, e `ai_adversarial` e
`ai_bandit` pelo gerador. Um addon que nem raciocina sobre uma grade nem
sorteia números com semente (`ai_steering`, `ai_behaviour`) não precisa dele.

## Quando não usar {#when-not}

Um tabuleiro hexagonal, uma malha de navegação, qualquer coisa cuja célula
não seja uma coordenada inteira: `GakGridGraph` é uma grade quadrada e diz
isso. As buscas continuam funcionando ali pela porta delas, `GakSearchGraph` --
veja [ai_search](ai_search.pt-BR.md). E o `Xorshift` para qualquer coisa
que um jogador não possa prever: o período é 2^32 - 1 e os bits baixos são
fracos.

## Para ir mais fundo {#deeper}

- Por que o núcleo guarda tipos e nenhuma lógica, e por que um gerador não
  é lógica (em inglês):
  [ADR 0021](../adr/0021-the-board-is-the-examples-kernel.md).
- Como um addon daqui é montado (em inglês):
  [godot/addon-anatomy.md](../godot/addon-anatomy.md).
