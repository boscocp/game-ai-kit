# ai_behaviour — o que fazer em seguida

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 5 on decision making ; book:Steve Rabin (ed.), "Game AI Pro", CRC Press, 2013 -- ch. 12 (Humphreys, HTN planners)
invalidated_if: the kit's StateMachine, BehaviourTree, GoapPlanner or HtnPlanner signatures change, or the demos that use them are renamed
teaches: ways-to-decide
translation_of: d58f1e55d5c4d66d51b27d68638acede4e35c9102e686e3de5d2c7f2ef6e929e
-->

> English: [ai_behaviour.md](ai_behaviour.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Que ação um agente faz agora, dados os fatos que o seu jogo conhece --
perseguir, investigar, fazer a ronda. Quatro jeitos de decidir isso, cada um
uma classe: uma **máquina de estados** (`StateMachine`), uma ***behaviour
tree*** (`BehaviourTree`), **GOAP** (`GoapPlanner`, que busca de trás para
frente, a partir de um objetivo, a lista de ações mais barata) e um **HTN**
(`HtnPlanner`, que quebra uma tarefa em partes seguindo métodos escritos por
um designer). Cada um deixa registrado o porquê: a seta tomada, o rastro da
árvore, o plano. O livro: Millington, *AI for Games*, capítulo 5; Humphreys
em *Game AI Pro*, capítulo 12.

## Quando não usar {#when-not}

Uma máquina de estados com mais do que um punhado de estados, ou com
comportamento repetido entre eles -- uma árvore compõe. Uma árvore quando o
agente precisa descobrir sozinho a ordem dos passos -- um planejador busca
essa ordem. Um planejador quando o designer já sabe a ordem -- é uma busca a
cada vez, para uma resposta que alguém poderia ter escrito. `WaysToDecide`
traz a tabela inteira, medida num mesmo guarda.

## Onde ver funcionando {#watch}

- `make demo-behaviour` -- um guarda, quatro cérebros. **1-4** trocam entre
  máquina de estados, árvore, GOAP e HTN no meio da ronda; **espaço** joga um
  turno, **enter** joga dez. O painel ao lado do tabuleiro acende a seta
  tomada, o rastro da árvore ou o plano.
- `make demo-tactical` -- **C** troca o jogador do computador, entre eles a
  máquina de estados, a árvore, GOAP e o HTN no mesmo tabuleiro.
- `make demo-rts` -- cada esquadrão é uma máquina de estados.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/demos/behaviour/guard_tree.gd` monta a árvore do guarda;
`guard_fsm.gd`, `guard_goap.gd` e `guard_htn.gd` são o mesmo guarda dos
outros três jeitos, todos alimentados com os mesmos fatos. Os ajustes que
importam:

| ajuste | onde | o que muda |
|---|---|---|
| os fatos | o `Dictionary` que você passa a cada tick | tudo o que o agente sabe; o seu jogo preenche |
| a ordem dos filhos | `BehaviourTree.Selector` / `Sequence` | qual ramo é perguntado primeiro, e portanto qual vence |
| a ordem das setas | `StateMachine.add_arrow` | a primeira seta cuja condição vale é a tomada |
| o custo de uma ação | `GoapAction` | qual plano o GOAP acha mais barato |
| a ordem dos métodos | `HtnDomain` | qual jeito de fazer uma tarefa o HTN tenta primeiro |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_behaviour/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes.

### Um exemplo mínimo {#example}

Um guarda seu, como *behaviour tree*: persegue o que vê, vai olhar onde ouviu
algo, senão faz a ronda. Chame `decide(facts)` do seu próprio laço de jogo e
aja conforme o que ele devolve; desenhe `trail()` para mostrar o porquê. Este
arquivo é executado por `guard_example_test.gd`, e o gate garante que a
página é igual a ele. Os comentários do código ficam em inglês, como no
arquivo.

<!-- example: godot/test/ai_behaviour/guard_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_behaviour.md, run by
# guard_example_test.gd. A guard of your own: chase what it sees, look
# where it heard something, otherwise walk its round.
extends Node

## What the last tick chose. Your game reads it and moves the guard.
var doing: String = ""

var _tree: BehaviourTree


func _ready() -> void:
	_tree = BehaviourTree.new(BehaviourTree.Selector.new("guard", [
		BehaviourTree.Sequence.new("chase", [
			BehaviourTree.Condition.new("sees someone?", _fact.bind("sees_player")),
			BehaviourTree.Action.new("run at them", _choose.bind("chase")),
		] as Array[BehaviourTree.TreeNode]),
		BehaviourTree.Sequence.new("investigate", [
			BehaviourTree.Condition.new("heard something?", _fact.bind("heard_noise")),
			BehaviourTree.Action.new("go and look", _choose.bind("investigate")),
		] as Array[BehaviourTree.TreeNode]),
		BehaviourTree.Action.new("walk the round", _choose.bind("patrol")),
	] as Array[BehaviourTree.TreeNode]))


## Ask the tree once, from the root, with what your game knows this tick.
func decide(facts: Dictionary) -> String:
	_tree.tick(facts)
	return doing


## Every node the last tick asked and what each answered: draw it, and the
## player sees why the guard did what it did.
func trail() -> Array[String]:
	return _tree.trail


# A condition: one fact, read from what the game filled in.
func _fact(facts: Dictionary, fact_name: String) -> bool:
	return facts.get(fact_name, false)


# An action: here it only records the choice; your game acts on `doing`.
func _choose(_facts: Dictionary, choice: String) -> BehaviourTree.Status:
	doing = choice
	return BehaviourTree.Status.SUCCESS
```

### O que você implementa {#implement}

Os fatos e as ações. Uma condição é qualquer `Callable` que recebe os fatos e
devolve um `bool`; uma ação é uma que devolve um `BehaviourTree.Status` --
`RUNNING` para algo que leva vários ticks, como andar até um lugar. A árvore
não guarda nada entre um tick e outro, então quem guarda o mundo é o seu
jogo. Uma máquina de estados recebe o mesmo tipo de condição em cada seta,
com uma frase dizendo por que ela dispara.

## Para ir mais fundo {#deeper}

- Um guarda escrito de quatro jeitos, e quando cada um é o certo (em inglês):
  [concepts/ways-to-decide.md](../concepts/ways-to-decide.md).
- Planejamento, e o primo do GOAP que busca para frente, o STRIPS (em
  inglês): [concepts/planning.md](../concepts/planning.md).
