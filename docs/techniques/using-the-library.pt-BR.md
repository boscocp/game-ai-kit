# Usando a biblioteca — o kit num projeto seu

<!-- doc-meta
half_life: practice
verified_on: 2026-11-04
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html ; https://packaging.python.org/en/latest/tutorials/installing-packages/
invalidated_if: scripts/release.py changes what an archive holds, ADR 0024 changes the prefixed names, .godot-version or python/pyproject.toml's version moves, or scripts/library_check.py stops following one of this page's steps
teaches: none
translation_of: 3d10625c8624b412d3ccbf61eea82076c54a382128e59e1f8887ebf176b513f9
-->

> English: [using-the-library.md](using-the-library.md). Os termos que ficam
> em inglês estão no [glossário](glossary.pt-BR.md).

Esta é a página para seguir com um projeto Godot seu, fora deste
repositório. O `make library-check` dá cada passo dela numa pasta
descartável que não sabe nada do kit: roda cada bloco de comandos do jeito
que está impresso e os dois exemplos do jeito que estão aqui, e um passo
desta página que a verificação não dá faz a verificação falhar.

## O que é a biblioteca {#what}

Duas metades, cada uma usável sem a outra.

- **Addons de Godot**, um zip cada. O `ai_core` é o núcleo: uma grade
  (`GakGridGraph`) e uma porta de *pathfinding* (`GakPathfinder`), nenhum
  algoritmo. Cada outro addon é uma técnica -- `ai_search`,
  `ai_behaviour`, `ai_steering`, ... -- e não depende de nada além, no
  máximo, do `ai_core`, então você leva só o que usa. O
  [catálogo](catalogue.pt-BR.md) diz o que cada um decide.
- **Um *wheel* de Python**, `gameaikit`, os gêmeos das técnicas em Python
  puro, só a biblioteca padrão: onde o kit treina ou confere alguma coisa,
  e onde você treina para o seu jogo.

Os nomes que o seu código escreve como tipo levam o prefixo `Gak`: as
portas que você estende ou implementa e a grade do núcleo (ADR 0024). Os
algoritmos mantêm os nomes do livro -- `AStarSearch`, `StripsPlanner`.

| nome | addon | o que você faz com ele |
|---|---|---|
| `GakGridGraph` | `ai_core` | preenche a partir dos seus *tiles* |
| `GakPathfinder` | `ai_core` | pede um caminho a ele |
| `GakSearchGraph` | `ai_search` | estende para um mapa que não é grade |
| `GakSearch` | `ai_search` | estende com uma busca sua |
| `GakAdversarialGame` | `ai_adversarial` | estende com os lances do seu jogo |
| `GakGameDomain` | `ai_planning` | copia para escrever o seu domínio de planejamento |
| `GakLlmRuntime` | `ai_llm` | estende para chegar ao seu modelo de linguagem |
| `GakSteeringBehaviour` | `ai_steering` | estende com um comportamento seu |
| `GakRtsController` | `ai_rts_core` | estende com o comandante do seu lado |

**Fora dela**, de propósito: os exemplos -- os jogos em `godot/game/`, as
demos, o núcleo `board` que eles dividem (ADR 0021) e os pacotes Python
que são dos exemplos (`checkers`, `menace`, `cloning`, `racing`, ...); a
arte, que também não está neste repositório; e os testes, que ficam aqui.
Uma página de técnica que depende de um desses diz isso.

## Num projeto Godot {#godot}

Todo comando abaixo roda de uma pasta que guarda duas outras: um clone
deste repositório, `game-ai-kit/`, e o seu projeto Godot, `my_game/`. Cada
bloco é rodado do jeito que está impresso, dessa pasta, pelo
`make library-check`, com `godot` no lugar do Godot do `.godot-version`.
No Windows, descompacte pelo gerenciador de arquivos e leia
`.venv/bin/python` como `.venv\Scripts\python`.

### Os arquivos {#archives}

<!-- library-step: release -->
Nada foi publicado ainda, então os arquivos são gerados a partir do
clone. Isso só precisa de Python e git -- nada de Godot:

```bash
python3 game-ai-kit/scripts/release.py --build --output library
```

