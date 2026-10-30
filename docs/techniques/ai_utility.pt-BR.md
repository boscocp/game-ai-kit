# ai_utility — pesar todas as opções de uma vez

<!-- doc-meta
half_life: practice
verified_on: 2026-10-30
tier: 2
source: https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf ; https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf
invalidated_if: the kit's ActionChoice, ErrandChoice or AimChoice signatures change, or the demos that use them are renamed
teaches: shooter-ai
translation_of: 62a5affaea190aad6d292451efd38b4c098ff55492d279931449974f44920bd3
-->

> English: [ai_utility.md](ai_utility.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

O que um agente faz agora, dando nota a cada opção e ficando com a maior.
O `ActionChoice` dá nota a todas as ações de uma vez -- o seu peso vezes a
resposta de cada consideração, de 0 a 1, lida de uma percepção por uma
curva de resposta --, então uma resposta 0 veta a ação e as outras a
graduam. Isso é *utility*, na forma com que *Guild Wars 2* decidia. O
`ErrandChoice` é a *utility* mais simples de todas: cada saída do posto um
ganho menos os seus custos, numa só unidade, e fica a maior quando passa de
zero -- voltar para buscar munição e vida, ir pegar uma arma poderosa, se
esconder para se curar. O `AimChoice` pesa onde mirar num corpo: a chance
de acertar cada zona, contando o tiro que pega a vizinha, vezes o que um
acerto ali vale, e mira-se na zona que vale mais. Cada um guarda os seus
números, para uma tela mostrar o porquê. Nada neles é sobre um time: até a
T101 -- o `AimChoice` até a T64 -- eles moravam no `ai_teamwork`, e um jogo que quisesse escolha por notas tinha que levar o
trabalho em equipe junto. As fontes: Graham, *An Introduction to Utility
Theory*, *Game AI Pro*, capítulo 9; Lewis, *Choosing Effective
Utility-Based Considerations*, *Game AI Pro 3*, capítulo 13.

## Quando não usar {#when-not}

Uma ordem que precisa ser mantida ao longo do tempo -- uma recarga
terminada antes de um tiro, os passos de um plano: isso é de um plano
(`ai_planning`, uma HTN), ou de um compromisso que as suas percepções
precisam carregar. Muitas ações ajustadas umas contra as outras: os números
interagem, então uma curva ajustada para uma mexe nas outras -- mantenha a
lista curta e as curvas simples. E uma escolha com duas opções e um motivo
só: um `if` diz o mesmo com menos a explicar.

## Onde ver funcionando {#watch}

- `make demo-botmatch` -- seis contra seis. **Tab** observa o próximo *bot*,
  e o painel lista cada ação, postura e ritmo que ele pesou, cada um com a
  sua nota, o escolhido marcado, e cada saída do posto como o seu ganho
  menos os seus custos. **T** assume o *bot* observado, e **V** mostra o
  painel enquanto você joga.
- `make demo-infiltration` -- os guardas escolhem pelo `ActionChoice` a
  partir de `guard_actions.json`; **Tab** observa o próximo guarda, e o
  painel lista cada ação que ele poderia fazer com a sua nota, a escolhida
  marcada.
- Qual demo usa qual técnica, nos dois sentidos: o
  [catálogo](catalogue.pt-BR.md).

## Neste kit {#in-this-kit}

`godot/game3d/botmatch/match_bot.gd` lê as suas ações, posturas e ritmos de
`actions.json` com `ActionChoice.actions_from`, e chama
`ActionChoice.choose` a cada decisão; `match_supply.gd` pesa as saídas de
cada *bot* com o `ErrandChoice` e deixa um time mandar um *bot* só atrás da
arma poderosa. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| o peso de uma ação | `"weight"` nos dados | o quanto ela importa quando tudo a favorece |
| uma curva | `"curve": "linear"` (`slope`, `intercept`) ou `"step"` (`at`, `below`, `above`) | como uma percepção vira uma resposta de 0 a 1 |
| um veto | uma consideração que responde 0 | a ação está fora, seja o que for que a favoreça |
| os preços de uma saída | `ErrandChoice.Weights` (`resupply_walk`, `leave_holding`, `power_danger`, ...) | quanto vale um segundo de caminhada, deixar o posto ou um inimigo perto, contra o ganho |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_utility/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. As duas classes leem números simples que
o seu jogo mediu, então nenhuma precisa da sua cena.

### Um exemplo mínimo {#example}

Um lutador seu que pesa atirar, recarregar, se proteger e patrulhar contra
o que percebe. Com um inimigo à vista, o pente cheio e vida 20, se proteger
(0,72) ganha de atirar (0,7); com a vida cheia, ele atira. Este arquivo é
executado por `fighter_example_test.gd`, e o *gate* garante que a página é
igual a ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_utility/fighter_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_utility.md, run by
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
padrão. O `ErrandChoice` recebe fatos do mesmo jeito -- `Resupply`,
`Fetch`, `Hide` são classes internas que você preenche com números -- e os
seus `Weights` são os preços do seu jogo.

## Para ir mais fundo {#deeper}

- Por que uma escolha por *utility* substituiu uma lista de prioridades
  na partida de *bots*, e de onde vem a sua forma (em inglês):
  [concepts/shooter-ai.md, o *bot* como agente](../concepts/shooter-ai.md#the-bot-as-an-agent-percepts-and-a-weighed-choice-t67).
- As quatro maneiras de decidir que este kit comparou antes da *utility* --
  uma máquina de estados, uma *behaviour tree*, GOAP e uma HTN -- e quando
  cada uma é a certa (em inglês):
  [concepts/ways-to-decide.md](../concepts/ways-to-decide.md).
- Um time que divide o trabalho, o *addon* de onde este saiu:
  [ai_teamwork.pt-BR.md](ai_teamwork.pt-BR.md).
