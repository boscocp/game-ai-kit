# ai_constraints — o que precisa valer, e um *solver* que acha

<!-- doc-meta
half_life: practice
verified_on: 2026-11-06
tier: 1
source: https://aima.cs.berkeley.edu/contents.html ; book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 6, Constraint Satisfaction Problems ; https://github.com/mxgmn/WaveFunctionCollapse
invalidated_if: the kit's ConstraintProblem, ConstraintSolver or WaveCollapse signature changes, or the infiltration demo or the XCOM-style mode stops building with them
teaches: constraint-satisfaction
translation_of: 1d7cffc99f03136007db744f875dd7d1d71d3e7f6277f46a9791544d1ac7499e
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

O ***wave function collapse*** é o mesmo *solver* com três escolhas trocadas
(`WaveCollapse`, T96). O README do mxgmn diz que o WFC "traduz um problema
de síntese de textura num problema de satisfação de restrições": uma célula
do mapa é uma variável, um *tile* é um valor, duas células vizinhas são uma
restrição binária que diz que *tiles* podem ficar juntos (o `TileGrid` as
declara a partir de uma tabela escrita à mão). A propagação é o AC-3 do
*solver*, sem mudança. O que muda: a próxima célula é a de menor entropia --
a de Shannon, sobre os pesos dos *tiles* que ela ainda pode ser,
`ln W - sum(w ln w) / W` -- onde o *solver* pega a de menos valores; seu
valor é um *tile* sorteado pelo peso, não uma lista de valores a tentar um
a um; e quando a propagação esvazia uma célula -- uma contradição -- ele não
volta atrás, recomeça da *seed* seguinte e conta os recomeços -- a não ser
que nenhuma célula tenha colapsado ainda, quando só os *tiles* e as fixações
estavam em jogo e nenhuma *seed* ajudaria. Uma diferença do mxgmn, que
observa "a menor entropia não nula": em termos de CSP, uma célula reduzida a
um *tile* ainda não foi atribuída, então é escolhida primeiro, sem sorteio,
onde o mxgmn a conta como já observada. O mapa sai o mesmo. A lição é que o
WFC não é um algoritmo à parte: é um CSP com uma ordem própria e sem
*backtracking*.

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

O *wave function collapse*, em particular: não quando o mapa precisa de algo
que nenhum par de vizinhos enxerga -- uma passagem, cobertura perto de cada
partida, uma saída só. Ele só mantém os vizinhos de acordo, então confira o
mapa inteiro depois de pronto (o modo no estilo XCOM recusa os mapas que não
consegue jogar) ou declare a regra como restrição global e deixe o
`ConstraintSolver` fazer *backtracking*. Não num mapa tão grande que
recomeçar tudo por uma contradição custe mais que voltar atrás. E não quando
os mapas devem parecer uma imagem que você já tem: isso é o modelo
*overlapping* do mxgmn, que aprende a vizinhança de um exemplo; este é o
modelo *simple tiled*, a quem ela é dita. E não para um *tile* com direção
-- terreno alto só à esquerda de um penhasco --, porque `left_right` lista
os *tiles* permitidos de qualquer dos lados: a vizinhança aqui é simétrica
em cada eixo.

## Onde ver {#watch}

- `make demo-infiltration` -- **L** até um nível gerado, depois **K**: o
  primeiro toque resolve o nível em vez de sorteá-lo, o segundo também
  reproduz o *solver* na tela. Nela, a coisa prestes a ser posta tem cada um
  dos seus lugares candidatos desenhado, branco enquanto possível e um X
  vermelho depois que a propagação o riscou; toda coisa ainda não posta
  aparece numa lista com quantos lugares lhe restam, a próxima primeiro; um
  valor desfeito por um *backtrack* pisca em vermelho; a última recusa diz
  qual restrição recusou. **N** monta outro nível do mesmo jeito.
