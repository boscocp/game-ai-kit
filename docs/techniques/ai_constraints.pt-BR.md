# ai_constraints — o que precisa valer, e um *solver* que acha

<!-- doc-meta
half_life: practice
verified_on: 2026-11-04
tier: 1
source: https://aima.cs.berkeley.edu/contents.html ; book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 6, Constraint Satisfaction Problems
invalidated_if: the kit's ConstraintProblem or ConstraintSolver signature changes, or the infiltration demo stops solving its levels with them
teaches: constraint-satisfaction
translation_of: 506a52434b7cf391346553a11d4bb8b54737d2a6558edd35488ede4b91455b28
-->

> English: [ai_constraints.md](ai_constraints.md). Os termos que ficam em
> inglês estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Uma atribuição de valores a variáveis que não quebra nenhuma das restrições
declaradas entre elas -- ou a notícia de que não existe nenhuma. Você não diz
*como* construir a resposta; diz *o que* é uma resposta. Cada variável tem um
domínio finito de valores; uma restrição *binária* diz que pares de valores
duas variáveis podem ter juntas; uma restrição *global* olha para quantas
variáveis quiser e diz se o que já foi atribuído ainda pode ser completado.
O `ConstraintSolver` é a busca com *backtracking* da 4ª edição do AIMA (6.3,
fig. 6.5) com as três escolhas que o livro nomeia: a variável com menos
valores restantes (*minimum remaining values*; no empate, a que está em mais
restrições, a heurística de grau), seus valores do que menos restringe para
o que mais restringe (*least constraining value*), e a consistência de arcos
mantida pelo AC-3 (fig. 6.3) depois de cada atribuição. Uma *seed* ordena os
empates, então uma *seed* é uma resposta.

## Quando não usar {#when-not}

