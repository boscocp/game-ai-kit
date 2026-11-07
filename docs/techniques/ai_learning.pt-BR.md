# ai_learning — usando o que o Python aprendeu

<!-- doc-meta
half_life: practice
verified_on: 2026-11-06
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 19, linear and logistic regression ; https://docs.godotengine.org/en/stable/classes/class_json.html
invalidated_if: the kit's LearnedModel, LearnedTree, ModelFile, SoftmaxModel, CaseTable or ClonedPlayer signatures change, or the demos that use them are renamed
teaches: learning
translation_of: c599731acdec41526f67a35a2bc82f4b32e03979c6ac7693df369a0a5ff84e93
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
probabilidade para cada resposta. `LearnedTree` é uma árvore de decisão
(T113): uma pergunta por nível -- esta palavra é aquela, este número é no
máximo aquele -- até uma folha que conta as respostas que as linhas de
treino deram ali, então o caminho se lê como uma regra. `CaseTable` é um *ghost*: o que um
jogador gravado fez em cada situação que encontrou, consultado em vez de
ajustado. Nada aqui muda um peso (invariante 6). O livro: Russell e
Norvig, *AIMA*, capítulo 19.

## Quando não usar {#when-not}

Uma camada oculta, ou uma estrutura que não seja um peso por *feature* nem
uma árvore -- estas classes não guardam isso. Uma árvore sozinha, funda,
com poucas linhas: ela aprende as linhas e não o jogador, e com as poucas
gravações do jogo de luta uma árvore mais funda acerta menos nas lutas que
nunca viu ([concepts/learning.md](../concepts/learning.md#a-decision-tree),
em inglês); várias árvores votando é a resposta de costume (T114).
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
  [behaviour_cloning](behaviour_cloning.pt-BR.md)). "tree: easy", "tree:
  medium" e "tree: hard" leem você com uma `LearnedTree` ajustada às suas
  gravações: o painel mostra cada teste do caminho, a palavra que ele leu e
  para que lado foi, as contagens da folha, e o que o *n-gram* ao lado
  espera.
- `make run` (damas) declara este módulo pela sua metade Python: o
  treinador ajusta com `gameaikit.training`. O jogo não usa nenhuma das
  classes do *addon* -- os pesos aprendidos são lidos pelo seu próprio
  `CheckersWeights` (veja [learned_evaluation](learned_evaluation.pt-BR.md)).
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#ai_learning).

## Neste kit {#in-this-kit}

`godot/game/main.gd` (o *skirmish*) e `godot/game/tactical/learned_blue.gd`
carregam o `weights.json` por `TacticalWeights.load_from` -- o `ModelFile`,
e a verificação do próprio jogo tático das convenções que ele publica ao
lado dos modelos -- e o entregam ao
`LearnedPolicy` (`learned_policy.gd`), que tira dele os modelos `combat` e
`capture` e compara a probabilidade do modelo de combate com um limiar.
`godot/game/fighting/fight_clone_opponent.gd` joga com um `ClonedPlayer`, e
`godot/game/fighting/fight_tree_opponent.gd` lê você com a árvore do
`opponent_tree.json`, que o `python/gameaikit/cloning/opponent_tree.py`
ajusta (`make train-tree`; `make tree-report` a mostra em cada
profundidade). Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| os pesos | o arquivo JSON que o Python publica | tudo o que o modelo conclui; só muda ajustando de novo |
| o limiar | `LearnedPolicy.DEFAULT_THRESHOLD`, ou a sua própria comparação | o quanto o modelo precisa ter certeza antes de a unidade agir; mais corajoso abaixo de meio |
| as *features* | `LearnedModel.features` | lidas do arquivo, na ordem do arquivo; `predict_named` casa pelo nome |
| exata ou mais próxima | `CaseTable.exact` ou `CaseTable.nearest` | o que um *ghost* faz numa situação que o jogador nunca encontrou |
| a profundidade e o tamanho da folha de uma árvore | `MAX_DEPTH`, `MIN_LEAF` no `opponent_tree.py` | quantos testes tem um caminho, e quão poucas linhas uma folha pode contar; mais funda se ajusta melhor às linhas e pior às lutas novas |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_learning-<version>.zip` na
raiz do seu projeto, `res://` -- [usando a
biblioteca](using-the-library.pt-BR.md) tem cada passo, o *wheel* de Python
também. Ou copie de um clone:

