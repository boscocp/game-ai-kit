# ai_steering — para que lado empurrar, e com que força

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.red3d.com/cwr/steer/gdc99/ ; book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 3 on movement
invalidated_if: the kit's SteeringVehicle, SteeringBehaviour or Steering.combined signatures change, or the demos that use them are renamed
teaches: steering
translation_of: 019b6629b9ea352945d78ebe7ed962276b2c7091f4d9231a094fa10c4f1c87d3
-->

> English: [ai_steering.md](ai_steering.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Não para onde ir -- isso é uma busca ou uma decisão acima dele -- mas como
chegar lá num espaço contínuo, um quadro por vez: a força a aplicar agora.
*Seek*, *arrive*, *pursue* e *avoid* transformam "onde eu estou, e onde
aquilo está" numa força nunca maior do que o veículo consegue aplicar, e
`Steering.combined` soma várias com pesos. As demos de corrida acrescentam um
controlador PID e a *heat line* do Melder. O livro: Reynolds, *Steering
Behaviors for Autonomous Characters* (GDC 1999); Millington, *AI for Games*,
capítulo 3.

## Quando não usar {#when-not}

Um modelo de carro de verdade, em que a curva depende da velocidade e da
aderência: aí os comportamentos continuam dizendo para onde ir, e o modelo do
carro diz como. Paredes, corredores e muitos obstáculos juntos: o *avoid* só
conhece círculos, e dois deles empurrando em sentidos opostos deixam o
veículo travado -- ali a resposta é um *flow field* ou uma malha de
navegação.

## Onde ver funcionando {#watch}

- `make demo-steering` -- quatro arenas: *seek*, *arrive*, *pursue* e *seek*
  com *avoid*. A seta **laranja** é o que o comportamento pede, a **azul** é
  para onde o veículo está indo: quando discordam, ele está prestes a virar.
  **Clique** move um alvo, **espaço** pausa, **.** avança um quadro.
- `make demo-racing` -- o piloto faz *seek* num ponto à frente na linha de
  corrida; **1-3** escolhem a IA, **Tab** assiste às três. `make demo-racing3d`
  esterça com o controlador PID (**1**) e a *heat line* (**2**).
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/demos/steering/steering_lane.gd` cria um `SteeringVehicle` por arena e
pede ao comportamento uma força a cada quadro de física. Os ajustes que
importam:

| ajuste | onde | o que muda |
|---|---|---|
| velocidade máxima | `SteeringVehicle.max_speed` | o mais rápido que ele anda |
| força | `SteeringVehicle.max_force` | o quanto ele consegue virar e frear; toda força é limitada a isso |
| raio de frenagem | `ArriveBehaviour.new(target, radius)` | onde o *arrive* começa a desacelerar; pequeno demais e ele passa do ponto |
| tempo até o alvo | `SeekBehaviour.new(target, seconds)`, e o mesmo último argumento de `ArriveBehaviour` e `PursueBehaviour` | o quão rápido a velocidade vira a desejada -- uma constante de tempo: cerca de dois terços da diferença se fecham nesses segundos. O padrão do *seek* e do *pursue* é 1, o do *arrive* 0,1; um carro numa linha quer cerca de 0,1. Mantenha-o com vários quadros de duração, ou ele oscila ([por quê, em inglês](../concepts/steering.md)) |
| antecipação | `PursueBehaviour` `max_prediction`, `AvoidBehaviour` `look_ahead` | o quanto ele adivinha à frente, ou procura obstáculos |
| pesos | `Steering.combined(vehicle, forces, weights)` | quanto cada comportamento conta quando vários falam |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_steering/`. Ela não precisa de mais nada, nem do
`ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`, para
o Godot registrar as classes.

### Um exemplo mínimo {#example}

Um `Node2D` seu que se dirige sozinho até `target` e para ali. Mude `target`
a partir de um clique ou de um *waypoint*. Este arquivo é executado por
`arrive_example_test.gd`, e o gate garante que a página é igual a ele. Os
comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_steering/arrive_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_steering.md, run by
# arrive_example_test.gd. A node of your own that drives itself to a point
# and stops there.
extends Node2D

## Where it is going. Set it from anything: a click, a waypoint, a path.
var target: Vector2 = Vector2(300, 200)

## The point the forces move: top speed 120 a second, and it may change its
## velocity by at most 240 a second.
var vehicle := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 120.0, 240.0)


func _ready() -> void:
	# Start where the node was placed, or it would jump to the origin.
	vehicle.position = position


func _physics_process(delta: float) -> void:
	# Brake from 100 units out. Seek here instead, and it overshoots forever.
	var arrive := ArriveBehaviour.new(target, 100.0)
	vehicle.step(arrive.force(vehicle), delta)
	position = vehicle.position
```

### O que você implementa {#implement}

Um comportamento novo é uma classe: estenda `GakSteeringBehaviour` e devolva uma
força em `force(vehicle)`, limitada com `Steering.clamped`. Se o seu nó tem
física própria -- um `CharacterBody2D` -- mantenha o veículo como o ponto
sobre o qual os comportamentos raciocinam, e copie a velocidade dele para
`velocity` antes do `move_and_slide()`.

## Para ir mais fundo {#deeper}

- Por que o *seek* nunca para e o *arrive* para (em inglês):
  [concepts/steering.md](../concepts/steering.md).
- Pilotar um carro numa pista (em inglês):
  [concepts/racing-ai.md](../concepts/racing-ai.md).