O `library/dist/` passa a ter um `<addon>-<version>.zip` por addon e o
`gameaikit-<version>-py3-none-any.whl`. No dia em que o kit for publicado,
são esses mesmos arquivos que você baixa. (O `make release` dentro do
clone é a *release* completa: ele também exporta o jogo do menu como
executável, então precisa antes do `make bootstrap` -- o Godot fixado e os
*templates* de exportação dele -- e de uma árvore limpa. Para a biblioteca
você não precisa dele.)

### Descompactar um addon {#unzip}

<!-- library-step: unzip -->
No `res://addons/` do seu projeto: o addon que você quer e, se o README
dele pedir, o `ai_core` ao lado. Para um caminho, os dois:

```bash
unzip -q library/dist/ai_core-0.1.0.zip -d my_game/addons/
unzip -q library/dist/ai_search-0.1.0.zip -d my_game/addons/
```

Não há plugin para ativar. Copiar `godot/addons/ai_core/` e
`godot/addons/ai_search/` do clone dá os mesmos arquivos, sem o `VERSION`
e o README; é a alternativa, não outra biblioteca.

### Deixar o Godot registrar as classes {#import}

<!-- library-step: import -->
Cada classe de um addon se anuncia com uma linha `class_name`, e o Godot
guarda a lista desses nomes num *cache* dentro da pasta `.godot/` do seu
projeto. O editor refaz essa lista quando percebe arquivos novos. Uma
execução pela linha de comando não refaz, e um script que usa uma classe
que o *cache* ainda não viu falha com `Could not find type "GakGridGraph"
in the current scope` -- que parece erro de digitação e não é. Uma vez,
depois de descompactar:

```bash
godot --headless --path my_game --import
```

### Uma primeira decisão na sua cena {#first-decision}

<!-- library-step: route -->
O exemplo mínimo da página do `ai_search`, sem mudança. Salve como
`my_game/route_example.gd`, anexe a qualquer nó de uma cena e rode a cena;
`route` guarda as células a percorrer. A verificação o coloca na árvore
de um projeto que não tem nada além dos addons descompactados, e essa é a
prova de que os zips bastam.

<!-- example: godot/test/ai_search/route_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_search.md, run by
# route_example_test.gd. A node of your own that finds a route across a
# board of its own as it enters the scene tree.
extends Node

## The route it found: the start left out, the goal included.
var route: Array[Vector2i] = []


func _ready() -> void:
	# Six by four, open ground, and a wall down column 3 with a gap at the
	# bottom -- the route has to find the gap.
	var board := GakGridGraph.new(6, 4)
	for row: int in range(0, 3):
		board.block(Vector2i(3, row))
	# Held as ai_core's GakPathfinder, so the caller does not care which search
	# answers: swap AStarSearch for DijkstraSearch and nothing else changes.
	var pathfinder: GakPathfinder = GridPathfinder.new(AStarSearch.new())
	route = pathfinder.find_path(board, Vector2i(0, 0), Vector2i(5, 0))
```

Cada outra página de técnica tem o seu exemplo mínimo no mesmo lugar, em
**No seu projeto**.

## O lado Python {#python}

### Instalar o *wheel* {#wheel}

<!-- library-step: wheel -->
Python 3.12 ou mais novo, mais nada. O *wheel* não tem dependências, e é
por isso que o `--no-index` basta: se um dia ganhar uma, este comando
falha em vez de baixá-la, e a verificação também. Num ambiente virtual só
dele:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --quiet --no-index library/dist/gameaikit-0.1.0-py3-none-any.whl
```

`from gameaikit import techniques` passa a listar o que está instalado,
`techniques.available()`. Do clone, `pip install ./game-ai-kit/python`
instala o mesmo pacote.

### Treinar em Python, decidir no Godot {#train}

<!-- library-step: train -->
O kit aprende em Python e só faz inferência em GDScript (a invariante 6
dele): nenhum peso muda enquanto o seu jogo roda. Um script de treino seu
ajusta um modelo e o grava num arquivo; o jogo lê o arquivo. Este ajusta
"esse ataque vence?" a partir de oito lutas. Salve como
`my_game/my_training.py`:

