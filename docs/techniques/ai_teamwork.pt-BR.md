# ai_teamwork — um time que divide o trabalho

<!-- doc-meta
half_life: practice
verified_on: 2026-11-11
tier: 2
source: https://www.gameaipro.com/
invalidated_if: the kit's RoleArbiter, TeamCommander, TacticalPositions, SquadConfidence, SearchCoordinator, AttackTokens or EngagementRings signatures change, or the demos that use them are renamed
teaches: shooter-ai
translation_of: 9a4e71937b41f603adc5106df514e5a029241a9a9a1bb85e63cef36a756a0531
-->

> English: [ai_teamwork.md](ai_teamwork.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Como um time divide o trabalho, cada parte uma ponderação própria:
`TeamCommander` manda esquadrões para objetivos, `TacticalPositions`
escolhe onde um *bot* fica e impede dois de reivindicarem o mesmo lugar,
`RoleArbiter` deixa um *bot* flanquear enquanto os outros atiram,
`SearchCoordinator` divide os lugares a procurar, `SquadConfidence` diz
quando atacar, segurar ou recuar, e `PassageChoice` pesa como passar por
um corpo no caminho -- esperar, dar a volta,
pedir a um companheiro que saia da frente, ou ir para outro lugar. E o
`AttackTokens` deixa um ou dois de um grupo golpearem um alvo de cada vez,
enquanto os outros esperam a vez (T154), e o
`EngagementRings` diz onde os outros ficam enquanto isso (T155). Cada um guarda os seus
números, para uma tela mostrar o porquê. O que um *bot* faz agora, as
saídas do posto e onde ele mira não estão aqui: desde a T101 e a T64 são do
[`ai_utility`](ai_utility.pt-BR.md), porque nada neles é sobre um time. As
fontes: os capítulos do *Game AI Pro* que cada classe cita.

## Quando não usar {#when-not}

Um esquadrão só, ou um único lugar onde ficar: o mais próximo primeiro dá a
mesma resposta com menos a explicar. Papéis que são lugares, não tarefas --
quem segura qual porta: isso é o `TacticalPositions` com reivindicações,
não o `RoleArbiter`. E um time cujos membros precisam agir numa ordem fixa,
uma invasão e depois uma varredura: isso é de um plano (`ai_planning`), não
de uma ponderação que cada *bot* refaz a cada decisão.
Os *attack tokens* são para um grupo contra um alvo: uma luta com um
inimigo só não precisa de vez, e num jogo de furtividade os inimigos não
deveriam estar atacando.

## Onde ver funcionando {#watch}

- `make demo-botmatch` -- seis contra seis. **Tab** observa o próximo *bot*:
  os discos em volta dele são cada lugar que ele pesou, com a sua nota.
  **1-3** ligam e desligam as reivindicações, o comandante e o recuo do
  azul (**shift** para os do vermelho), para você ver o time com cada parte
  desligada. **T** assume o *bot* observado.
- `make demo-infiltration` -- os guardas procuram com o `SearchCoordinator`
  e lutam sob o `RoleArbiter`; **2** e **3** ligam e desligam o coordenador
  e o árbitro, **Tab** observa o próximo guarda.
- O `AttackTokens` e o `EngagementRings` ainda não têm demo: a luta
  contra o chefe da T157 é a que vai mostrar quem segura um *token* e os
  anéis. Até lá, os vetores e a suíte dele
  o rodam.
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
| *attack tokens* | `AttackTokens.Config` | quantos podem golpear de uma vez por tipo, quanto tempo entre concessões, quanto mais quando o jogador está ocupado |
| anéis | `EngagementRings.Config` | o raio e o número de pontos de cada anel, e o espaçamento mínimo entre duas reivindicações |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_teamwork-<version>.zip` na
raiz do seu projeto, `res://` -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

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

## *Attack tokens*: um ataca de cada vez {#attack-tokens}

Um grupo cerca o jogador, e só um ou dois golpeiam de uma vez; os outros
rodeiam e esperam. Kingdoms of Amalur deu ao jogador uma *attack capacity*
e a cada ataque um peso, e uma criatura só podia escolher um ataque cujo
peso ainda coubesse [Dawe 2013]; DOOM (2016) mantém uma contagem de
*tokens* por tipo de ataque, definida pela dificuldade [Thompson 2018]. O
`AttackTokens` é esse estoque, um por alvo:

- **Um estoque por tipo**, `melee: 2` e `ranged: 1`, e um custo por pedido,
  então um ataque pesado leva os dois *tokens* de *melee*. Um custo acima do
  estoque inteiro do seu tipo é recusado quando é pedido -- `REFUSED_COST`
  --, não fica na fila para sempre; também é recusado quem segura um
  *token* e pede de outro tipo, `REFUSED_HOLDING`. Pedir de novo o mesmo
  tipo e custo mantém o lugar na fila; outro tipo ou custo é um pedido
  novo, que espera a partir de agora.
- **Quem é atendido em seguida é uma regra escrita**, não a ordem em que os
  pedidos foram guardados: primeiro quem foi preterido `patience` vezes, o
  mais antigo antes; depois a maior prioridade (o chefe acima dos
  capangas); depois quem espera há mais tempo; depois o mais perto; depois
  um *hash* com *seed*. O primeiro dessa ordem é atendido ou ninguém é: um
  ataque pesado que ainda não cabe não é ultrapassado pelos leves. Assim
  todo pedido é atendido em no máximo `patience` concessões mais o número
  dos que ainda esperam e pediram no mesmo instante ou antes dele -- a
  suíte segura esse limite para cada tipo, e um estoque plantado sem
  paciência o quebra.
- **Um *token* volta de cinco jeitos**: o ataque termina, quem o segura é
  interrompido ou morre, o jogo revoga um tipo inteiro de uma vez
  (`revoke_kind`, quando a pressão de *melee* começa e os de longe devem
  parar), ou o tempo dele acaba -- a rede para quem esqueceu de devolver.
  Todo tipo precisa de um tempo máximo: um estoque configurado sem ele é
  recusado pelo nome. Quem espera e é interrompido ou morre sai da fila, e
  quem mudou de ideia chama `withdraw`.
- **Um *timer* espaça as concessões** de cada tipo: uma espera base, vezes
  um fator pelo estado do jogador -- mais longa quando ele está ocupado,
  mais curta quando está parado. O estado é lido na concessão e define a
  espera até a próxima. Os dois são dados, e o
  `delay_for(kind, state)` está lá para ser desenhado.

```gdscript
var pool := AttackTokens.new(config)  # config.pools = {"melee": 2, "ranged": 1}
pool.request("troll", "melee", 2, 5, 3.0, now)  # cost 2, priority 5, 3 m away
for id: String in pool.step(now, "busy"):
	print(id, " may strike")
pool.release("troll", AttackTokens.ENDED, now)
```

O `events` registra cada concessão e cada devolução com o motivo, para uma
tela desenhar. Onde isso fica ao lado dos anéis e dos *telegraphs*, e
quando não usar nenhum deles (em inglês):
[concepts/action-combat-ai.md](../concepts/action-combat-ai.md).

## Anéis de combate: onde os outros esperam {#engagement-rings}

Um *token* diz **quem** ataca; não diz onde os outros ficam. Sem isso, os
que esperam se amontoam, ficam atrás do jogador, onde ele não os vê, ou
tapam a linha de quem ataca de longe. Reckoning dividiu o círculo em volta
do jogador num círculo de ataque e num de aproximação, para o jogador
saber quem é uma ameaça imediata [Dawe 2013, 28.3.1]. O `EngagementRings`
mantém três:

- **`INNER`** para quem segura um *token* de *melee*, **`WAITING`** para os
  outros de *melee*, e **`RANGED`**, uma faixa mais longe, para os de longe,
  segurando *token* ou não. O `ring_for(holds_token, ranged)` diz qual;
  então segurar um *token* leva o inimigo para dentro, e devolvê-lo o manda
  para fora de novo. Os anéis nunca concedem um ataque: quem concede é o
  `AttackTokens`.
- **Os anéis só põem pontos**, um número por anel, no raio dele. Qual ponto
  um inimigo toma é a consulta do `TacticalPositions`, não uma segunda: um
  ponto de outro anel fica `OUTSIDE_AREA`; um ponto a menos de `spacing` da
  reivindicação de outro inimigo -- em qualquer anel -- aparece como
  `CLAIMED` por ele; um ponto sem linha de visão fica `EXPOSED`; a
  proximidade ordena o resto. Andar longe nunca descarta um ponto do anel:
  cada consulta sobe o `max_travel` até o ponto mais distante, então um
  inimigo longe ainda chega à frente.
- **Quem segura um *token* tem a preferência.** Uma reivindicação de outro
  anel nunca impede quem segura um *token* de entrar no anel de dentro: ele
  toma o ponto, e cada reivindicação que agora fica perto demais é largada
  e listada em `last_bumped`, para aquele inimigo escolher de novo.
- **Primeiro na frente da câmera.** Um ponto atrás da vista do jogador fica
  fora da área enquanto houver um livre na frente, e só é tomado quando não
  houver nenhum. Um ponto exatamente na altura da câmera conta como atrás.
- **Não lança raios.** A `line_of_sight` de cada ponto é sua para
  preencher, lançada com a sua física, como os fatos do
  `TacticalPositions`; assim o *addon* e o gêmeo em Python não precisam de
  física.
- **Os anéis andam com o alvo**: `place(at)` move todos os pontos e mantém
  cada reivindicação, e o `choose` larga a reivindicação antiga do inimigo
  antes de perguntar; perguntar de novo a cada decisão acompanha o alvo, o
  *token* e a vista. Rodear é *steering*, e é seu: chegar ao ponto
  reivindicado, com separação.

```gdscript
var field := EngagementRings.new(config, player_xz)
for point: EngagementRings.Point in field.points:
	point.line_of_sight = _can_see(point.position, player_xz)  # your raycast
var enemy_id: int = minion.get_instance_id()  # the rings' id: an int
var holds: bool = str(enemy_id) in tokens.holders("melee")  # the tokens' id: a String
var ring: String = EngagementRings.ring_for(holds, is_ranged)
var index: int = field.choose(enemy_id, ring, enemy_xz, camera_xz, camera_forward_xz)
```

Dois ids para um inimigo: o `AttackTokens` chama quem pede por uma
`String`, e o `EngagementRings`, como o `TacticalPositions`, por um `int`.
Um `int` por inimigo, com o `str()` dele dado aos *tokens*, mantém os dois
o mesmo inimigo.

Para uma tela: o `last_choice` guarda o estado e a nota de cada ponto da
última consulta, e o `last_behind` diz, por ponto, se ele estava atrás da
câmera -- a parte da regra da câmera no `OUTSIDE_AREA`, que um ponto de
outro anel também é.

## Para ir mais fundo {#deeper}

- Como os inimigos de jogos de ação revezam -- *tokens*, anéis,
  *telegraphs* (em inglês):
  [concepts/action-combat-ai.md](../concepts/action-combat-ai.md).
- Como se faz a IA de jogos de tiro: um *bot*, um time, uma busca (em
  inglês): [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- A partida de *bots*, cada ajuste e cada tecla (em inglês):
  [godot/botmatch.md](../godot/botmatch.md).
- O que um *bot* faz agora, por *utility*: [ai_utility.pt-BR.md](ai_utility.pt-BR.md).
