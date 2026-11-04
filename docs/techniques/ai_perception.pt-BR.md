# ai_perception — o que um guarda vê, ouve e acredita

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: book:Travis McIntosh, "Human Enemy AI in The Last of Us", in Steve Rabin (ed.), "Game AI Pro 2", CRC Press, 2015 ; https://www.gameaipro.com/
invalidated_if: the kit's VisionCone, Awareness, LineOfSight, Hearing, VisionShape, BeliefMap or ParticleBelief signatures change, or the demos that use them are renamed
teaches: perception
translation_of: dec1b33831dd8ac6b08ed7f2a445c7f3b6779215677b8867c937cf280722f496
-->

> English: [ai_perception.md](ai_perception.md). Os termos que ficam em
> inglês estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

O que um agente sabe do mundo, antes de qualquer coisa decidir o que fazer
a respeito. Visão: `VisionCone` -- perto o bastante, dentro do ângulo para
onde ele olha, nada no caminho --, numa grade com `LineOfSight`, ou em campo
aberto com o seu próprio teste de linha; `VisionShape` para um corpo meio
visto, como uma certeza. Audição: `Hearing` através das paredes,
`PathHearing` contornando-as. Dúvida: `Awareness`, um número que sobe
enquanto algo é percebido e desce passando por cada fase intermediária --
calmo, desconfiado, alerta -- quando não é. E crença: `TargetMemory` guarda
só o que foi percebido, `BeliefMap` espalha onde o alvo pode estar desde
então, e `ParticleBelief` responde à mesma pergunta com uma nuvem de
palpites que andam como uma pessoa e rareiam onde um guarda olhou e
escutou. As fontes: McIntosh, *Human Enemy AI in The Last of Us*, em *Game AI
Pro 2* (2015), e as outras que [concepts/stealth-ai.md](../concepts/stealth-ai.md)
lista.

## Quando não usar {#when-not}

Centenas de observadores num mapa grande: perguntar célula por célula é
lento -- lance raios para fora uma vez por observador, ou use a física da
*engine*. Um alvo que nunca é meio visto -- um item, uma porta -- precisa do
sim ou não de um cone, não de um `VisionShape`. E uma percepção que lê o
que o agente nunca percebeu -- "saber" para onde o jogador foi por alguns
segundos depois de perdê-lo de vista -- fica de fora de propósito: o
jogador sente isso como trapaça.

## Onde ver funcionando {#watch}

- `make demo-stealth` -- o cone de cada guarda é desenhado no chão; **D**
  pinta cada célula pelo quanto ela é vigiada (um `InfluenceMap` dos cones).
- `make demo-behaviour` -- os sentidos do guarda são um `VisionCone` e um
  `Hearing`, os mesmos para os seus quatro cérebros; **espaço** joga um
  turno.
- `make demo-infiltration` -- guardas com um `VisionShape`, um `Awareness`,
  `PathHearing` e um `BeliefMap` ou um `ParticleBelief` quando procuram.
  Sobre cada guarda fica a sua barra de detecção, com os limiares das fases
  como marcas; **1** alterna a crença -- desligada, a grade, as partículas
  --, **H** mostra o raciocínio, **Tab** observa o próximo guarda. Com as
  partículas ligadas, a nuvem do guarda observado aparece como pontos, um
  quadrado branco pisca em cada célula que a visão dele acabou de esvaziar,
  e uma cruz roxa marca o ponto que ele escolheu procurar a partir da
  nuvem.