Uma pasta: `godot/addons/ai_learning/`. Ela não precisa de mais nada, nem
do `ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes. O ajuste é do Python: `python/gameaikit/`
(`training/` para as regressões, `training/tree.py` para uma árvore e
`training/model_file.py` para escrever o arquivo, `cloning/` para um
jogador clonado) -- copie aquilo com que você
ajusta, e deixe isso fora do jogo.

### Um exemplo mínimo {#example}

Uma unidade sua que pergunta a um modelo ajustado no Python qual a chance
de um ataque dar certo. Ela carrega o `chance_model.json`, escrito à mão ao
lado dela: um modelo e nada mais, que é tudo de que um arquivo de modelo
precisa. O seu é o arquivo que o seu lado Python escreveu. Este arquivo é
executado por `chance_example_test.gd`, e o *gate* garante que a página é
igual a ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_learning/chance_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_learning.md, run by
# chance_example_test.gd. A unit of your own that asks a model Python
# fitted how likely an attack is to win, and only multiplies -- it never
# changes a weight.
extends Node

## Where your Python side wrote the model file. This one is the kit's,
## written by hand beside this example: one model, nothing else.
const MODEL_PATH: String = "res://test/ai_learning/chance_model.json"

var _model: LearnedModel


func _ready() -> void:
	_model = model_from(MODEL_PATH)


## The `chance` model in the file at `path`, or null when the file is
## refused -- whole, with the reason in one sentence, never filled in with a
## guess.
static func model_from(path: String) -> LearnedModel:
	var published: ModelFile = ModelFile.load_from(path)
	if not published.is_loaded():
		push_warning(published.error)
		return null
	return published.model("chance")


## How likely an attack is to win, 0 to 1, from the facts by name. With no
## model, or a fact the model needs and was not given, the answer is NAN,
## which no threshold passes.
func chance_to_win(facts: Dictionary) -> float:
	if _model == null:
		return NAN
	return _model.predict_named(facts)
```

### O que você implementa {#implement}

As *features*, medidas no seu jogo com os nomes que o arquivo usa, e o que
fazer com a resposta -- em geral uma comparação com um limiar. Os pesos se
aplicam aos números crus do jogo: o lado Python desfaz a sua normalização
antes de publicar, então aqui não há nada a normalizar. O arquivo é
`models`, cada um com `kind`, `features`, `weights` e `bias` -- ou, para
uma árvore, `kind` "tree", `features`, `classes` e `nodes`, lida com
`ModelFile.tree(name)`; qualquer outra coisa nele é sua, entregue sem leitura em `ModelFile.extra`. Se as suas
*features* precisam de números que não são pesos -- um raio, o que "sozinho"
vale --, publique-os ali e verifique-os você mesmo por cima do `ModelFile`,
como o `TacticalWeights` do jogo tático faz com as suas quatro
`feature_conventions`. `ClonedPlayer.load_from(path)` carrega qualquer
jogador clonado que o lado Python escreva.

## Para ir mais fundo {#deeper}

- As duas regressões e a árvore, ajustadas e lidas (em inglês):
  [concepts/learning.md](../concepts/learning.md).
- A forma do arquivo e o lado Godot (em inglês):
  [godot/learning.md](../godot/learning.md).
- Um jogador clonado a partir de gravações:
  [behaviour_cloning](behaviour_cloning.pt-BR.md).
