# ai_learning — usando o que o Python aprendeu

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 19, linear and logistic regression ; https://docs.godotengine.org/en/stable/classes/class_json.html
invalidated_if: the kit's LearnedModel, ModelFile, SoftmaxModel, CaseTable or ClonedPlayer signatures change, or the demos that use them are renamed
teaches: learning
translation_of: 97a529fd8b385fee46735d76f6253cc8a5354ab481c690eefac06516822d0905
-->

> English: [ai_learning.md](ai_learning.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Nada sozinho: é a metade de inferência do aprendizado de máquina. O Python
ajusta um modelo aos dados e publica os números dele num arquivo JSON; este
*addon* os lê de volta e multiplica. `LearnedModel` é um número por
*feature* e um *bias* -- `w·x + b` --, que responde a uma pergunta de sim ou
não com uma probabilidade (`LOGISTIC`) ou a uma de quanto com o próprio
número (`LINEAR`). `SoftmaxModel` responde "qual destes?" com uma
probabilidade para cada resposta. `CaseTable` é um *ghost*: o que um
jogador gravado fez em cada situação que encontrou, consultado em vez de
ajustado. Nada aqui muda um peso (invariante 6). O livro: Russell e
Norvig, *AIMA*, capítulo 19.

## Quando não usar {#when-not}

Um modelo que não seja um número por *feature*: uma árvore, uma camada
oculta, qualquer coisa com estrutura -- estas classes não guardam isso.
*Features* que só importam juntas ("um chute baixo quando perto, a não ser
que esteja encurralado"): estes modelos somam, então o produto precisa
entrar como uma *feature* própria. E qualquer aprendizado durante a
partida: ajustar é coisa do Python, numa mesa, com revisão -- a única
exceção é o *n-gram* do `ai_opponent` (ADR 0016).

## Onde ver funcionando {#watch}

- `make demo-skirmish` -- o azul é uma política aprendida: cada unidade
  pergunta a um modelo logístico qual a chance de um ataque dar certo, e o
  tabuleiro mostra a probabilidade ao lado do ataque que ela pesou.
- `make demo-tactical` -- **C** até o computador ser "learned": os mesmos
  modelos no tabuleiro tático.
- `make demo-fighting` -- **M** troca o boneco de treino; "ghost: exact",
  "ghost: nearest" e "clone" são um `CaseTable` e um `SoftmaxModel`
  ajustados a um jogador gravado (veja
  [behaviour_cloning](behaviour_cloning.pt-BR.md)).
- `make run` (damas) declara este *addon* no seu manifesto mas não usa
  nenhuma das classes dele: os pesos aprendidos são lidos pelo seu próprio
  `CheckersWeights` (veja [learned_evaluation](learned_evaluation.pt-BR.md)).
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

`godot/game/main.gd` (o *skirmish*) e `godot/game/tactical/learned_blue.gd`
carregam o `weights.json` por `ModelFile.load_from` e o entregam ao
`LearnedPolicy` (`learned_policy.gd`), que tira dele os modelos `combat` e
`capture` e compara a probabilidade do modelo de combate com um limiar.
`godot/game/fighting/fight_clone_opponent.gd` joga com um `ClonedPlayer`.
Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| os pesos | o arquivo JSON que o Python publica | tudo o que o modelo conclui; só muda ajustando de novo |
| o limiar | `LearnedPolicy.DEFAULT_THRESHOLD`, ou a sua própria comparação | o quanto o modelo precisa ter certeza antes de a unidade agir; mais corajoso abaixo de meio |
| as *features* | `LearnedModel.features` | lidas do arquivo, na ordem do arquivo; `predict_named` casa pelo nome |
| exata ou mais próxima | `CaseTable.exact` ou `CaseTable.nearest` | o que um *ghost* faz numa situação que o jogador nunca encontrou |

## No seu projeto {#your-project}

### O que copiar {#copy}

Uma pasta: `godot/addons/ai_learning/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. O ajuste é do Python: `python/gameaikit/`
(`training/` para as regressões, `cloning/` para um jogador clonado) --
copie aquilo com que você ajusta, e deixe isso fora do jogo.

### Um exemplo mínimo {#example}

Uma unidade sua que pergunta a um modelo ajustado no Python qual a chance
de um ataque dar certo. A entrada do modelo está escrita no arquivo para o
exemplo rodar sozinho; a sua vem do seu arquivo JSON. Este arquivo é
executado por `chance_example_test.gd`, e o *gate* garante que a página é
igual a ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_learning/chance_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_learning.md, run by
# chance_example_test.gd. A unit of your own that asks a model Python
# fitted how likely an attack is to win, and only multiplies -- it never
# changes a weight.
extends Node

## One model as Python publishes it. Your game reads this from the JSON file
## your Python side wrote; it is here so the example runs on its own.
const PUBLISHED: Dictionary = {
	"kind": "logistic",
	"features": ["my_health", "their_health", "distance"],
	"weights": [0.05, -0.05, -0.2],
	"bias": 0.5,
}

var _model: LearnedModel


func _ready() -> void:
	_model = model_from(PUBLISHED)


## A model from one published entry, or null when the entry is not one --
## refused whole, as the kit's `ModelFile` does, never filled in with a guess.
static func model_from(entry: Dictionary) -> LearnedModel:
	if not LearnedModel.KINDS.has(entry.get("kind")):
		return null
	if not (entry.get("bias") is float or entry.get("bias") is int):
		return null
	var features := PackedStringArray(entry.get("features", []))
	var weights := PackedFloat64Array(entry.get("weights", []))
	if features.is_empty() or features.size() != weights.size():
		return null
	return LearnedModel.new(entry["kind"], features, weights, float(entry["bias"]))


## How likely an attack is to win, 0 to 1, from the facts by name. A fact the
## model needs and was not given answers NAN, which no threshold passes.
func chance_to_win(facts: Dictionary) -> float:
	return _model.predict_named(facts)
```

### O que você implementa {#implement}

As *features*, medidas no seu jogo com os nomes que o arquivo usa, e o que
fazer com a resposta -- em geral uma comparação com um limiar. Os pesos se
aplicam aos números crus do jogo: o lado Python desfaz a sua normalização
antes de publicar, então aqui não há nada a normalizar. **Um achado:** o
`ModelFile`, o carregador do kit, recusa qualquer arquivo sem as quatro
`feature_conventions` do jogo tático (`nearby_radius` e mais três); fora
desse jogo, monte o `LearnedModel` a partir da sua própria entrada, como o
exemplo faz -- ou publique essas quatro. `ClonedPlayer.load_from(path)` não
tem esse vínculo: ele carrega qualquer jogador clonado que o lado Python
escreva.

## Para ir mais fundo {#deeper}

- As duas regressões, ajustadas e lidas (em inglês):
  [concepts/learning.md](../concepts/learning.md).
- A forma do arquivo e o lado Godot (em inglês):
  [godot/learning.md](../godot/learning.md).
- Um jogador clonado a partir de gravações:
  [behaviour_cloning](behaviour_cloning.pt-BR.md).