- `make demo-botmatch` -- cada *bot* vê com um `VisionCone` em campo aberto,
  contra as paredes da arena.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/demos/behaviour/guard_senses.gd` é o menor uso completo: um cone e
uma audição numa grade, alimentando uma suspeita. `godot/game3d/infiltration/`
usa o resto, cada tipo de guarda uma linha de JSON. Os ajustes que
importam:

| ajuste | onde | o que muda |
|---|---|---|
| alcance e ângulo | `VisionCone.new(reach, half_angle_degrees)` | até onde e com que abertura ele vê; `all_round_within` acrescenta um círculo que ele sente para onde quer que olhe |
| o que bloqueia a visão | `VisionCone.new(..., opaque_from_cost)`, ou o seu `line_is_clear` | numa grade, terreno pelo menos tão caro assim é opaco; em campo aberto, quem decide é o seu *raycast* |
| as fases | uma linha de *awareness*: `peak`, `decay`, `phases`, `caution` | onde calmo vira desconfiado vira alerta, a rapidez da descida, quanto tempo ele fica cauteloso depois de um alerta |
| a subida | `Awareness.step(row, perceived, rate, seconds, now)` | a rapidez com que ele fica atento enquanto percebe; calculada por quem lê a percepção |
| o alcance de um som | `Hearing.loudness_at(listener, source, radius)` | até onde um barulho chega; `PathHearing` mede contornando as paredes |
| os modelos das partículas | `walk_on` (0,7), `turn` (0,2), `unheard` (0,3) e a contagem de `ParticleBelief` | como um alvo suposto se move, e quanto "não ouvi nada" pesa contra um palpite |

## Um filtro de partículas {#particles}

O capítulo 14 do AIMA acompanha um estado escondido ao longo do tempo com
dois modelos: como ele se move (transição) e o que um sensor diz dado onde
ele está (sensor). Filtrar é manter uma crença e atualizá-la a cada passo
com os dois. Exato, sobre um grafo, isso é o `BeliefMap` com uma transição
melhor -- mas "um guarda não ouviu nada daqui" e "uma pessoa continua
andando para onde ia" são difíceis de escrever como uma tabela só. A seção
14.5.3 ("Approximate inference in DBNs") faz isso por amostragem: guarde
algumas centenas de palpites, mova cada um pela transição, pese cada um
pelo sensor, reamostre pelo peso. A robótica fez disso o jeito padrão de
acompanhar algo que não se vê [Thrun 2002].

`ParticleBelief` faz isso sobre a mesma lista de vizinhos do `BeliefMap`:

- **transição**: um palpite segue em frente para um vizinho que não é de
  onde veio com `walk_on`, vira para qualquer vizinho com `turn`, e senão
  fica. Num grafo sem geometria, "manter o rumo" só pode querer dizer "não
  voltar"; é o que quer dizer aqui.
- **sensor**: um palpite numa célula que um guarda vê, quando ele não viu
  ninguém, pesa 0; um numa célula de onde o guarda teria ouvido um passo,
  quando ele não ouviu nada, pesa `unheard`; qualquer outro, 1. Não 0 para
  o silêncio: um jogador deitado não faz barulho.
- **reamostragem**: sistemática, a cada passo. Se todo peso for 0, a nuvem
  é semeada de novo, por igual, nas células que nenhum guarda vê, e
  `reseeded` diz isso.

Um avistamento ou um relato colapsa a nuvem numa célula. `shares` é a
nuvem contada por célula, no mesmo formato de `BeliefMap.shares`, então uma
busca lê qualquer um dos dois. Todo sorteio vem do `Xorshift` do
`ai_core`, um gerador com semente escrito nas duas linguagens
(`gameaikit.core` em Python), então uma nuvem é conferida com a sua gêmea em Python
(`gameaikit.perception.particles`) sorteio a sorteio por
`spec/vectors/perception/particles-*.json`.

**Isto não é treino (invariante 6).** Toda probabilidade acima é uma
constante escrita antes de o jogo começar, e nada que o jogo faça muda
nenhuma. Os pesos são refeitos a partir dessas constantes a cada passo,
nunca acumulados de um passo para o outro, o que é inferência --
filtragem --, não um ajuste. `check_no_training.py` concorda
pelo motivo certo: a sua regra N3 procura escritas nos `weights` de um
modelo ou uma atualização composta deles (`weights[i] /= total`), e o
código não faz nenhuma das duas -- cada passo monta um vetor novo de pesos
a partir das constantes, já que os antigos não significam nada depois que
a nuvem se moveu.

**Ele te acha mais cedo?** Medido na fase de infiltração
(`make test-infiltration-tracking`): nenhuma diferença que mereça o nome --
os números estão em [godot/infiltration.md](../godot/infiltration.md#particles-against-the-grid)
(em inglês). Em 35 de 41 partidas pareadas os guardas acharam o jogador no
mesmo instante com qualquer uma das crenças, porque um vislumbre no
caminho colapsa as duas igual; as poucas que diferem vão para os dois
lados, por um ou dois segundos. Os cenários medidos têm pouca força para
separar as duas, e a página diz por quê.

**Dê partículas suficientes.** Menos partículas que nós deixa a maioria dos
nós sem parte nenhuma depois de semear de novo, e uma partícula pode pesar
mais que a parte uniforme de um nó; a fase de infiltração dá duas por
célula. Isso custa: um passo da crença com 1784 partículas mediu 1,5 ms
lá.

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_core-<version>.zip` e o
`ai_perception-<version>.zip` no `res://addons/` do seu projeto -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

