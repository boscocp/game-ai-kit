# ai_teamwork — pesar ações, e um time que divide o trabalho

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf ; https://www.gameaipro.com/
invalidated_if: the kit's ActionChoice, RoleArbiter, TeamCommander, TacticalPositions or SearchCoordinator signatures change, or the demos that use them are renamed
teaches: shooter-ai
translation_of: 3fbf736cea44f0974c89b6962cbf8546566c6a6947c97d75252e69171893914a
-->

> English: [ai_teamwork.md](ai_teamwork.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Duas coisas. O que um *bot* faz agora: o `ActionChoice` dá nota a todas as
ações de uma vez -- o seu peso vezes a resposta de cada consideração, de 0 a
1, lida de uma percepção por uma curva de resposta -- e fica com a maior,
então uma resposta 0 veta a ação e as outras a graduam. Isso é *utility*,
na forma com que *Guild Wars 2* decidia. E como um time divide o trabalho,
cada parte uma ponderação própria: `TeamCommander` manda esquadrões para
objetivos, `TacticalPositions` escolhe onde um *bot* fica e impede dois de
reivindicarem o mesmo lugar, `RoleArbiter` deixa um *bot* flanquear
enquanto os outros atiram, `SearchCoordinator` divide os lugares a
procurar, `SquadConfidence` diz quando atacar, segurar ou recuar, e
`AimChoice`, `ErrandChoice` e `PassageChoice` pesam o resto. Cada um guarda
os seus números, para uma tela mostrar o porquê. As fontes: Lewis,
*Choosing Effective Utility-Based Considerations*, *Game AI Pro 3*,
capítulo 13, e os capítulos que cada classe cita.

## Quando não usar {#when-not}

Uma ordem que precisa ser mantida ao longo do tempo -- uma recarga
terminada antes de um tiro, os passos de um plano: isso é de um plano
(`ai_planning`, uma HTN), ou de um compromisso que as suas percepções
precisam carregar. Muitas ações ajustadas umas contra as outras: os números
interagem, então uma curva ajustada para uma mexe nas outras -- mantenha a
lista curta e as curvas simples. E as classes de time para um esquadrão só
ou um único lugar onde ficar: o mais próximo primeiro dá a mesma resposta
com menos a explicar.

## Onde ver funcionando {#watch}

- `make demo-botmatch` -- seis contra seis. **Tab** observa o próximo *bot*:
  os discos em volta dele são cada lugar que ele pesou, com a sua nota, e
  **V** mostra as notas da IA. **1-3** ligam e desligam as reivindicações,
  o comandante e o recuo do azul (**shift** para os do vermelho), para você
  ver o time com cada parte desligada. **T** assume o *bot* observado.
- `make demo-infiltration` -- os guardas escolhem pelo `ActionChoice` a
  partir de dados, procuram com o `SearchCoordinator` e lutam sob o
  `RoleArbiter`; **2** e **3** ligam e desligam o coordenador e o árbitro,
  **Tab** observa o próximo guarda.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/game3d/botmatch/match_bot.gd` lê as suas ações, posturas e ritmos de
`actions.json` com `ActionChoice.actions_from`, e chama
`ActionChoice.choose` a cada decisão; `team_tactics.gd` roda o comandante e
a confiança dos esquadrões de cada time. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| o peso de uma ação | `"weight"` nos dados | o quanto ela importa quando tudo a favorece |
| uma curva | `"curve": "linear"` (`slope`, `intercept`) ou `"step"` (`at`, `below`, `above`) | como uma percepção vira uma resposta de 0 a 1 |
| um veto | uma consideração que responde 0 | a ação está fora, seja o que for que a favoreça |
| flanqueadores | `RoleArbiter.grant(requests, use_arbiter, max_flankers)` | quantos podem contornar de uma vez; alguém sempre atira |
| reivindicações | `TacticalPositions.choose(...)` | se um lugar que outro *bot* pegou é descartado |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_teamwork/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. Toda classe lê números simples que o seu
jogo mediu -- distâncias, linha de tiro já testada --, então nenhuma
precisa da sua cena.

### Um exemplo mínimo {#example}

Um lutador seu que pesa atirar, recarregar, se proteger e patrulhar contra
o que percebe. Com um inimigo à vista, o pente cheio e vida 20, se proteger
(0,72) ganha de atirar (0,7); com a vida cheia, ele atira. Este arquivo é
executado por `fighter_example_test.gd`, e o *gate* garante que a página é
igual a ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_teamwork/fighter_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_teamwork.md, run by
# fighter_example_test.gd. A fighter of your own that weighs every action
# at once against what it perceives, and takes the highest -- utility.
extends Node

## The actions, as data a designer edits. A score is the weight times every
## consideration's answer, each 0 to 1, so one answer of 0 vetoes the
## action: no enemy in sight, no shot. A `step` curve answers `above` from
## `at` up and `below` under it (1 and 0 unless given); a `linear` one
## answers slope times the percept plus intercept, clamped to 0 and 1.
const ACTIONS: Array = [
	{"name": "shoot", "weight": 0.7, "considerations": [
		{"percept": "enemy_visible", "curve": "step", "at": 1.0},
		{"percept": "ammo", "curve": "step", "at": 1.0},
	]},
	{"name": "reload", "weight": 0.8, "considerations": [
		{"percept": "ammo", "curve": "linear", "slope": -0.1, "intercept": 1.0},
	]},
	{"name": "take cover", "weight": 0.9, "considerations": [
		{"percept": "enemy_visible", "curve": "step", "at": 1.0},
		{"percept": "health", "curve": "linear", "slope": -0.01, "intercept": 1.0},
	]},
	{"name": "patrol", "weight": 0.1, "considerations": []},
]

var _actions: Array[ActionChoice.Action] = ActionChoice.actions_from(ACTIONS)


## The action to take, given `percepts` by name -- `enemy_visible` 0 or 1,
## `ammo` rounds left, `health` 0 to 100 -- or "" when nothing scores.
func decide(percepts: Dictionary) -> String:
	var choice: ActionChoice.Choice = ActionChoice.choose(_actions, percepts)
	return "" if choice.chosen == -1 else _actions[choice.chosen].name


## Every action's score, by name: draw it, and the player sees why the
## fighter did what it did, and what came second.
func scores(percepts: Dictionary) -> Dictionary:
	var choice: ActionChoice.Choice = ActionChoice.choose(_actions, percepts)
	var by_name: Dictionary = {}
	for index: int in range(_actions.size()):
		by_name[_actions[index].name] = choice.scores[index]
	return by_name
```

### O que você implementa {#implement}

As percepções: cada uma um número que o seu jogo mediu nesta decisão, pelo
nome -- uma percepção não informada vale 0, nada percebido. E a ação: o
nome que volta é seu para executar, e uma ação que leva tempo (uma recarga)
é do seu jogo terminar antes de perguntar de novo. Deixe as ações num
arquivo JSON que um *designer* edita, e carregue-as com
`ActionChoice.actions_from(data)`: uma chave ou uma curva escrita errado é
recusada inteira, com um erro, em vez de pesada em silêncio com um valor
padrão. As classes de time recebem o mesmo tipo de entrada -- `Candidate`,
`Objective`, `SquadReport` são classes internas que você preenche com
números -- e vale lê-las na ordem em que a partida de *bots* as usa.

## Para ir mais fundo {#deeper}

- Como se faz a IA de jogos de tiro: um *bot*, um time, uma busca (em
  inglês): [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- A partida de *bots*, cada ajuste e cada tecla (em inglês):
  [godot/botmatch.md](../godot/botmatch.md).
- As outras quatro maneiras de decidir, e quando cada uma é a certa (em
  inglês): [concepts/ways-to-decide.md](../concepts/ways-to-decide.md).
