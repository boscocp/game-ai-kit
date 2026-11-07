# ai_steering — para que lado empurrar, e com que força

<!-- doc-meta
half_life: practice
verified_on: 2026-11-07
tier: 2
source: https://www.red3d.com/cwr/steer/gdc99/ ; book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 3 on movement
invalidated_if: the kit's SteeringVehicle, SteeringBehaviour, Steering.combined or Flock signatures change, or the demos that use them are renamed
teaches: steering
translation_of: e95286923e4af5afecba5c49cf7d42f0c200ffd1466252fe22fa5540ca6195a8
-->

> English: [ai_steering.md](ai_steering.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Não para onde ir -- isso é uma busca ou uma decisão acima dele -- mas como
chegar lá num espaço contínuo, um quadro por vez: a força a aplicar agora.
*Seek*, *arrive*, *pursue* e *avoid* transformam "onde eu estou, e onde
aquilo está" numa força nunca maior do que o veículo consegue aplicar, e
`Steering.combined` soma várias com pesos. `Flock` são os *boids* de
Reynolds: *separation*, *alignment* e *cohesion* sobre os vizinhos que cada
*boid* recebe, e aparece um bando sem líder. As demos de corrida acrescentam um
controlador PID e a *heat line* do Melder. O livro: Reynolds, *Steering
Behaviors for Autonomous Characters* (GDC 1999); Millington, *AI for Games*,
capítulo 3.

## Quando não usar {#when-not}

Um modelo de carro de verdade, em que a curva depende da velocidade e da
aderência: aí os comportamentos continuam dizendo para onde ir, e o modelo do
carro diz como. Paredes, corredores e muitos obstáculos juntos: o *avoid* só
conhece círculos, e dois deles empurrando em sentidos opostos deixam o
veículo travado -- ali a resposta é um *flow field* ou uma malha de
navegação. Um grupo que precisa chegar em ordem ou manter uma formação: um
bando não tem lugares nem líder, então siga um caminho ou um líder.

## Onde ver funcionando {#watch}

- `make demo-steering` -- quatro arenas: *seek*, *arrive*, *pursue* e *seek*
  com *avoid*. A seta **laranja** é o que o comportamento pede, a **azul** é
  para onde o veículo está indo: quando discordam, ele está prestes a virar.
  **Clique** move um alvo, **espaço** pausa, **.** avança um quadro.
- `make demo-flocking` -- cem *boids*. **1**, **2** e **3** ligam e
  desligam *separation*, *alignment* e *cohesion*; as três forças do *boid*
  branco são desenhadas em **vermelho**, **azul** e **verde**, com linhas
  **amarelas** até os vizinhos que ele contou. **Clique** põe um obstáculo,
  **Tab** observa o próximo *boid*.
- `make demo-infiltration`, no mercado (**L** depois dos níveis gerados)
  -- uma multidão: três grupos de civis, cada um um `Flock` com três forças
  do jogo somadas por `Steering.combined` (o alvo do passeio dele, e ficar
  longe dos outros grupos, e abrir caminho para você e os guardas, que não
  desviam de ninguém). As paredes não são uma
  força: cada passo é dado na grade de células por onde se anda no nível, deslizando ao longo de
  uma barraca. Ande no passo dentro de um grupo e ele fica circulado no
  chão: você se mistura.
- `make demo-racing` -- o piloto faz *seek* num ponto à frente na linha de
  corrida; **1-3** escolhem a IA, **Tab** assiste às três. `make demo-racing3d`
  esterça com o controlador PID (**1**) e a *heat line* (**2**).
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#ai_steering).

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
| perto demais | `Flock.new(radius)`, `SeparationBehaviour.new(radius)` | dentro dele um vizinho empurra o *boid* para longe, com todo o `max_force` no contato e nada na borda |
| pesos do bando | `Flock.new(radius, seconds, weights)`, *separation*, *alignment*, *cohesion* | 1,5, 1 e 1 por padrão, definidos uma vez; um peso zero desliga uma regra. O 1-3 da demo passa os próprios pesos ao `Steering.combined` |
| visão | sua: quem você passa para `Flock.see(neighbours)` | a demo passa todo *boid* a menos de 50 (perto demais é 25), achado pelo `godot/demos/flocking/neighbour_grid.gd` |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_steering-<version>.zip` na
raiz do seu projeto, `res://` -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

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

Um bando é um `Flock` e a sua busca de vizinhos. Antes de pedir a força de um
*boid*, passe para ele os *boids* que ele enxerga, numa ordem fixa, com
`flock.see(neighbours)`; as três regras nunca os procuram. Cada *boid* contra
todos os outros é O(n^2), bom para algumas dezenas; uma grade de células da
largura do raio de visão, como o `NeighbourGrid` da demo, é cerca de O(n).
Calcule a força de todos antes de mover qualquer um, e duas execuções a
partir do mesmo começo concordam.

## Para ir mais fundo {#deeper}

- Por que o *seek* nunca para e o *arrive* para (em inglês):
  [concepts/steering.md](../concepts/steering.md).
- As três forças do bando calculadas à mão, e o que cada regra faz quando é
  desligada (em inglês): [concepts/steering.md](../concepts/steering.md),
  "Flocking".
- Pilotar um carro numa pista (em inglês):
  [concepts/racing-ai.md](../concepts/racing-ai.md).