Duas pastas: `godot/addons/ai_core/` (a grade, que o cone usa num tabuleiro
em grade) e `godot/addons/ai_perception/` -- para uma crença de partículas
sozinha, bastam `particle_belief.gd` e o `xorshift.gd` do `ai_core`. Abra o projeto uma vez, ou rode
`godot --headless --import`, para o Godot registrar as classes.

### Um exemplo mínimo {#example}

Um guarda seu que vê num cone em campo aberto, fora de qualquer grade, e
vai ficando atento ao que vê aos poucos. Ele olha na direção da sua própria
rotação e funciona onde quer que seja colocado; defina `target` e leia
`phase()`. Este arquivo é executado por `watcher_example_test.gd`, e o
*gate* garante que a página é igual a ele. Os comentários do código ficam
em inglês, como no arquivo.

<!-- example: godot/test/ai_perception/watcher_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_perception.md, run by
# watcher_example_test.gd. A guard of your own that sees in a cone, off any
# grid, and grows aware of what it sees by degrees: calm, then suspicious,
# then alert -- and back down through each when it loses sight.
extends Node2D

## How aware it is, as data: rising past each phase's share of the peak, and
## falling a fifth of the peak a second. Once alert, it stays at least
## suspicious for five seconds.
const AWARENESS: Dictionary = {
	"peak": 1.0,
	"decay": 0.2,
	"phases": [
		{"name": "calm", "at": 0.0},
		{"name": "suspicious", "at": 0.3},
		{"name": "alert", "at": 0.8},
	],
	"caution": {"floor": 0.3, "seconds": 5.0},
}

## How fast awareness rises while it sees, in shares of the peak a second.
const RISE: float = 0.5

## Who it is watching for. Set it from your game.
var target: Node2D

## 300 units of reach, 45 degrees either side of where the node faces.
var cone := VisionCone.new(300.0, 45.0)

var _awareness := Awareness.new()
var _seconds: float = 0.0


func _ready() -> void:
	# A row with phases out of order, or a caution floor above alert, is
	# refused here rather than found out in play.
	if Awareness.problem(AWARENESS) != "":
		push_error(Awareness.problem(AWARENESS))


func _physics_process(delta: float) -> void:
	_seconds += delta
	_awareness.step(AWARENESS, sees_target(), RISE, delta, _seconds)


## True when the target is within reach, inside the cone this node faces
## along (its rotation), and nothing stands between.
func sees_target() -> bool:
	if target == null:
		return false
	return cone.sees_in_the_open(global_position, global_rotation, target.global_position, _line_is_clear)


## "calm", "suspicious" or "alert": what your game shows above the guard.
func phase() -> String:
	return Awareness.phase_name(_awareness.value, AWARENESS)


# Your walls go here: a raycast from the guard to the target, say. The
# open field of this example has none.
func _line_is_clear() -> bool:
	return true
```

### O que você implementa {#implement}

A linha: `_line_is_clear` é onde entram as suas paredes -- um
`PhysicsRayQueryParameters2D` do guarda até o alvo, por exemplo --, e um
`Callable` sem argumentos que devolve um `bool` é tudo o que
`sees_in_the_open` pede. Numa grade, preencha um `GakGridGraph` a partir do
seu mapa e chame `cone.sees(graph, eye, facing, target)` com células
(`Vector2i`) e uma direção que seja um passo, como `Vector2i.RIGHT`. Depois,
o que as fases significam: o *awareness* diz o quanto o guarda tem certeza,
e a sua decisão -- uma árvore, uma máquina de estados, o *utility* do
`ai_teamwork` -- diz o que ele faz com isso. Confira uma linha uma vez com
`Awareness.problem(row)`: `""` quer dizer que ela faz sentido.

## Para ir mais fundo {#deeper}

- O que um guarda percebe, e o quanto isso o deixa desconfiado (em
  inglês): [concepts/stealth.md](../concepts/stealth.md).
- Como os jogos de *stealth* lançados fazem isso, fonte por fonte (em
  inglês): [concepts/stealth-ai.md](../concepts/stealth-ai.md).
- A fase de infiltração, onde cada classe daqui é usada (em inglês):
  [godot/infiltration.md](../godot/infiltration.md).
- As fontes do filtro de partículas, abertas em 2026-10-26: AIMA 4ª ed.,
  cap. 14, seção 14.5.3 "Approximate inference in DBNs"
  (<https://aima.cs.berkeley.edu/contents.html>); Thrun, S. "Particle Filters
  in Robotics", UAI 2002 (<https://arxiv.org/abs/1301.0607>).
