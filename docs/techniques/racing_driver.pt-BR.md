# O piloto de corrida — um ponto à frente, um perfil de velocidade, sem *rubber band*

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.gameaipro.com/ ; https://www.ri.cmu.edu/pub_files/pub3/coulter_r_craig_1992_1/coulter_r_craig_1992_1.pdf
invalidated_if: RacingDriver, RacingLevel or RacingTrack change what they decide, or demo-racing is renamed
teaches: racing-ai
translation_of: 3f5e2ddda970e0bf22764b8b1b4f8c6322fa932b5cab443ac78b2ec5f4cabca1
-->

> English: [racing_driver.md](racing_driver.md). Os termos que ficam em
> inglês estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Duas coisas a cada passo, as duas que todo piloto de IA decide. **Para
onde esterçar**: para um ponto a uma distância fixa à frente na linha de
corrida -- a ideia única do *pure pursuit* --, perguntado ao *seek* do
`ai_steering` e transformado numa taxa de curva. **A que velocidade**: não
mais rápido do que o perfil de velocidade da pista permite aqui. O perfil é
calculado uma vez: o limite de cada curva a partir da sua curvatura e da
aderência do carro, depois levado para trás ao longo da linha na frenagem
do carro, então segui-lo é frear na hora certa. A dificuldade são três
ajustes fixos durante a corrida inteira -- o quanto ele olha à frente,
quanto da aderência ele ousa usar, o quanto ele se desvia da linha -- e
nunca um *rubber band* que acelera um carro porque ele ficou para trás. As
fontes: os capítulos de corrida de *Game AI Pro*, e o *pure pursuit* de
Coulter (1992).

## Quando não usar {#when-not}

Corrida roda com roda: este piloto ultrapassa o carro da frente, mas não
defende, não fecha e não escolhe o momento -- a *heat line* do corredor 3D
é como os jogos lançados escolhem onde ultrapassar. Um carro cuja curva é
um modelo de pneu completo: o perfil supõe um limite de aderência, e um
carro que derrapa precisa do seu controlador (`make demo-racing3d` esterça
com um PID). E uma pista que muda durante a corrida: o perfil é calculado
a partir da linha uma vez só.

## Onde ver funcionando {#watch}

- `make demo-racing` -- corra contra uma IA no mesmo carro. **1-3** escolhem
  o nível dela, **Tab** assiste às três IAs; a sobreposição desenha o ponto
  para onde cada piloto mira e o ponto de frenagem para o qual ele já
  precisa estar desacelerando.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/demos/racing/racing_driver.gd` decide; `racing_track.gd` monta a
linha de corrida e o seu perfil de velocidade a partir de nós fixos;
`racing_level.gd` é uma dificuldade, os três ajustes e mais nada;
`racing_car.gd` é o carro que você e a IA dirigem.
`godot/test/demo_racing/racing_does_not_cheat.gd` garante que nenhum
ajuste muda durante uma corrida. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| *lookahead* | `RacingLevel.lookahead` | quantos metros à frente na linha ele mira; mais longo entra na curva antes e mais suave, mais curto ziguezagueia |
| margem de aderência | `RacingLevel.grip_margin` | a parte da aderência e dos freios que ele ousa usar; menos freia antes e faz a curva mais devagar |
| desvio | `RacingLevel.wander` | quantos metros o ponto mirado se afasta da linha; o piloto que não está exatamente nela |

## No seu projeto {#your-project}

### O que copiar {#copy}

Nada do lado Python: este piloto não é treinado, e não tem metade em
Python -- `python/gameaikit/racing/` é o piloto do corredor 3D, outro. No
Godot, `godot/addons/ai_steering/` para o veículo e o *seek*. **Um achado:**
o `RacingDriver` não dá para ligar a outro jogo em poucas linhas: ele lê o
`RacingTrack`, cuja linha é montada a partir dos nós fixos da própria demo,
e dirige o `RacingCar`. O exemplo abaixo são as duas ideias sozinhas,
sobre qualquer linha que você der a ele.

### Um exemplo mínimo {#example}

Um carro seu que dá voltas numa linha de corrida que você entrega -- um
`Path2D` assado, por exemplo: ele mira alguns pontos à frente e nunca anda
mais rápido do que o perfil de velocidade da linha permite. Colocado fora
da linha, ele a encontra. Este arquivo é executado por
`racing_line_example_test.gd`, e o *gate* garante que a página é igual a
ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/demo_racing/racing_line_example.gd -->
```gdscript
# The minimal example on docs/techniques/racing_driver.md, run by
# racing_line_example_test.gd. A car of your own that drives round a racing
# line: it steers at a point ahead on the line, and is never faster than the
# line's speed profile says it can be and still take what is coming.
extends Node2D

