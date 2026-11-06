# ai_bandit — que opção tentar agora?

<!-- doc-meta
half_life: practice
verified_on: 2026-10-30
tier: 1
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- section 17.3, Bandit Problems ; https://homes.di.unimi.it/~cesabian/Pubblicazioni/ml-02.pdf
invalidated_if: the kit's Bandit signature changes, ADR 0016's amendment is withdrawn, or the demos that use it are renamed
teaches: fighting-game-ai
translation_of: 7b28efc6d1c1d0c2fd1675fe85a925cdb760912936d6a9624b25b739899c7974
-->

> English: [ai_bandit.md](ai_bandit.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Qual de um conjunto fixo de opções tentar agora, pelo que cada uma rendeu
até aqui. Cada opção é um braço (*arm*); puxe um e ele paga algo entre 0 e
1. O `Bandit` guarda dois números por braço -- quantas vezes foi puxado e a
soma do que pagou -- e escolhe a partir deles. A lição é o dilema entre
ficar com a opção que pagou melhor (*exploitation*) e tentar as que ainda
se conhece pouco (*exploration*). O *UCB1* [Auer, Cesa-Bianchi & Fischer
2002] responde com "a soma de dois termos": a média do que o braço pagou,
e um bônus que cresce a cada puxada que o deixa de fora e diminui a cada
puxada que ele recebe. O *epsilon-greedy*, aqui para comparação, fica com a
melhor média, exceto quando, com chance `epsilon`, puxa um braço qualquer
ao acaso. O livro: AIMA 4ª edição, 17.3, *Bandit Problems*.

## Quando não usar {#when-not}

Quando o valor de uma opção depende da situação -- isso é um *bandit*
contextual, ou uma tabela de *bandits*, um por situação, como o jogo de
luta guarda. Quando os pagamentos mudam com o tempo: o *UCB1* conta uma
puxada antiga tanto quanto uma nova, então acompanha a mudança devagar.
Quando há puxadas de menos para tentar cada opção ao menos uma vez: um peso
escrito à mão é melhor que um *bandit* que nunca passou da primeira rodada.
E guardar as contagens entre partidas: isso seria um modelo ajustado
durante o jogo, o que a invariante 6 proíbe; a ADR 0016, emendada, só
permite este porque ele conta, começa vazio a cada luta e nunca é salvo.

## Onde ver funcionando {#watch}

- `make demo-fighting` -- **M** até o boneco ser um "bandit" (fácil, médio
  ou difícil). O painel mostra, para a situação que o oponente acabou de
  nomear, as puxadas de cada uma das suas opções, a média do que pagou e o
  limite do *UCB1*, com uma barra -- `#` a média, `+` o termo de
  exploração -- e a opção escolhida marcada com `>` antes de ser jogada;
  depois, a última opção paga e quanto rendeu. Responda sempre do mesmo
  jeito a uma situação e veja as barras.
- `make measure-bandit` -- o oponente *bandit* contra os jogadores escritos em código do T18
  e o *ghost* do dono, ao lado do oponente fixo do T37, e quantas puxadas
  ele leva para se decidir.
- Que demo usa que técnica, nos dois sentidos: o
  [catálogo](catalogue.pt-BR.md).

## Neste kit {#in-this-kit}

`godot/game/fighting/fight_bandit_opponent.gd` mantém as situações, as
opções, a reação e a execução do T37, e troca o sorteio fixo por um
`Bandit` por situação, cujos braços são as opções daquela situação. Uma
opção recebe a mudança na vantagem de vida enquanto foi jogada e por meio
segundo depois, escalada para [0, 1]. Os botões que importam:

| botão | onde | o que muda |
|---|---|---|
| braços | `Bandit.new(arm_count, ...)` | quantas opções; um braço é um índice, e o seu jogo guarda os nomes |
| política | o segundo argumento, `Bandit.UCB1` ou `Bandit.EPSILON_GREEDY` | como troca explorar por aproveitar |
| exploração | o terceiro, 0 ou mais; `Bandit.EXPLORATION`, a raiz de dois, por padrão | o quanto ser pouco conhecido pesa contra ter pago bem; o oponente de luta usa 0,5, medido, porque seus pagamentos ficam perto de 0,5 |
| *epsilon* | o quarto, entre 0 e 1 | com que frequência o *epsilon-greedy* puxa ao acaso |
| semente | o quinto | os sorteios do *epsilon-greedy*, iguais em GDScript e Python |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_core-<version>.zip` e o
`ai_bandit-<version>.zip` no `res://addons/` do seu projeto -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

Duas pastas: `godot/addons/ai_core/` (pelo `Xorshift`, o gerador com
semente de que o epsilon-greedy sorteia) e `godot/addons/ai_bandit/`. Abra
o projeto uma vez, ou rode `godot --headless --import`, para o Godot
registrar as classes.

### Um exemplo mínimo {#example}

Um oponente seu com três aberturas que aprende, durante a partida, qual
vence este jogador. Contra um jogador que vence o *rush* e perde para a
expansão, ele tenta cada uma uma vez e depois joga mais a expansão. Este
arquivo é rodado por `opening_example_test.gd`, e o *gate* mantém a página
igual a ele.

<!-- example: godot/test/ai_bandit/opening_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_bandit.md, run by
# opening_example_test.gd. An opponent of your own that has three openings
# and learns, during this match only, which one wins against this player:
# it tries each, then keeps choosing by UCB1.
extends Node

const OPENINGS: Array[String] = ["rush", "turtle", "expand"]

# One arm an opening, UCB1 by default. It starts empty, and nothing here
# saves it: a new match makes a new one (ADR 0016).
var _bandit := Bandit.new(OPENINGS.size())
var _played: int = 0


func _ready() -> void:
	# No arms, an unknown policy or an epsilon outside [0, 1] is refused here.
	if _bandit.problem() != "":
		push_error(_bandit.problem())


## The opening to play this round.
func next_opening() -> String:
	_played = _bandit.choose()
	return OPENINGS[_played]


## The round is over: 1 for a win, 0 for a loss, anything between for a draw.
func round_ended(payoff: float) -> void:
	_bandit.reward(_played, payoff)


## Each opening's pulls, mean payoff and UCB1 bound. Draw them, and the
## player sees why the opponent chose what it chose.
func worth() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for arm: int in range(OPENINGS.size()):
		var opening: String = OPENINGS[arm]
		rows.append({"opening": opening, "pulls": _bandit.pulls[arm], "mean": _bandit.mean(arm), "bound": _bandit.bound(arm)})
	return rows
```

### O que você implementa {#implement}

O pagamento: um número entre 0 e 1 para o que uma puxada rendeu -- uma
rodada vencida, dano causado menos dano sofrido, escalado -- e o momento em
que ele é conhecido. `choose()` não muda contagem nenhuma; só `reward()`
muda, então chame-o uma vez por puxada, com o braço que você de fato
jogou. Quando o pagamento chega depois da próxima escolha -- um jogo de
luta só sabe o que uma resposta rendeu meio segundo depois de ela acertar
-- chame `pull(arm)` ao escolher e `pay(arm, payoff)` quando souber: um
braço esperando o pagamento deixa de ser "nunca tentado", e o *UCB1* não o
escolhe de novo por ser pouco conhecido. Guarde a média como o *bandit* guarda, uma soma sobre uma contagem
lida quando preciso: uma média atualizada no lugar com `+= (payoff - mean)
/ n` é o mesmo número com a forma de um passo de aprendizado, e o *gate*
deste kit a recusa. Chame `problem()` depois de construir: `""` quer dizer
que os parâmetros fazem sentido.

## Mais a fundo {#deeper}

- Como se faz IA de jogo de luta, e o que o oponente *bandit* mediu:
  [concepts/fighting-game-ai.md](../concepts/fighting-game-ai.md).
- Por que contar durante a luta é permitido, e nada além disso:
  [ADR 0016](../adr/0016-an-opponent-model-counts-during-the-fight.md), e
  sua emenda de 2026-10-26.
- Onde os *bandits* ficam entre as técnicas da área:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
