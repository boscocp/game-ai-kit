# ai_sifting — que momentos valem ser contados?

<!-- doc-meta
half_life: practice
verified_on: 2026-11-11
tier: 1
source: https://github.com/mkremins/winnow
invalidated_if: the kit's StorySifter or SiftPattern signature changes, a pattern's keys change, or the valley's chronicle is renamed
teaches: story-sifting
translation_of: 9234fd070a8e0adb7971d16fb0d487370a9e7f2d9ab0e0acc5022e6cf1a9a8e9
-->

> English: [ai_sifting.md](ai_sifting.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Que momentos de um registro de eventos valem ser contados. Uma simulação
anota tudo o que acontece -- um feito, um fato que mudou durante a noite
-- e quase nada disso é uma história. Uma história é uma forma entre os
eventos: o celeiro queimou e depois foi reconstruído; a ponte caiu pela
terceira vez. *Story sifting* [Ryan 2018] é achar essas formas no registro
depois do fato, em vez de planejá-las antes.

O `StorySifter` faz isso como o Felt faz [Kreminski, Dickinson &
Wardrip-Fruin 2019]: quem projeta escreve um padrão (*pattern*) -- os
eventos a achar, cada um com um nome; variáveis (`?place`) que os ligam,
para que dois eventos sejam sobre o mesmo lugar; uma ordem (`before`); e
eventos que **não** podem estar lá (`unless`), entre dois dos achados, ou
antes ou depois de um. O *sifter* devolve cada casamento (*match*), com os
eventos que o formaram e o valor de cada variável. O que fazer com um
casamento -- uma linha de uma crônica, a fofoca de um aldeão -- é do jogo.

## Quando não usar {#when-not}

Quando o registro cresce enquanto o jogo roda e as histórias são pedidas
a cada quadro: peneirar o registro inteiro de novo a cada vez repete todo
o trabalho, e um padrão de k eventos custa até n^k tentativas. O vale
peneira quando um feito é guardado ou um dia acaba: 26 ms para os seus seis
padrões sobre 120 dias de feitos (239 eventos), medidos. O Winnow
[Kreminski, Dickinson & Mateas 2021] guarda os casamentos parciais e os
estende a cada evento que chega; não está no kit. Quando o mundo deveria
**agir** sobre uma história: um casamento é algo a contar, e um aldeão, um
preço ou uma porta que o lessem deixariam a escolha de histórias de quem
projeta mudar o jogo -- esses leem os fatos. E quando a pergunta é um
número -- quantos dias entre, quanto se perdeu: um padrão só pergunta
"estes eventos, nesta ordem, e não aqueles"; ponha o número nos eventos.

## Onde ver funcionando {#watch}

- `make demo-valley` -- faça um feito por dia (queime o celeiro, derrube a
  ponte), encerre alguns dias com N e aperte **C**. O painel vira a crônica
  do vale: cada linha que os padrões acharam -- o mercado sem pão por causa
  de um feito, o celeiro reconstruído, a terceira vez que o mesmo feito foi
  feito a um lugar -- e embaixo dela os eventos que casou. C de novo volta
  às razões dos aldeões.
- Que demo usa que técnica, nos dois sentidos: o
  [catálogo](catalogue.pt-BR.md).

## Neste kit {#in-this-kit}

`godot/game/valley/valley_chronicle.gd` deriva os eventos do vale do
registro de feitos -- os fatos que cada noite mudou, depois os feitos
daquele dia -- toda vez que conta, e nunca os salva (a ADR 0025 guarda
feitos e nada derivado). Uma mudança da noite também carrega o feito por
trás dela, seguido de volta pelas regras, então "o mercado ficou sem pão"
se liga ao feito que o causou, não ao último que veio antes. Os padrões
estão em
`godot/game/valley/chronicle.json`, e a frase de cada um em
`ValleyPanel.CHRONICLE`. Os botões que importam:

| botão | onde | o que muda |
|---|---|---|
| `find` | o padrão | os eventos a achar, cada um `{as, where}`: um nome, e os campos que um evento precisa ter |
| uma variável | um valor `"?name"` num `where` | liga eventos: o primeiro a amarra, os seguintes precisam ter o mesmo valor |
| `before` | o padrão, pares de nomes | o primeiro achado antes do segundo no registro |
| `unless` | o padrão, cada um `{where, after?, before?}` | um evento que não pode estar entre `after` e `before`; "a terceira vez" são três `find` e três `unless` |
| o registro | o primeiro argumento de `sift` | um `Array` de `Dictionary`, na ordem em que as coisas aconteceram; um evento é o seu índice |

Dois valores só são iguais quando são do mesmo tipo: `1` e `1.0` são um
número só, e `false` nunca é `0`, em GDScript e em Python. Um `unless`
nunca casa com um dos eventos achados pelo próprio casamento: três `find`
com um `unless` em volta do do meio não são recusados por ele. O Felt e o
Winnow não excluem os eventos achados por padrão; este kit sempre exclui, e
um vetor garante isso.
`gameaikit.sifting` é o gêmeo, e `spec/vectors/sifting/` prende os dois
aos mesmos casamentos.

## No seu projeto {#your-project}

### O que copiar {#copy}

Da biblioteca: descompacte `ai_sifting-<version>.zip` na raiz do seu
projeto, `res://` -- [usando a biblioteca](using-the-library.pt-BR.md) tem
cada passo, a *wheel* de Python também. Ou copie de um clone:

Uma pasta: `godot/addons/ai_sifting/`. Ela não usa mais nada, nem o
`ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`,
para o Godot registrar as classes.

### Um exemplo mínimo {#example}

Um taverneiro seu que reconta o que aconteceu na cidade. O jogo anota um
evento cada vez que algo acontece; o taverneiro peneira os eventos atrás
de uma história -- um ladrão pego na loja de onde roubou, e só o roubo
que a captura respondeu. Este arquivo é rodado por
`gossip_example_test.gd`, e o *gate* mantém a página igual a ele.

<!-- example: godot/test/ai_sifting/gossip_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_sifting.md, run by
# gossip_example_test.gd. A tavern keeper of your own who retells what
# happened in town: the game writes events down as they happen, and the
# keeper sifts them for one story -- a thief caught where they stole before.
extends Node

# The story, as data: the same thief, the same shop, a theft and then a
# catch, and no other theft by them there in between.
const CAUGHT_AGAIN: Dictionary = {
	"name": "caught-where-they-stole",
	"find": [
		{"as": "theft", "where": {"what": "theft", "who": "?thief", "where": "?shop"}},
		{"as": "catch", "where": {"what": "caught", "who": "?thief", "where": "?shop"}},
	],
	"before": [["theft", "catch"]],
	"unless": [{"where": {"what": "theft", "who": "?thief", "where": "?shop"}, "after": "theft", "before": "catch"}],
}

# What happened, in order. The game appends; nothing here edits an event.
var _events: Array[Dictionary] = []
var _sifter := StorySifter.new()


func _ready() -> void:
	# A misspelt key or an `unless` bounded by no event is refused here.
	if SiftPattern.problem(CAUGHT_AGAIN) != "":
		push_error(SiftPattern.problem(CAUGHT_AGAIN))


## Something happened in town.
func happened(day: int, what: String, who: String, where: String) -> void:
	_events.append({"day": day, "what": what, "who": who, "where": where})


## The keeper's stories, one line each, and the events each one is about:
## show both, and the player sees why the keeper tells it.
func stories() -> Array[Dictionary]:
	var told: Array[Dictionary] = []
	for match: Dictionary in _sifter.sift(_events, CAUGHT_AGAIN):
		var theft: Dictionary = _events[match["events"]["theft"]]
		var caught: Dictionary = _events[match["events"]["catch"]]
		var line: String = "%s stole from the %s on day %d, and was caught there on day %d." % [
			match["bindings"]["thief"], match["bindings"]["shop"], theft["day"], caught["day"]]
		told.append({"line": line, "events": match["events"].values()})
	return told
```

### O que você implementa {#implement}

O registro: acrescente um evento, um `Dictionary` de valores simples --
texto, números, verdadeiro ou falso -- sempre que acontecer algo sobre o
que uma história possa ser, e nunca edite um depois. Dê a cada evento os
campos que seus padrões pedem (`what`, `who`, `where`, um dia); um evento
sem um campo que o padrão nomeia não casa com ele. Depois, os padrões,
como dados, e o que um casamento vira: uma frase feita das variáveis e
dos campos dos eventos achados, mostrada ao lado desses eventos para o
jogador ver por que foi contada. Chame `SiftPattern.problem(pattern)` uma
vez: `""` quer dizer que está certo, e qualquer outra coisa -- uma chave
escrita errado, um `unless` limitado por um nome que ninguém achou --
começa com a sua regra, de P1 a P5. Entregue o registro ao *sifter* e leia
o que ele devolve; ele não escreve nada no registro, e os testes garantem
isso.

## Mais a fundo {#deeper}

- Como o vale se lembra, e o que ele se recusa a guardar:
  [concepts/karma-and-world-memory.md](../concepts/karma-and-world-memory.md)
  e a [ADR 0025](../adr/0025-a-save-is-a-record-of-deeds.md).
- O jogo em si: [godot/valley.md](../godot/valley.md).
- Onde *story sifting* fica entre as técnicas da área:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
