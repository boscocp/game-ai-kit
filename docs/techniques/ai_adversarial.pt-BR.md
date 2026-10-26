# ai_adversarial — a melhor jogada contra quem responde

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 5, figures 5.3 and 5.7
invalidated_if: the kit's AdversarialGame, MinimaxSearch, AlphaBetaSearch or AdversarialResult signatures change, or the demos that use them are renamed
teaches: adversarial-search
translation_of: 2cbf25263397608df31647dd3303f886b3495544905f2aec3395e107452ec68b
-->

> English: [ai_adversarial.md](ai_adversarial.md). Os termos que ficam em
> inglês estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Qual jogada fazer num jogo de dois jogadores, supondo que o outro vai
responder com a jogada pior para você. O *minimax* (`MinimaxSearch`)
alterna árvore abaixo -- o seu melhor, o pior dele -- até uma profundidade
fixa e pede ao jogo uma nota para a posição a que chegou. O *alpha-beta*
(`AlphaBetaSearch`) devolve a mesma jogada e o mesmo valor olhando menos
posições: abandona uma jogada assim que fica provado que ela não é melhor
do que uma já encontrada. As duas devolvem um `AdversarialResult`: cada
jogada da raiz com o seu valor, as posições visitadas e as jogadas
cortadas. O livro: Russell e Norvig, *AIMA*, capítulo 5.

## Quando não usar {#when-not}

Um jogo com dados ou cartas escondidas: o *minimax* supõe que os dois
jogadores veem tudo e que nada fica por conta da sorte -- ali é o
*expectiminimax*, ou outra família. Um jogo tão largo que nem os cortes do
*alpha-beta* deixam posições poucas o bastante -- o go --, em que a resposta
de costume é a busca em árvore de Monte Carlo. E o `MinimaxSearch` puro
quase nunca: ele está aqui para que o atalho apareça ao lado daquilo que
ele encurta.

## Onde ver funcionando {#watch}

- `make run` -- damas contra o *minimax*. **Espaço** joga a vez das
  brancas, **1-6** escolhem quantos *plies* ele olha à frente. Cada jogada
  que ele considerou é uma seta **azul** com o seu valor, e o painel diz
  quantas posições ele examinou e quantas respostas pulou.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/game/checkers/checkers_game.gd` são as damas contadas para a busca:
um `AdversarialGame` cujos estados são tabuleiros e cujas ações são
jogadas. `checkers.gd` pede ao `AlphaBetaSearch` a jogada das brancas. Os
ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| profundidade | `search(game, state, depth)` | quantos *plies* ele olha à frente; cada um custa mais ou menos o fator de ramificação vezes o anterior |
| a estimativa | o seu `AdversarialGame.evaluate(state, player)` | a nota de uma posição em que a busca para; nunca infinita |
| ordem das jogadas | o seu `AdversarialGame.actions(state)` | o quanto o *alpha-beta* corta -- nunca a jogada que ele devolve. Sempre a mesma ordem: entre jogadas iguais, vence a primeira |
| qual busca | `MinimaxSearch` ou `AlphaBetaSearch` | o trabalho, não a resposta |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_adversarial/`. Ela não precisa de mais nada,
nem do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless
--import`, para o Godot registrar as classes.

### Um exemplo mínimo {#example}

O seu jogo, contado para a busca: Nim, em que os jogadores tiram um, dois
ou três palitos e quem tira o último ganha. `best_take(10)` responde 2,
deixando para o adversário um múltiplo de quatro. Este arquivo é executado
por `nim_example_test.gd`, e o *gate* garante que a página é igual a ele.
Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_adversarial/nim_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_adversarial.md, run by
# nim_example_test.gd. A game of your own, told to the search: Nim, where
# the players take one, two or three sticks in turn, and whoever takes the
# last stick wins.
extends AdversarialGame


## A position: the sticks left, and whose turn it is, 0 or 1. The search
## never looks inside it; it only hands it back to the functions below.
class Pile extends RefCounted:
	var sticks: int
	var player: int

	func _init(left: int, to_play: int) -> void:
		sticks = left
		player = to_play


## How many sticks to take from a pile of `sticks` (at least one), looking
## `depth` moves ahead. Alpha-beta returns what minimax would, for less work.
func best_take(sticks: int, depth: int = 12) -> int:
	return AlphaBetaSearch.new().search(self, Pile.new(sticks, 0), depth).action


# Whose turn it is: the search plays for whoever moves at the root.
func to_move(state: RefCounted) -> int:
	return (state as Pile).player


# One, two or three, never more than are left, always in the same order.
func actions(state: RefCounted) -> Array:
	var takes: Array = []
	for take: int in range(1, mini(3, (state as Pile).sticks) + 1):
		takes.append(take)
	return takes


# A new pile: the search keeps the old one while it tries the others.
func result(state: RefCounted, action: Variant) -> RefCounted:
	var pile := state as Pile
	return Pile.new(pile.sticks - int(action), 1 - pile.player)


# Over when the pile is empty: whoever took the last stick has won.
func is_terminal(state: RefCounted) -> bool:
	return (state as Pile).sticks == 0


# Over: whoever is to move has nothing to take, so the other one took the
# last stick and won. Not over, but as deep as the search may look: no
# opinion. A real game's estimate goes here -- see the learned evaluation.
func evaluate(state: RefCounted, player: int) -> float:
	var pile := state as Pile
	if pile.sticks > 0:
		return 0.0
	return 1.0 if pile.player != player else -1.0
```

### O que você implementa {#implement}

As cinco funções do `AdversarialGame`, para o seu jogo: `to_move`,
`actions`, `result`, `is_terminal` e `evaluate`. Um estado e uma ação são
o que você quiser -- o estado precisa ser um `RefCounted`, e a busca nunca
olha dentro de nenhum dos dois. Quatro promessas em que a busca se apoia:
`result` devolve um estado novo e não mexe no antigo; `actions` lista as
mesmas jogadas na mesma ordem toda vez; os jogadores se alternam (uma
captura múltipla é uma ação só); e `evaluate` devolve o resultado
verdadeiro num jogo terminado e nunca é infinito. Depois chame
`AlphaBetaSearch.new().search(game, state, depth)` e leia `action`;
`considered` é o que desenhar.

## Para ir mais fundo {#deeper}

- Por que o *minimax* funciona, e o que o *alpha-beta* corta (em inglês):
  [concepts/minimax.md](../concepts/minimax.md).
- Dar nota a uma posição com pesos ajustados em Python:
  [learned_evaluation](learned_evaluation.pt-BR.md).
