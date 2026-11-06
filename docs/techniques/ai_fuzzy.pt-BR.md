# ai_fuzzy — quanto, aos poucos

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 5, fuzzy logic ; book:IEC 61131-7, "Programmable controllers -- Part 7: Fuzzy control programming", 2000
invalidated_if: the kit's FuzzySet, FuzzyVariable, FuzzyRule or FuzzyRuleBase signatures change, or the demos that use them are renamed
teaches: stealth-ai
translation_of: f07e36205616588541d40c0b0a87a8936fc9e009ffe8045122358f53ad568313
-->

> English: [ai_fuzzy.md](ai_fuzzy.md). Os termos que ficam em inglês estão
> no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Uma quantidade, a partir de números que o seu jogo mediu, por regras que um
*designer* consegue ler em voz alta: *se a distância é perto e a luz é
clara, então o alarme é alarmado*. Cada entrada pertence aos seus conjuntos
num grau de 0 a 1 (`FuzzySet`, um trapézio ou um triângulo); cada regra é
tão verdadeira quanto a sua condição mais fraca (E) ou a mais forte (OU); e
o centroide (`FuzzyCentroid`) transforma os termos de saída, cada um
cortado na força da sua regra, de volta num número só. Duas regras
disparando juntas caem entre os seus termos, então a resposta anda suave
onde um limiar daria um salto. `activations` diz com que força cada termo
foi concluído -- o *porquê*. O livro: Millington, *AI for Games*, capítulo
5; a linguagem das regras é a FCL da IEC 61131-7.

## Quando não usar {#when-not}

Uma escolha entre ações: o centroide de "fugir" e "lutar" é uma unidade
parada -- deixe o *fuzzy* responder *quanto*, e outra coisa responder
*qual*. Uma entrada discreta ("tem a chave"), em que um conjunto é um
booleano disfarçado. E passando de uma dúzia de regras: aí toda mudança
mexe um pouco em todas as saídas, e ninguém consegue prever o sistema; uma
árvore de decisão diz o mesmo com mais clareza.

## Onde ver funcionando {#watch}

- `make demo-stealth` -- a barra sobre cada guarda é a sua suspeita, que
  sobe em direção ao que um controlador *fuzzy* responde a partir de
  distância, luz, barulho e silêncio. Pise na luz perto de um guarda, ou
  passe por um correndo com **shift**, e veja a barra encher aos poucos.
- `make demo-infiltration` -- a velocidade com que a atenção de um guarda
  sobe é um controlador *fuzzy* lido de dados. **Tab** acompanha um guarda.
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#ai_fuzzy).

## Neste kit {#in-this-kit}

`godot/game/stealth/suspicion.gd` escreve o controlador do guarda do
*stealth* por extenso em `build_controller()`, para as regras serem lidas
em voz alta ao lado do código; `godot/game3d/infiltration/fuzzy_from_data.gd`
monta um a partir de uma linha de JSON. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| a forma de um conjunto | `FuzzySet.new(name, [rise_start, rise_end, fall_start, fall_end])` | onde um valor começa e deixa de pertencer; três pontos fazem um triângulo |
| a faixa de uma variável | `FuzzyVariable.new(name, minimum, maximum, sets)` | as entradas são limitadas a ela antes de serem lidas |
| as amostras da saída | `FuzzyVariable.new(..., samples)` numa saída | o quanto o centroide mede com precisão; no mínimo duas |
| as regras | `FuzzyRule.new(conditions, conclusion, connective)` | que termo cada combinação conclui; `FuzzyRule.AND` ou `FuzzyRule.OR` |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_fuzzy-<version>.zip` na raiz
do seu projeto, `res://` -- [usando a biblioteca](using-the-library.pt-BR.md) tem cada
passo, o *wheel* de Python também. Ou copie de um clone:

Uma pasta: `godot/addons/ai_fuzzy/`. Ela não precisa de mais nada, nem do
`ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`, para
o Godot registrar as classes. O leitor de FCL, para regras escritas num
arquivo, fica do lado Python, em `python/gameaikit/fuzzy/`.

### Um exemplo mínimo {#example}

