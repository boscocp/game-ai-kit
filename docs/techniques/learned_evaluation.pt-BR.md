# Avaliação aprendida — dar nota a uma posição com pesos ajustados aos resultados

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Arthur L. Samuel, "Some Studies in Machine Learning Using the Game of Checkers", IBM Journal of Research and Development 3(3), July 1959
invalidated_if: CheckersEvaluation, CheckersWeights, the weights file's shape or gameaikit.checkers's report change, or make run stops opening checkers
teaches: learned-evaluation
translation_of: e3cd2345ab888de5502d4a3e6b2249cbf297211a23e453467386c6ca1544dba7
-->

> English: [learned_evaluation.md](learned_evaluation.md). Os termos que
> ficam em inglês estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

O quanto uma posição parece boa, quando a busca precisa parar antes do fim
do jogo. A avaliação conta algumas coisas -- nas damas, peças, damas e
fileiras avançadas, cada uma a do jogador menos a do adversário -- e soma
cada contagem vezes o seu peso. Escritos à mão, os pesos são um palpite:
uma peça 1, uma dama 1,5. Aprendidos, eles são ajustados no Python a quem
ganhou as partidas de onde cada posição veio: regressão logística sobre
*self-play*, então cada peso diz o quanto a sua contagem mexe nas chances
de ganhar. A busca (`ai_adversarial`) não muda; só os números que ela
recebe. Inspirado no programa de damas de Samuel, de 1959, que ajustava os
seus coeficientes jogando -- aqui o ajuste acontece uma vez, fora do jogo,
e o jogo só multiplica.

## Quando não usar {#when-not}

Quando ninguém sabe dizer quais contagens importam: um ajuste só pesa as
*features* que recebe, e três boas contagens ajustadas ganham de trinta
chutadas. Contagens que andam juntas (peças e avanço aqui, r = 0,89, medido na
revisão da *wave* 33 -- veja
[concepts/learned-evaluation.md](../concepts/learned-evaluation.md), em inglês)
dividem o crédito de um jeito imprevisível, então um peso sozinho não é uma
lição sobre o jogo. E pesos que mudam durante a partida: isso é treinar
durante o jogo, o que a invariante 6 proíbe.

## Onde ver funcionando {#watch}

- `make run` -- damas contra o *minimax*. **E** alterna as brancas entre os
  pesos escritos à mão e os aprendidos; o painel mostra, para a posição no
  fim da linha que ele espera, o que cada contagem soma à nota sob os dois.
  **1-6** escolhem a profundidade, **espaço** faz a jogada dele.
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#learned_evaluation).

## Neste kit {#in-this-kit}

O ajuste é `python/gameaikit/checkers/`: `selfplay.py` joga as partidas,
`train.py` ajusta os três pesos com o treinador do kit
(`gameaikit.training`), e `report.py` os publica com os escritos à mão e a
partida entre os dois em `godot/game/checkers/checkers_weights.json`
(`make train-checkers`). No Godot, `checkers_weights.gd` lê o arquivo e
recusa um cujas *features* não sejam as da avaliação, na ordem;
`checkers_evaluation.gd` multiplica. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| as *features* | `CheckersEvaluation.FEATURES`, e o `FEATURES` do Python | o que a avaliação consegue ver; as duas listas precisam bater, e os vetores garantem isso |
| quais pesos | **E** no jogo, `CheckersGame.weights` no código | à mão ou aprendidos; a busca é a mesma |
| as partidas do ajuste | `python/gameaikit/checkers/selfplay.py` | que posições os pesos viram |
| a semente | `report.py` | o ajuste é determinístico: `make lint-no-training` ajusta de novo e compara (N7) |

## No seu projeto {#your-project}

### O que copiar {#copy}

A biblioteca tem a metade Godot, o `ai_adversarial-<version>.zip` e o
`ai_learning-<version>.zip`, e o *wheel* instala o `gameaikit.training`
([usando a biblioteca](using-the-library.pt-BR.md)). O caso das damas é do
exemplo e é copiado:

O lado Python ajusta: `python/gameaikit/checkers/` é o caso pronto -- o
`evaluation.py` e o `selfplay.py` dele são o que você reescreve para o seu
jogo --, com `python/gameaikit/training/` para a regressão, só a biblioteca
padrão. O lado Godot só multiplica: `godot/addons/ai_adversarial/` para a
busca e `godot/addons/ai_learning/` para o `LearnedModel`, que é a mesma
multiplicação sobre quaisquer *features* que você nomear.

### Um exemplo mínimo {#example}

A avaliação que um jogo seu entrega à busca, lendo pesos que o Python
publicou. Com o próprio arquivo de damas do kit, ela dá a cada posição
exatamente a nota que o jogo de damas dá. Este arquivo é executado por
`evaluation_example_test.gd`, e o *gate* garante que a página é igual a
ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/checkers/evaluation_example.gd -->
```gdscript
# The minimal example on docs/techniques/learned_evaluation.md, run by
# evaluation_example_test.gd. The evaluation a game of your own hands its
# search: counts your game takes of a position, each times a weight Python
# fitted to results. Here it only multiplies.
extends RefCounted

var _model: LearnedModel


## The weights in the file Python wrote at `path`: its `features`, and the
## `weights` under `learned`, one per feature, in that order. `is_ready()` is
## false when the file is not one.
func _init(path: String) -> void:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK or not reader.data is Dictionary:
		return
	var published: Dictionary = reader.data
	if not published.get("learned") is Dictionary:
		return
	var features := PackedStringArray(published.get("features", []))
	var weights := PackedFloat64Array(published["learned"].get("weights", []))
	if not features.is_empty() and features.size() == weights.size():
		_model = LearnedModel.new(LearnedModel.LINEAR, features, weights, 0.0)


## True when the weights were read.
func is_ready() -> bool:
	return _model != null


## How good a position is for one player: `counts` by feature name, each
## that player's minus the opponent's. Your `GakAdversarialGame.evaluate`
## returns this for a game that is not over.
func score(counts: Dictionary) -> float:
	return _model.predict_named(counts)
```

### O que você implementa {#implement}

No Python: as regras do seu jogo, um jeito de ele jogar contra si mesmo,
as contagens (a mesma função que o jogo vai calcular) e um rótulo por
posição -- quem ganhou. Ajuste, e publique as *features* junto com os pesos
para que a ordem nunca seja suposta. No Godot: as mesmas contagens, com os
mesmos nomes, vindas do seu `GakAdversarialGame.evaluate` para um jogo que não
terminou; um jogo terminado continua devolvendo o seu resultado
verdadeiro. O *bias* é publicado mas não é usado: uma busca só compara
posições para um jogador, e uma constante somada a toda folha não muda
escolha nenhuma.

## Para ir mais fundo {#deeper}

- O programa de Samuel, e o que este ajuste faz de diferente (em inglês):
  [concepts/learned-evaluation.md](../concepts/learned-evaluation.md).
- A busca que usa a nota: [ai_adversarial](ai_adversarial.pt-BR.md).
- A regressão em si (em inglês): [concepts/learning.md](../concepts/learning.md).