- `make demo-tactical MODE=squad` -- o modo no estilo XCOM. **N** constrói
  um mapa novo por *wave function collapse* e começa uma partida nele; **B**
  mostra um sendo construído, uma célula por toque. Em cada célula aberta, o
  número de *tiles* que ela ainda pode ser; a célula de menor entropia,
  prestes a colapsar, em âmbar, com a entropia e os *tiles* restantes na
  primeira linha do status; o toque seguinte a colapsa, e as contagens em
  volta caem enquanto a propagação risca *tiles*. Uma contradição fica no
  tabuleiro como um 0 vermelho onde nenhum *tile* cabe, e o toque seguinte
  recomeça da *seed* seguinte. **N** termina a construção de uma vez. A
  primeira linha do status diz então a *seed* do mapa, suas contradições e
  quantos mapas as regras recusaram.
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
| label | o último argumento de ambas, "" por padrão | o nome que uma recusa informa em `trace`; uma restrição sem nome vale do mesmo jeito |
| *seed* | `ConstraintSolver.new(problem, seed)` | para que lado vão os empates, o mesmo em GDScript e em Python |
| mrv, lcv, propagate | propriedades do *solver*, todas ligadas | desligue uma para ver quanto ela vale: o mesmo problema, os *backtracks* contados dos dois jeitos |
| record | uma propriedade, desligada | guarda cada passo em `trace` -- escolhido, atribuído, recusado, riscado, desfeito -- para uma visualização |
| limit | uma propriedade, 0 para nenhum | o máximo de atribuições antes de desistir; `gave_up` diz então que nenhuma resposta foi provada impossível |

Os mapas do modo no estilo XCOM (`godot/game/squad/squad_map_build.gd`) são
*wave function collapse* nos 14 por 9 do mapa tático, com os *tiles* de
`spec/squad/tiles.json`: terreno aberto, árvores, rocha, água, a ponte e o
vau -- o terreno que o jogo tático já desenha, então um mapa gerado parece o
jogo a que pertence. Cada *tile* lista os *tiles* que podem ficar ao seu
lado, à esquerda ou à direita, e acima ou abaixo; a ponte e o vau têm água
acima e abaixo, a rocha nunca fica na água. As oito partidas são fixadas em
terreno aberto, e um mapa pronto passa por duas regras do T84 antes de ser
jogado: as partidas ligadas a pé, e cobertura a uma ação de cada uma. Um
mapa que falha é recusado, e a *seed* seguinte é construída. Medido em vinte
mapas a partir da *seed* 1: nenhuma contradição, três mapas recusados (dois
com uma partida longe de cobertura, um murado). Os controles:

| controle | onde | o que muda |
|---|---|---|
| *tileset* | `TileGrid.problem(tile_set, size, pinned)` | os *tiles*, cada um com seu `weight` e seus vizinhos `left_right` e `up_down`; um par dito de um lado só é recusado por `TileGrid.why_not` |
| pinned | o terceiro argumento, "x,y" -> *tiles* | as células que só podem ser alguns *tiles*: as partidas dos esquadrões, terreno aberto |
| pesos | `WaveCollapse.new(problem, weights, seed)` | quantas vezes cada *tile* é sorteado, e assim a entropia de uma célula |
| attempts | uma propriedade, 10 | quantas *seeds* tentar antes de dizer que não há mapa; `restarts` e `contradictions` dizem o que houve com as outras |
| record | a do *solver*, desligada | o rastro que uma visualização reproduz: cada célula escolhida, o *tile* sorteado, cada *tile* riscado, e um evento "contradiction" onde uma tentativa acabou |

## No seu projeto {#your-project}

### O que copiar {#copy}

Duas pastas: `godot/addons/ai_constraints/` e o núcleo,
`godot/addons/ai_core/`, cujo `GakXorshift` dá os sorteios com *seed* que
ordenam os empates (T135; o *addon* carregava uma cópia dele). O *wave function collapse* são dois arquivos dela,
`wave_collapse.gd` e `tile_grid.gd`, e precisa dos do *solver*. Abra o projeto uma vez, ou rode `godot --headless --import`,
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
- O *wave function collapse* na fonte, os modelos *simple tiled* e
  *overlapping*, e os jogos que o usam: mxgmn,
  [WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse).
  Os vetores e as regras que as duas linguagens seguem:
  [spec/vectors/constraints/collapse/](../../spec/vectors/constraints/collapse/README.md).
- Onde a satisfação de restrições fica entre as técnicas da área:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
