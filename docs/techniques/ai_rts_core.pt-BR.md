# ai_rts_core — muitas unidades, um quadro

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://ojs.aaai.org/index.php/AIIDE/article/view/12435/12294 ; book:Elijah Emerson, "Crowd Pathfinding and Steering Using Flow Field Tiles", in Steve Rabin (ed.), "Game AI Pro", CRC Press, 2013
invalidated_if: the kit's FlowField, SpatialHash, FrameBudget, RtsWorld or RtsController signatures change, or the demos that use them are renamed
teaches: strategy-ai
translation_of: 9c744b516b193a017df870d9bc720956f49ef7d5b2d1ecda739bba161249cca2
-->

> English: [ai_rts_core.md](ai_rts_core.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Como centenas de unidades andam e olham em volta dentro de um sexagésimo
de segundo. Um *flow field* (`FlowField`) responde "como chego àquela
célula?" uma vez para todos que vão para lá: uma inundação de Dijkstra a
partir do objetivo dá a cada célula uma seta, e uma unidade lê a seta sob
os seus pés -- montado uma fatia por quadro, para nunca ocupar um quadro
inteiro. Um *spatial hash* (`SpatialHash`) responde "quem está perto deste
ponto?" lendo só os baldes que um círculo toca. Um *frame budget*
(`FrameBudget`) diz como o quadro é repartido e mede cada camada contra a
sua parte. Em volta deles, `RtsWorld` é uma partida inteira e
determinística -- uma semente e uma lista de comandos sempre terminam
iguais --, que uma IA só vê por um `RtsSnapshot` congelado e só muda por
`RtsCommand`s que ele pode recusar.

## Quando não usar {#when-not}

Poucas unidades com muitos objetivos diferentes: cada campo é montado para
um leitor só, e o A\* do `ai_search`, que para quando chega, sai mais
barato. Unidades de tamanhos muito diferentes, ou perguntas que cobrem
quase o mapa todo: uma *quadtree* ou uma varredura simples ganham do
*hash*. E qualquer coisa por turnos ou com busca sobre jogadas: `RtsWorld`
muda no lugar, então uma busca não consegue tentar uma jogada e desfazê-la
-- o tabuleiro dos exemplos faz isso (ADR 0019).

## Onde ver funcionando {#watch}

- `make demo-rts` -- cada unidade a que você dá uma ordem anda por um *flow
  field* compartilhado; **arrastar** seleciona, **clique direito** dá a
  ordem. **V** assiste a dois computadores jogando, **I** mostra a
  influência que o comandante lê, **F** liga e desliga a névoa que
  `RtsWorld.visible_to` calcula.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/game/rts/` é o RTS construído sobre este núcleo: `rts.gd` avança um
`RtsWorld` a 60 *ticks* por segundo, o mundo assenta no máximo
`RtsWorld.FIELD_CELLS_PER_TICK` células de *flow field* por *tick*, e
`rts_commander.gd` é um `RtsController` que planeja. Os ajustes que
importam:

| ajuste | onde | o que muda |
|---|---|---|
| células por *tick* | `FlowField.settle(budget)`; o `FIELD_CELLS_PER_TICK` do mundo | quão cedo um campo novo fica pronto, contra quanto do quadro ele ocupa |
| custo das células | `GridGraph.set_cost`, `GridGraph.block` | para onde as setas levam; um campo já montado não vê uma mudança |
| tamanho do balde | `SpatialHash.new(size)` | mais ou menos o raio que a maioria das perguntas usa; menor lê mais baldes, maior descarta mais |
| as partes | `FrameBudget.SHARES` | os milissegundos que cada camada pode ocupar dos 16,7 |
| a frequência das decisões da IA | `RtsMatch.decide_every` | *ticks* entre decisões; meio segundo por padrão |

## No seu projeto {#your-project}

### O que copiar {#copy}

Duas pastas: `godot/addons/ai_core/` (a grade que o campo inunda) e
`godot/addons/ai_rts_core/`. Abra o projeto uma vez, ou rode `godot
--headless --import`, para o Godot registrar as classes. `FlowField`,
`SpatialHash` e `FrameBudget` são genéricos. **Um achado:** `RtsWorld`,
`RtsRules`, `RtsOrders` e `RtsKinds` são o RTS do próprio kit -- com os seus
tipos de unidade, custos e ordens escritos dentro -- e não dá para ligá-los
a outro jogo em poucas linhas; leve as três classes genéricas, ou o RTS
inteiro como ele é.

### Um exemplo mínimo {#example}

Um mapa seu em que qualquer número de unidades é mandado para uma célula.
O campo é montado uma fatia por quadro; depois cada unidade pergunta
`step_from(cell)` e anda para lá, contornando uma parede, pela sua
abertura. Este arquivo é executado por `flow_example_test.gd`, e o *gate*
garante que a página é igual a ele. Os comentários do código ficam em
inglês, como no arquivo.

<!-- example: godot/test/ai_rts_core/flow_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_rts_core.md, run by
# flow_example_test.gd. A map of your own where any number of units are
# sent to one cell, and the way there is worked out once for all of them,
# a slice every frame.
extends Node

## How many cells the flood may settle in one frame: the share of the frame
## you give it. More, and the field is ready sooner.
const CELLS_PER_FRAME: int = 64

## Your map: 1 is open ground, dearer cells are slower, blocked is a wall.
## Change it before you send anyone; a field already built does not see it.
var map := GridGraph.new(24, 16)

var _field: FlowField


func _physics_process(_delta: float) -> void:
	if _field != null:
		_field.settle(CELLS_PER_FRAME)


## Send everybody to `goal`. The field is built over the next frames.
func send_everyone_to(goal: Vector2i) -> void:
	_field = FlowField.new(map, goal)


## Which way a unit standing on `cell` steps now: one of the four
## directions, or zero when it has arrived, when nothing reaches the goal
## from there, or while the field is still being built.
func step_from(cell: Vector2i) -> Vector2i:
	if _field == null or not _field.complete:
		return Vector2i.ZERO
	return _field.direction_at(cell)
```

### O que você implementa {#implement}

As unidades e o movimento. Uma unidade sua transforma a posição numa
célula, pergunta `step_from` e anda até o centro da próxima célula na sua
própria velocidade -- suave, com o seu próprio *steering* ou
`CharacterBody2D`; o campo só diz para que lado. Preencha `map` a partir do
seu `TileMapLayer` (`set_cost`, `block`) e monte um campo novo quando ele
mudar. Um campo para cada lugar aonde alguém vai é um `FlowField` cada;
guarde os que estão em uso e descarte o resto, como o `RtsWorld` faz depois
de um segundo sem ninguém perguntar. Para achar quem está perto, registre
cada unidade com `SpatialHash.place(id, position)` toda vez que ela se mexer
e pergunte `near(centre, radius)`.

## Para ir mais fundo {#deeper}

- O RTS: um comandante que planeja, contra um relógio (em inglês):
  [concepts/rts-ai.md](../concepts/rts-ai.md).
- Por que o núcleo do RTS muda no lugar e o tabuleiro copia (em inglês):
  [ADR 0019](../adr/0019-two-cores-one-that-copies-one-that-mutates.md).
- A grade em si: [ai_core](ai_core.pt-BR.md).
