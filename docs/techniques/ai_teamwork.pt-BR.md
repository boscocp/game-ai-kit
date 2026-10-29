# ai_teamwork — um time que divide o trabalho

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://www.gameaipro.com/
invalidated_if: the kit's RoleArbiter, TeamCommander, TacticalPositions, SquadConfidence or SearchCoordinator signatures change, or the demos that use them are renamed
teaches: shooter-ai
translation_of: 61eefd262afef21dde5194b0a187013043fe895b46369c9ffa64068012045654
-->

> English: [ai_teamwork.md](ai_teamwork.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Como um time divide o trabalho, cada parte uma ponderação própria:
`TeamCommander` manda esquadrões para objetivos, `TacticalPositions`
escolhe onde um *bot* fica e impede dois de reivindicarem o mesmo lugar,
`RoleArbiter` deixa um *bot* flanquear enquanto os outros atiram,
`SearchCoordinator` divide os lugares a procurar, `SquadConfidence` diz
quando atacar, segurar ou recuar, e `AimChoice` e `PassageChoice` pesam
onde mirar e como passar por um companheiro. Cada um guarda os seus
números, para uma tela mostrar o porquê. O que um *bot* faz agora, e as
saídas do posto, não estão aqui: desde a T101 são do
[`ai_utility`](ai_utility.pt-BR.md), porque nada neles é sobre um time. As
fontes: os capítulos do *Game AI Pro* que cada classe cita.

## Quando não usar {#when-not}

Um esquadrão só, ou um único lugar onde ficar: o mais próximo primeiro dá a
mesma resposta com menos a explicar. Papéis que são lugares, não tarefas --
quem segura qual porta: isso é o `TacticalPositions` com reivindicações,
não o `RoleArbiter`. E um time cujos membros precisam agir numa ordem fixa,
uma invasão e depois uma varredura: isso é de um plano (`ai_planning`), não
de uma ponderação que cada *bot* refaz a cada decisão.

## Onde ver funcionando {#watch}

- `make demo-botmatch` -- seis contra seis. **Tab** observa o próximo *bot*:
  os discos em volta dele são cada lugar que ele pesou, com a sua nota.
  **1-3** ligam e desligam as reivindicações, o comandante e o recuo do
  azul (**shift** para os do vermelho), para você ver o time com cada parte
  desligada. **T** assume o *bot* observado.
- `make demo-infiltration` -- os guardas procuram com o `SearchCoordinator`
  e lutam sob o `RoleArbiter`; **2** e **3** ligam e desligam o coordenador
  e o árbitro, **Tab** observa o próximo guarda.
- Qual demo usa qual técnica, nos dois sentidos: o
  [catálogo](catalogue.pt-BR.md).

## Neste kit {#in-this-kit}

`godot/game3d/botmatch/team_tactics.gd` roda o comandante e a confiança dos
esquadrões de cada time, e pergunta ao `TacticalPositions` onde cada *bot*
fica. Os guardas da infiltração dividem a busca por
`godot/game3d/infiltration/guard_team.gd`. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| flanqueadores | `RoleArbiter.grant(requests, use_arbiter, max_flankers)` | quantos podem contornar de uma vez; alguém sempre atira |
| reivindicações | `TacticalPositions.choose(...)` | se um lugar que outro *bot* pegou é descartado |
| o comandante | `TeamCommander.assign(squads, objectives, weights)` | para qual objetivo cada esquadrão vai, e quantos enchem um |
| o recuo | `SquadConfidence.Thresholds` | quando um esquadrão ataca, segura ou recua, e a folga que o impede de oscilar |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_teamwork/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. Toda classe lê números simples que o seu
jogo mediu -- distâncias, linha de tiro já testada --, então nenhuma
precisa da sua cena.

### Um exemplo mínimo {#example}

Um esquadrão seu dividindo uma luta. Três lutadores pedem para flanquear e
um para atirar: o árbitro concede o melhor flanco e os outros atiram; e
quando o único que pode atirar pede para flanquear, ele continua atirando.
Este arquivo é executado por `squad_example_test.gd`, e o *gate* garante
que a página é igual a ele. Os comentários do código ficam em inglês, como
no arquivo.

<!-- example: godot/test/ai_teamwork/squad_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_teamwork.md, run by
# squad_example_test.gd. A squad of your own that shares one fight out:
# each fighter asks for a role, and an arbiter grants one flank at a time
# so the others keep shooting -- teamwork as a referee, not a plan.
extends Node

## At most this many go round at once.
const MAX_FLANKERS: int = 1


## The role each fighter gets, by name -- "shooter", "flanker" or "none".
## `fighters` is [{name, wants_to_flank, flank_score, can_shoot}], each a
## fact your game measured: whether a way round is open, how good it is,
## whether the fighter has a line and rounds.
func roles(fighters: Array[Dictionary]) -> Dictionary:
	var requests: Array[Dictionary] = []
	for fighter: Dictionary in fighters:
		requests.append({
			"role": RoleArbiter.FLANKER if fighter["wants_to_flank"] else RoleArbiter.SHOOTER,
			"score": fighter["flank_score"],
			"can_shoot": fighter["can_shoot"],
		})
	var granted: PackedStringArray = RoleArbiter.grant(requests, true, MAX_FLANKERS)
	var by_name: Dictionary = {}
	for index: int in range(fighters.size()):
		by_name[fighters[index]["name"]] = granted[index]
	return by_name
```

### O que você implementa {#implement}

Quem pede o quê: os pedidos são seus -- se um caminho em volta está aberto
e quão bom ele é, se um lutador tem linha de tiro e munição --, e os papéis
que voltam são seus para executar. As outras classes recebem o mesmo tipo
de entrada -- `Candidate`, `Objective`, `SquadReport` são classes internas
que você preenche com números -- e vale lê-las na ordem em que a partida de
*bots* as usa.

## Para ir mais fundo {#deeper}

- Como se faz a IA de jogos de tiro: um *bot*, um time, uma busca (em
  inglês): [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- A partida de *bots*, cada ajuste e cada tecla (em inglês):
  [godot/botmatch.md](../godot/botmatch.md).
- O que um *bot* faz agora, por *utility*: [ai_utility.pt-BR.md](ai_utility.pt-BR.md).