## The racing line: a closed loop of points a few units apart, in the same
## space as `position` -- a baked Path2D, say. Set it before the node enters
## the tree.
var line := PackedVector2Array()
## How many points ahead it steers at. More cuts corners and steadies the
## car; fewer follows the line tightly and weaves.
var lookahead: int = 8
## The difficulty: the share of the grip it dares to use. 1 is on the limit;
## below it brakes earlier and corners slower. No rubber band.
var grip_margin: float = 1.0

## How hard it can turn and brake, units a second squared: a corner of
## radius r is taken at most at sqrt(GRIP * r).
const GRIP: float = 300.0
const BRAKING: float = 400.0
## How quickly it closes on the velocity it wants: a tenth of a second.
const RESPONSE: float = 10.0

## Top speed 400 a second; it may change its velocity by 600 a second.
var vehicle := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 400.0, 600.0)
## The fastest it will be at each point of the line.
var speed_limits := PackedFloat64Array()

var _at: int = 0


func _ready() -> void:
	vehicle.position = position
	speed_limits = speed_profile(line, GRIP * grip_margin, BRAKING * grip_margin, vehicle.max_speed)
	_at = _nearest(0, line.size())


func _physics_process(delta: float) -> void:
	_at = _nearest(_at, 2 * lookahead)
	var aim: Vector2 = line[(_at + lookahead) % line.size()]
	# Seek, with the profile's speed in place of top speed: the force is
	# the velocity it wants minus the one it has, closed at RESPONSE.
	var wanted: Vector2 = vehicle.position.direction_to(aim) * speed_limits[_at]
	vehicle.step((wanted - vehicle.velocity) * RESPONSE, delta)
	position = vehicle.position


## Each point's speed limit: the corner there, sqrt(grip / curvature), then
## carried backwards, so the car is slow enough to brake for every corner
## ahead in time. Twice round the loop, so the last corner reaches the first.
static func speed_profile(points: PackedVector2Array, grip: float, braking: float, top: float) -> PackedFloat64Array:
	var count: int = points.size()
	var limits := PackedFloat64Array()
	for index: int in range(count):
		var bend: float = _curvature(points[index - 1], points[index], points[(index + 1) % count])
		limits.append(top if bend == 0.0 else minf(top, sqrt(grip / bend)))
	for step: int in range(2 * count, 0, -1):
		var here: int = (step - 1) % count
		var next: int = step % count
		var room: float = points[here].distance_to(points[next])
		limits[here] = minf(limits[here], sqrt(limits[next] * limits[next] + 2.0 * braking * room))
	return limits


# The point of the line nearest the car among the `span` from `from` on.
func _nearest(from: int, span: int) -> int:
	var best: int = from
	for ahead: int in range(span):
		var index: int = (from + ahead) % line.size()
		if vehicle.position.distance_to(line[index]) < vehicle.position.distance_to(line[best]):
			best = index
	return best


# One over the radius of the circle through three points; 0 on a straight.
static func _curvature(before: Vector2, here: Vector2, after: Vector2) -> float:
	var twice_area: float = absf((here - before).cross(after - before))
	var sides: float = before.distance_to(here) * here.distance_to(after) * after.distance_to(before)
	return 0.0 if sides == 0.0 else 2.0 * twice_area / sides
```

### O que você implementa {#implement}

A linha: um laço fechado de pontos igualmente espaçados -- desenhe um
`Path2D`, e `curve.get_baked_points()` os entrega. O carro: o exemplo usa
um `SteeringVehicle` no lugar dele; um `CharacterBody2D` seu copia a
velocidade do veículo para `velocity` antes do `move_and_slide()`, e um
carro que só consegue virar toma o ângulo até o ponto mirado como o seu
esterço, como o `RacingDriver.pursuit_turn` faz. E os níveis: dê a cada um
um *lookahead* e uma margem de aderência -- e, se acrescentar um desvio,
afaste o ponto mirado para o lado --, fixos durante a corrida inteira.

## Para ir mais fundo {#deeper}

- Como se faz a IA de corrida, e de onde vem cada ajuste (em inglês):
  [concepts/racing-ai.md](../concepts/racing-ai.md).
- *Steering*, a força por baixo de tudo: [ai_steering](ai_steering.pt-BR.md).
