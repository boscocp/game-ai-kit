# ai_opponent — o que o jogador vai fazer agora?

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Ian Millington and John Funge, "Artificial Intelligence for Games", 2nd edition, Morgan Kaufmann, 2009 -- chapter 7, Learning
invalidated_if: the kit's NGramPredictor signature changes, ADR 0016 is withdrawn, or the demos that use it are renamed
teaches: fighting-game-ai
translation_of: 697523ae9bf72fd7c2849ef1928a434c6eaa828aca3fa5cc92b03bf9baf898c9
-->

> English: [ai_opponent.md](ai_opponent.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

A chance de cada ação do jogador ser a próxima, a partir do que ele acabou
de fazer. O `NGramPredictor` conta, durante a partida, que ação veio depois
de cada sequência das últimas `order - 1` ações -- o *contexto* -- e lê as
contagens de volta como uma probabilidade para cada ação. Dois números o
refinam: `prior`, as aparições imaginárias com que toda ação começa, para
que um contexto nunca visto responda "não sei" em vez de um palpite tirado
do nada; e `decay`, o quanto uma aparição antiga conta diante de uma nova,
para acompanhar um jogador que muda de hábito. A tabela pode ser impressa
(`rows()`), e esse é o motivo de escolher um *n-gram* em vez de uma rede. O
livro: Millington e Funge, *Artificial Intelligence for Games*, capítulo 7.

## Quando não usar {#when-not}

Ações que dependem de mais do que as últimas -- da distância, da vida, do
relógio: o *n-gram* só vê a sequência, então todo o resto precisa entrar
nos próprios símbolos. Um adversário que não deve ficar melhor em vencer um
jogador específico -- um tutorial, uma dificuldade escolhida de propósito. E
guardar a tabela entre partidas: isso seria um modelo ajustado durante o
jogo, o que a invariante 6 proíbe; a ADR 0016 só permite este porque ele
começa vazio a cada luta e nunca é salvo.

## Onde ver funcionando {#watch}

- `make demo-fighting` -- **M** até o boneco de treino ser um "learner"
  (*easy*, *medium* ou *hard*). O painel imprime a tabela como ela está: o
  que ele espera que você faça agora, depois de qual contexto, quantos dos
  últimos palpites acertou e as linhas que já contou. Repita um hábito e
  veja a confiança subir.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/game/fighting/fight_model_opponent.gd` monta um `NGramPredictor`
sobre as ações do jogo de luta, observa o que você fez do jeito que foi
desenhado na tela, e puxa a sua escolha para a resposta àquilo que espera
-- ele só pode dar peso a opções que o seu nível já tem, então uma previsão
certeira nunca o deixa perfeito. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| ordem | `NGramPredictor.new(order, actions, decay, prior)` | quantas ações passadas ele olha, mais um; baixa demais não distingue um momento de outro, alta demais nunca vê um contexto duas vezes |
| *decay* | o terceiro argumento, acima de 0 e no máximo 1 | a rapidez com que hábitos antigos são esquecidos; 1 tira a média da partida inteira |
| *prior* | o quarto argumento, acima de 0 | quanta evidência ele precisa antes de ter certeza |
| ações | o segundo argumento | toda ação que ele pode ver ou prever; uma que não lhe foi dita é ignorada |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_opponent-<version>.zip` no
`res://addons/` do seu projeto -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

Uma pasta: `godot/addons/ai_opponent/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar a classe.

### Um exemplo mínimo {#example}

Um adversário seu de pedra, papel e tesoura que aprende o hábito do
jogador durante a partida e joga o que o vence. Um jogador que joga pedra,
pedra, papel sem parar recebe papel depois de "pedra, papel". Este arquivo
é executado por `counter_example_test.gd`, e o *gate* garante que a página
é igual a ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_opponent/counter_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_opponent.md, run by
# counter_example_test.gd. An opponent of your own at rock, paper, scissors
# that counts what the player did after what, during this match only, and
# plays what beats the likeliest next move.
extends Node

const MOVES: Array[String] = ["rock", "paper", "scissors"]

## What beats each move.
const BEATEN_BY: Dictionary = {"rock": "paper", "paper": "scissors", "scissors": "rock"}

# Order 3: it looks at the player's last two moves. Each old sighting of a
# context counts 0.9 of the one after it, so a player who changes habits is
# followed. The table starts empty and is never saved (ADR 0016).
var _predictor := NGramPredictor.new(3, MOVES, 0.9)


func _ready() -> void:
	# An order below 1 or a decay outside (0, 1] is refused here.
	if _predictor.problem() != "":
		push_error(_predictor.problem())


## The player just played `move`: count it.
func player_played(move: String) -> void:
	_predictor.observe(move)


## What to play now: the move that beats what the player will likeliest do.
func counter() -> String:
	return BEATEN_BY[_predictor.likeliest()]


## How likely each of the player's moves is next, summing to 1. Draw it, and
## the player sees what the opponent expects.
func expectation() -> Dictionary:
	return _predictor.probabilities()
```

### O que você implementa {#implement}

Os símbolos: transforme o que o jogador fez em um nome de uma lista curta
de ações -- a altura de um golpe, um pulo, uma defesa -- e chame `observe`
uma vez por ação nova, não uma vez por quadro. Alimente-o só com o que
estava na tela quando o seu adversário poderia ter visto, senão ele reage a
botões que nenhuma pessoa veria. E o uso: `probabilities()` é uma
inclinação, não um veredito -- pondere as escolhas do seu adversário por
ela em vez de jogar sempre a resposta, senão ele fica imbatível e sem
graça. Chame `problem()` depois de montar: `""` quer dizer que os ajustes
fazem sentido.

## Para ir mais fundo {#deeper}

- Como se faz a IA de jogos de luta, e onde o *n-gram* entra (em inglês):
  [concepts/fighting-game-ai.md](../concepts/fighting-game-ai.md).
- Por que contar durante a luta é permitido, e nada além disso (em inglês):
  [ADR 0016](../adr/0016-an-opponent-model-counts-during-the-fight.md).