```python
# Fit "does this attack win?" from a few fights, and write the model file
# the game reads. Python learns here; the game will only multiply.
import json

from gameaikit.training import descent, model_file

fights = [  # (my_health, their_health), and 1 when I won
    ([90, 20], 1), ([80, 40], 1), ([70, 30], 1), ([60, 50], 1),
    ([30, 80], 0), ([40, 90], 0), ([20, 60], 0), ([50, 70], 0),
]
rows = [row for row, _ in fights]
labels = [won for _, won in fights]
# Fit on standardised numbers, then fold the scaling back in, so the
# weights apply to raw health and the game needs no scaler.
means, deviations = descent.standardise(rows)
scaled = descent.apply_standardisation(rows, means, deviations)
weights, bias = descent.fit(scaled, labels, descent.logistic_prediction)
weights, bias = descent.unstandardise(weights, bias, means, deviations)

published = {"generated_by": "my_training.py", "models": {"chance": {
    "kind": "logistic", "features": ["my_health", "their_health"],
    "weights": weights, "bias": bias}}}
refused = model_file.why_wrong(published)  # the same rules the game applies
assert not refused, refused
with open("chance_model.json", "w", encoding="utf-8") as file:
    json.dump(published, file, indent=2)
```

e rode com o Python do ambiente, de dentro do projeto, para o arquivo cair
em `res://chance_model.json`:

```bash
cd my_game && ../.venv/bin/python my_training.py
```

<!-- library-step: infer -->
No Godot, o `ai_learning` ao lado dos outros (ele não precisa do
`ai_core`), e a importação de novo:

```bash
unzip -q library/dist/ai_learning-0.1.0.zip -d my_game/addons/
godot --headless --path my_game --import
```

Depois um nó seu, `my_game/chance_from_python.gd`, lê o arquivo e
multiplica:

<!-- example: scripts/library/chance_from_python.gd -->
```gdscript
# The second example on docs/techniques/using-the-library.md, run by
# scripts/library_check.py in a project that has never seen this kit.
# A node of your own that reads the model your Python side wrote, and
# only multiplies: nothing in the game changes a weight.
extends Node

## Where the training script wrote its file, run from the project's folder.
const MODEL_PATH: String = "res://chance_model.json"

## How likely a healthy attacker is to beat a hurt one, 0 to 1; NAN when
## the file was refused, which no threshold passes.
var chance: float = NAN


func _ready() -> void:
	var published: ModelFile = ModelFile.load_from(MODEL_PATH)
	if not published.is_loaded():
		push_warning(published.error)
		return
	var model: LearnedModel = published.model("chance")
	chance = model.predict_named({"my_health": 85.0, "their_health": 30.0})
```

Treinar de novo é rodar o script outra vez e entregar o arquivo novo. A
página do [ai_learning](ai_learning.pt-BR.md) tem o formato do arquivo e o
que faz ele ser recusado.

## Versões e a licença {#versions}

<!-- library-step: licence -->
- **Godot**: o kit é testado na versão do `.godot-version`, hoje a 4.7.2,
  e é essa que o `make library-check` roda. Um Godot 4 mais antigo não é
  testado.
- **A versão da biblioteca** está no `VERSION` de cada zip e no nome do
  *wheel* -- 0.1.0 hoje, o número dos comandos acima. O que ela promete
  manter é o que o ADR 0024 escreve: os nove nomes `Gak` acima, os que o
  seu código escreve como tipo -- renomear um depois de uma *release*
  quebra todo jogo que o usa, e por isso eles são poucos. Antes da 1.0,
  qualquer outro nome ainda pode mudar entre *releases*.
- **Um nome que colide com um seu**: o README de cada zip diz o que fazer
  -- renomeie a linha `class_name`, e os usos dela, dentro da pasta daquele
  addon. Nada seu muda.
- **Licença**: Apache-2.0. Cada zip leva `LICENSE` e `NOTICE` ao lado do
  código, e o *wheel* leva os dois nos metadados; a verificação abre cada
  arquivo e confere. O que você redistribuir que os contenha os mantém --
  uma tela de licenças de terceiros basta. Um crédito no seu jogo é um
  pedido, não uma obrigação (o [README](../../README.md), em inglês,
  explica por quê).

## Mais fundo {#deeper}

- Por que os nomes levam `Gak`, e por que só as técnicas vão na
  biblioteca: [ADR 0024](../adr/0024-the-library-prefixes-its-ports.md).
- O que o `ai_core` guarda e por que é tão pequeno:
  [ai_core](ai_core.pt-BR.md).
- Como os arquivos de um addon, o `class_name` e o `.uid` se encaixam no
  Godot: [godot/addon-anatomy.md](../godot/addon-anatomy.md) (em inglês).