Quando qualquer resposta serve e a primeira sorteada costuma ser boa: gerar
e testar é mais curto. Quando uma restrição é uma preferência ("melhor longe
que perto"): aqui a resposta é sim ou não, e uma nota é coisa de utilidade
ou de otimizador. Quando a maioria das restrições é global e não pode ser
propagada: o *solver* passa a tentar valores um a um, que é gerar e testar
com passos a mais. Quando o problema é grande o bastante para pedir busca
local (*min-conflicts*, AIMA 6.4) ou um *solver* dedicado. E quando o
*backtracking* cronológico se debate -- voltando sobre escolhas que nunca
foram o problema --, este kit recomeça com outros empates em vez de saltar
para trás (o *backjumping* do AIMA 6.3.3 não está aqui).

## Onde ver {#watch}

- `make demo-infiltration` -- **L** até um nível gerado, depois **K**: o
  primeiro toque resolve o nível em vez de sorteá-lo, o segundo também
  reproduz o *solver* na tela. Nela, a coisa prestes a ser posta tem cada um
  dos seus lugares candidatos desenhado, branco enquanto possível e um X
  vermelho depois que a propagação o riscou; toda coisa ainda não posta
  aparece numa lista com quantos lugares lhe restam, a próxima primeiro; um
  valor desfeito por um *backtrack* pisca em vermelho; a última recusa diz
  qual restrição recusou. **N** monta outro nível do mesmo jeito.
- `make measure-level-constraints` -- o *solver* contra os níveis sorteados
  em 200 *seeds*; a tabela está na [página da infiltração](../godot/infiltration.md).
- Que demo usa que técnica, nos dois sentidos: o
  [catálogo](catalogue.pt-BR.md).

## Neste kit {#in-this-kit}

`godot/game3d/infiltration/level_constraints.gd` declara o nível de
infiltração: cada caixa, lâmpada, esconderijo, ponto de patrulha e o posto da
sentinela é uma variável cujo domínio são alguns lugares candidatos sorteados
pela *seed*. Caixas afastadas, nada debaixo de uma caixa, um guarda por
célula, esconderijos e lâmpadas afastados são binárias e propagadas; a saída
e todo lugar de guarda alcançáveis, nenhum posto à vista da partida, um
esconderijo perto de cada rota e um caminho escuro até a saída são globais,
escritas pelo jogo (`level_constraint_rules.gd`) e perguntadas a cada nível
parcial. Os controles:

| controle | onde | o que muda |
|---|---|---|
| variáveis | `add_variable(name, values)` | o que se decide, e os valores que cada uma pode ter, na sua ordem |
| binária | `add_binary(first, second, allowed, label)` | um teste de dois valores; propagado pelo AC-3 |
| global | `add_global(names, holds, label)` | um teste de uma atribuição parcial: falso só quando nada que ainda vem poderia salvá-la |
| *seed* | `ConstraintSolver.new(problem, seed)` | para que lado vão os empates, o mesmo em GDScript e em Python |
| mrv, lcv, propagate | propriedades do *solver*, todas ligadas | desligue uma para ver quanto ela vale: o mesmo problema, os *backtracks* contados dos dois jeitos |
| record | uma propriedade, desligada | guarda cada passo em `trace` -- escolhido, atribuído, recusado, riscado, desfeito -- para uma visualização |
| limit | uma propriedade, 0 para nenhum | o máximo de atribuições antes de desistir; `gave_up` diz então que nenhuma resposta foi provada impossível |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_constraints/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. O gêmeo em Python é
`gameaikit.constraints`.

### Um exemplo mínimo {#example}

Quatro salas em fila e três coisas para pôr nelas: a chave antes do baú, o
guarda ao lado do baú e não sobre a chave, e alguma coisa na torre. Este
arquivo é rodado por `rooms_example_test.gd`, e o *gate* mantém a página
igual a ele.

<!-- example: godot/test/ai_constraints/rooms_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_constraints.md, run by
# rooms_example_test.gd. A dungeon of four rooms in a row, and three things
# to put in them -- a key, the chest it opens, the guard of the chest --
# said as what must hold, not as how to place them.
extends Node

const ROOMS: Array[String] = ["hall", "library", "cellar", "tower"]

var _problem := ConstraintProblem.new()


func _ready() -> void:
	# Each thing may go in any room, by its index along the row.
	for thing: String in ["key", "chest", "guard"]:
		_problem.add_variable(thing, range(ROOMS.size()))
	# The key comes before the chest, so the player finds it first.
	_problem.add_binary("key", "chest", func(key: int, chest: int) -> bool: return key < chest, "key first")
	# The guard stands in the chest's room or the one beside it.
	_problem.add_binary("guard", "chest", func(guard: int, chest: int) -> bool: return absi(guard - chest) <= 1, "guarded")
	# Not where the key is: the player must be able to take it.
	_problem.add_binary("guard", "key", func(guard: int, key: int) -> bool: return guard != key, "key free")
	# Global, checked on each partial answer: the tower is used. It can only
	# say no once all three are placed, so until then it says yes.
	_problem.add_global(["key", "chest", "guard"], func(placed: Dictionary) -> bool:
		return placed.size() < 3 or placed.values().has(3), "tower used")
	# A misspelt name or an empty domain is refused here.
	if _problem.problem() != "":
		push_error(_problem.problem())


## Where each thing goes, by room name, for `seed_value`; {} when no
## placement satisfies every constraint.
func place(seed_value: int) -> Dictionary:
	var solver := ConstraintSolver.new(_problem, seed_value)
	var found: Dictionary = solver.solve()
	var named: Dictionary = {}
	for thing: String in found:
		named[thing] = ROOMS[found[thing]]
	return named
```

### O que você implementa {#implement}

As restrições, como testes. Uma binária é um `Callable` de dois valores, o da
primeira variável e depois o da segunda; faça-a barata, porque o AC-3 e o
*least constraining value* perguntam por cada par muitas vezes -- o nível de
infiltração pergunta cada par uma vez e guarda uma tabela. Uma global é um
`Callable` da atribuição parcial: deve responder falso só quando nenhum jeito
de atribuir o resto poderia satisfazê-la, e verdadeiro enquanto ainda não
sabe dizer. Errar para o outro lado -- falso em algo que um valor posterior
consertaria -- faz o *solver* perder respostas e dizer "nenhuma" quando há
uma. Não mude a atribuição que ela recebe. Mantenha os valores comparáveis
com `==`: um índice numa lista de candidatos é a resposta de sempre quando as
coisas são grandes.

## Mais fundo {#deeper}

- O que é um CSP, propagação contra busca, e por que o nível de infiltração
  passou de sortear para declarar:
  [concepts/constraint-satisfaction.md](../concepts/constraint-satisfaction.md).
- Os dois níveis lado a lado, medidos em 200 *seeds*:
  [godot/infiltration.md](../godot/infiltration.md).
- Onde a satisfação de restrições fica entre as técnicas da área:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