Um guarda seu que fica mais alarmado quanto mais perto e mais iluminado
está o que ele vê. `alarm(1.0, 1.0)` passa de 75; `alarm(9.0, 0.0)` fica
abaixo de 25; no meio, ele anda aos poucos. Este arquivo é executado por
`alarm_example_test.gd`, e o *gate* garante que a página é igual a ele. Os
comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_fuzzy/alarm_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_fuzzy.md, run by
# alarm_example_test.gd. A guard of your own that grows more alarmed the
# nearer and the better lit what it sees is -- by degrees, not at a line.
extends Node

var _controller: FuzzyRuleBase


func _ready() -> void:
	var distance := FuzzyVariable.new("distance", 0.0, 10.0, [
		FuzzySet.new("near", PackedFloat64Array([0, 0, 2, 6])),
		FuzzySet.new("far", PackedFloat64Array([2, 6, 10, 10])),
	] as Array[FuzzySet])
	var light := FuzzyVariable.new("light", 0.0, 1.0, [
		FuzzySet.new("dark", PackedFloat64Array([0, 0, 0.2, 0.6])),
		FuzzySet.new("lit", PackedFloat64Array([0.2, 0.6, 1, 1])),
	] as Array[FuzzySet])
	# An output is measured at 101 points across its range by the centroid.
	var alarm := FuzzyVariable.new("alarm", 0.0, 100.0, [
		FuzzySet.new("calm", PackedFloat64Array([0, 0, 10, 35])),
		FuzzySet.new("wary", PackedFloat64Array([20, 45, 55, 80])),
		FuzzySet.new("alarmed", PackedFloat64Array([65, 90, 100, 100])),
	] as Array[FuzzySet], 101)
	_controller = FuzzyRuleBase.new([distance, light] as Array[FuzzyVariable],
		[alarm] as Array[FuzzyVariable], [
			_rule("near", "lit", "alarmed"),
			_rule("near", "dark", "wary"),
			_rule("far", "lit", "wary"),
			_rule("far", "dark", "calm"),
		] as Array[FuzzyRule])
	# A misspelt set or an empty range is refused here, not guessed at later.
	if _controller.problem() != "":
		push_error(_controller.problem())


## How alarmed the guard is, 0 to 100, by what it sees: `distance` in metres
## and `light` from 0, dark, to 1, lit. Your game moves its guard by this.
func alarm(distance: float, light: float) -> float:
	return _controller.evaluate({"distance": distance, "light": light})["alarm"]


## Why: how strongly each of calm, wary and alarmed was concluded. Draw it,
## and the player sees which rule fired. Empty when an input is not a finite
## number, as `alarm` is then NAN: refused, not read as zero.
func why(distance: float, light: float) -> Dictionary:
	return _controller.activations({"distance": distance, "light": light}).get("alarm", {})


# IF distance IS `near_or_far` AND light IS `dark_or_lit` THEN alarm IS `alarm_term`.
func _rule(near_or_far: String, dark_or_lit: String, alarm_term: String) -> FuzzyRule:
	return FuzzyRule.new([
		PackedStringArray(["distance", near_or_far]),
		PackedStringArray(["light", dark_or_lit]),
	] as Array[PackedStringArray], PackedStringArray(["alarm", alarm_term]))
```

### O que você implementa {#implement}

A medição: o seu jogo entrega a `evaluate` um `Dictionary` de nome de
entrada para um número finito, com todas as entradas presentes -- uma que
falte é recusada (sai `NAN`), e não lida como zero. E a ação: o número que
volta é uma quantidade, então o seu jogo decide o que ele significa -- uma
suspeita que sobe em direção a ele a cada turno, como a do guarda do
*stealth*, ou uma velocidade. Os *arrays* são tipados com rigor: conjuntos
são `Array[FuzzySet]`, variáveis `Array[FuzzyVariable]`, regras
`Array[FuzzyRule]`, e cada condição um `PackedStringArray` de variável e
conjunto. Chame `problem()` uma vez depois de montar: `""` quer dizer que
ele pode ser avaliado.

## Para ir mais fundo {#deeper}

- A suspeita do guarda do *stealth*, regra por regra (em inglês):
  [concepts/stealth.md](../concepts/stealth.md).
- Por que o kit reescreveu a lógica *fuzzy* em vez de portar uma biblioteca
  (em inglês): [ADR 0011](../adr/0011-fuzzy-is-rewritten-not-ported.md).
