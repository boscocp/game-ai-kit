# ai_planning — os passos até um objetivo que ninguém escreveu

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 11, classical planning ; https://en.wikipedia.org/wiki/Stanford_Research_Institute_Problem_Solver
invalidated_if: the kit's StripsAction, WorldState, StripsPlanner, HeuristicPlanner or PlanResult signatures change, or the demos that use them are renamed
teaches: planning
translation_of: 92c74b846ee320b4adaa2353e8d9f463464d736379125530ec0a50026c8b95dd
-->

> English: [ai_planning.md](ai_planning.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

A ordem de ações que torna um objetivo verdadeiro, encontrada por busca em
vez de escrita por um *designer*. Um mundo é um conjunto de fatos que valem
(`WorldState`); uma ação (`StripsAction`) precisa de alguns fatos, deixa
alguns de valer e faz outros valerem -- o STRIPS, na forma de Fikes e
Nilsson. O `StripsPlanner` é uma busca em largura sobre mundos, a versão
para ler primeiro; o `HeuristicPlanner` é o que os jogos rodam: o mesmo
problema sobre bits, A\* guiado por uma estimativa relaxada dos passos que
faltam, dentro de um orçamento, com um horizonte que é o ajuste de
dificuldade. Os dois respondem um `PlanResult` que distingue "já está
feito" de "não há plano" de "o orçamento acabou". O livro: Russell e
Norvig, *AIMA*, capítulo 11.

## Quando não usar {#when-not}

Quando o *designer* já sabe a ordem: aí é uma busca toda vez por uma
resposta que alguém poderia ter escrito -- uma HTN (`ai_behaviour`)
decompõe as receitas do *designer* em vez disso. Um domínio com números --
"ouro suficiente", "três unidades": fatos STRIPS são verdadeiros ou falsos,
então transforme quantidades em fatos antes. E um plano seguido até o fim
sem perguntar de novo: um plano parcial vindo de um orçamento é uma
direção, não uma promessa; execute o primeiro passo e planeje de novo.

## Onde ver funcionando {#watch}

- `make demo-rts` -- a ordem de construção do computador é um plano. **H**
  alterna o seu planejador entre STRIPS e uma HTN sobre o mesmo domínio, e
  o painel mostra o plano e o passo em que ele está; **C** muda o seu
  nível, cujo horizonte é até onde ele planeja.
- `make demo-tactical` -- **C** até o computador ser "planner": um plano
  STRIPS para tomar a oficina do vermelho decide o que o azul compra, e
  cada unidade com que o plano conta diz qual passo está executando.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/game/rts/build_order.gd` transforma o que um lado tem em fatos,
pede `HeuristicPlanner.new().plan(actions, WorldState.new(held), goal,
HeuristicPlanner.Guide.H_MAX, budget, horizon)` e executa o primeiro passo.
`godot/game/tactical/planned_blue.gd` faz o mesmo no tabuleiro tático e
planeja de novo a cada poucos turnos, ou assim que o plano deixa de valer a
partir do tabuleiro. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| o domínio | o seu `Array[StripsAction]` | tudo sobre o que o planejador consegue raciocinar; nada mais existe para ele |
| o guia | `HeuristicPlanner.Guide.H_MAX`, `H_ADD` ou `BREADTH_FIRST` | H_MAX mantém o plano mais curto; H_ADD pode olhar menos mundos |
| o orçamento | `plan(..., budget)` | quantos mundos ele pode olhar antes de responder o que tem, marcado `partial` |
| o horizonte | `plan(..., horizon)` | quantas ações à frente ele enxerga: a dificuldade; `HeuristicPlanner.NO_HORIZON` para todas |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_planning/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. `GakGameDomain` e `Difficulty` ali dentro
são o domínio e os níveis do próprio kit; os seus os substituem. Para um
domínio escrito em PDDL, o leitor fica do lado Python, em
`python/gameaikit/pddl/`.

### Um exemplo mínimo {#example}

Um personagem seu a quem se pede uma porta aberta. Da porta, com a chave na
mesa, ele encontra quatro passos: andar até a mesa, pegar a chave, andar
até a porta, destrancá-la. Este arquivo é executado por
`door_example_test.gd`, e o *gate* garante que a página é igual a ele. Os
comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_planning/door_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_planning.md, run by
# door_example_test.gd. A character of your own that is asked for a goal
# -- the door open -- and finds for itself the steps that get there.
extends Node

## What it can do: what each needs, what stops being true, what starts.
## The planner knows nothing else about your game.
var actions: Array[StripsAction] = [
	StripsAction.new("walk to the table", ["at_door"], ["at_door"], ["at_table"]),
	StripsAction.new("walk to the door", ["at_table"], ["at_table"], ["at_door"]),
	StripsAction.new("take the key", ["at_table", "key_on_table"], ["key_on_table"], ["has_key"]),
	StripsAction.new("unlock the door", ["at_door", "has_key"], [], ["door_open"]),
]


## The steps from what is true now, `facts`, to `goal`, by name. Empty when
## the goal already holds, or when there is no way -- `solved` on the
## `PlanResult` from `plan_for` tells those apart.
func steps(facts: PackedStringArray, goal: PackedStringArray) -> PackedStringArray:
	return plan_for(facts, goal).action_names()


## The whole answer: the steps, whether they reach the goal, and how many
## worlds the planner looked at to find them.
func plan_for(facts: PackedStringArray, goal: PackedStringArray) -> PlanResult:
	return HeuristicPlanner.new().plan(actions, WorldState.new(facts), goal, HeuristicPlanner.Guide.H_MAX)
```

### O que você implementa {#implement}

Os fatos e a execução. A cada turno, escreva o que vale no seu jogo como um
`PackedStringArray` de nomes de fatos -- quantidades viram fatos, como
`resources_banked` --, peça um plano, execute o primeiro passo com o seu
próprio código (andar, construir) e pergunte de novo quando esse passo
terminar ou o mundo mudar debaixo dele. `PlanResult.solved` falso com
`gave_up` verdadeiro quer dizer "não achei dentro do orçamento", nunca
"impossível"; `partial` quer dizer que os passos levam ao mundo que parecia
mais perto. Um domínio tem no máximo 63 fatos, já que um mundo é um `int`.

## Para ir mais fundo {#deeper}

- STRIPS, PDDL e o planejador, desde o começo (em inglês):
  [concepts/planning.md](../concepts/planning.md).
- Como os jogos de estratégia lançados planejam, e por que só no topo (em
  inglês): [concepts/planning-in-strategy-games.md](../concepts/planning-in-strategy-games.md).
- Cada argumento dos dois planejadores (em inglês):
  [godot/planning.md](../godot/planning.md).
