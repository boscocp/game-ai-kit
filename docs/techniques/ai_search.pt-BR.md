# ai_search — achar um caminho

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 3 ; https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
invalidated_if: the kit's Search, SearchGraph, GridPathfinder or GridGraph signatures change, or the demos that use them are renamed
teaches: search
translation_of: 7515c335339af63e12c53fcbdbf19b6513b13f18212917553ea13a52107239c4
-->

> English: [ai_search.md](ai_search.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Por quais células passar para ir daqui até ali, e quanto custa esse caminho.
Quatro buscas respondem isso -- largura (*breadth-first*), profundidade
(*depth-first*), Dijkstra e A\* -- e uma quinta, `CostFlood`, responde "tudo
o que eu alcanço com esse orçamento", que é até onde um som chega contornando
uma parede. Cada busca também devolve *o que ela olhou* (`expanded`), e é
essa a parte que vale a pena ver. O livro: Russell e Norvig, *AIMA*,
capítulo 3.

## Quando não usar {#when-not}

Quando o que importa é desempenho. O `AStarGrid2D` do próprio Godot é C++ e
ganha de todas as buscas daqui; estas foram escritas para serem lidas. E
quando não dá para estimar a distância até o objetivo -- um grafo de estados
abstratos em vez de um mapa -- o A\* não tem em que se apoiar e vira um
Dijkstra com passos a mais.

## Onde ver funcionando {#watch}

- `make demo-search` -- as quatro buscas num tabuleiro que você pinta.
  **1-4** escolhem a busca, **espaço** revela mais uma célula expandida,
  **enter** revela o resto: você vê a fronteira crescer, não só a rota.
- `make demo-behaviour`, `make demo-stealth` e `make demo-skirmish` usam a
  busca por baixo para mover um guarda ou uma unidade; dois dos exemplos 3D
  também, `make demo-infiltration` (por onde um guarda anda, até onde um som
  chega) e `make demo-botmatch` (por onde um bot anda).
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#ai_search).

## Neste kit {#in-this-kit}

`godot/demos/search/search_demo.gd` monta um `GakGridGraph` a partir de um
tabuleiro com nome, embrulha-o em `GridSearchGraph.new(grid)` -- o adaptador
que deixa uma busca ler uma grade -- roda as quatro buscas nele e repete
`SearchResult.expanded` uma célula por vez. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| qual busca | `AStarSearch`, `DijkstraSearch`, `BreadthFirstSearch`, `DepthFirstSearch` | a ordem em que a fronteira é consumida -- e com ela a rota e o trabalho |
| o custo de uma célula | `GakGridGraph.set_cost(cell, cost)` | quanto custa entrar nela; no mínimo 1, `GakGridGraph.BLOCKED` é parede |
| a estimativa | `GakSearchGraph.estimate` | a heurística do A\*; precisa ser *consistente*, e zero transforma o A\* em Dijkstra |
| o limite | `CostFlood.within(GridSearchGraph.new(grid), from, limit)` | até onde a inundação se espalha |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_core-<version>.zip` e o
`ai_search-<version>.zip` na raiz do seu projeto, `res://` -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

Duas pastas, mais nada: `godot/addons/ai_core/` (a grade e a porta
`GakPathfinder`) e `godot/addons/ai_search/`. Não há plugin para ativar -- cada
classe se registra pelo `class_name`. Abra o projeto uma vez, ou rode
`godot --headless --import`, para o Godot refazer a lista de classes.

### Um exemplo mínimo {#example}

Um nó seu que acha uma rota ao entrar na cena. Anexe-o a qualquer nó;
`route` guarda as células a percorrer. Este arquivo é executado por
`route_example_test.gd`, e o gate garante que a página é igual a ele. Os
comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_search/route_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_search.md, run by
# route_example_test.gd. A node of your own that finds a route across a
# board of its own as it enters the scene tree.
extends Node

## The route it found: the start left out, the goal included.
var route: Array[Vector2i] = []


func _ready() -> void:
	# Six by four, open ground, and a wall down column 3 with a gap at the
	# bottom -- the route has to find the gap.
	var board := GakGridGraph.new(6, 4)
	for row: int in range(0, 3):
		board.block(Vector2i(3, row))
	# Held as ai_core's GakPathfinder, so the caller does not care which search
	# answers: swap AStarSearch for DijkstraSearch and nothing else changes.
	var pathfinder: GakPathfinder = GridPathfinder.new(AStarSearch.new())
	route = pathfinder.find_path(board, Vector2i(0, 0), Vector2i(5, 0))
```

### O que você implementa {#implement}

Nada, numa grade quadrada: preencha um `GakGridGraph` a partir do seu
`TileMapLayer` (um `set_cost` por tile). Só para a rota, entregue-o a um
`GakPathfinder`, como no exemplo. Para ver também o que a busca olhou,
embrulhe-o: `AStarSearch.new().search(GridSearchGraph.new(grid), from, to)`
devolve um `SearchResult` com `path`, `cost`, `expanded` e `frontier` -- uma
busca recebe um `GakSearchGraph`, e um `GakGridGraph` não é um. Em qualquer outra
coisa --
*waypoints*, salas, os polígonos de uma malha de navegação -- estenda
`GakSearchGraph` com quatro métodos (`contains`, `neighbours`, `cost_at`,
`estimate`) e chame `search(graph, from, to)` em qualquer uma das quatro;
`godot/test/ai_search/waypoint_test.gd` é um completo.

## Para ir mais fundo {#deeper}

- Por que cada busca se comporta como se comporta (em inglês):
  [concepts/search.md](../concepts/search.md).
- Cada campo de `SearchResult`, e um grafo que não é grade (em inglês):
  [godot/search.md](../godot/search.md).
- A grade em si: [ai_core](ai_core.pt-BR.md).
