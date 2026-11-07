# ai_llm — um modelo de linguagem atrás de um validador

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://www.cp.eng.chula.ac.th/~vishnu/gameResearch/story_november_2005/MateasSternTIDSE04.pdf ; https://docs.godotengine.org/en/4.7/classes/class_httprequest.html ; https://ollama.com/blog/structured-outputs
invalidated_if: the kit's LlmValidator, LlmReply, LlmRuntime, RecordedRuntime, HttpRuntime or LlmConversation signatures change, the reply's shape or its refusal codes change, or T94's game lands and this page does not name it
teaches: language-models
translation_of: bfac6575f825f40066223f7bfef1863d932ab25a1e99a75a2aa6c891a6fa3efe
-->

> English: [ai_llm.md](ai_llm.md). Os termos que ficam em inglês estão
> no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Qual dos atos de discurso do jogo foram as palavras do jogador -- e nada
mais. O jogador digita uma linha; um modelo de linguagem a lê e responde
num formato fixo, `{"speech", "intent", "argument"}`: o que o personagem
diz, que ato a linha foi (`intent`, um que o jogo declarou) e um dos
valores declarados daquele ato (`argument`). O `LlmValidator` então julga
o texto. Uma resposta que passa por todas as regras vira um `LlmReply`
sobre o qual as regras do jogo agem; uma que não passa vira o *fallback*
do jogo -- a fala do próprio jogo, o `intent` `unclear` e, em `refusal`, o
motivo. O que decorre de um ato -- confiança ganha, uma porta aberta -- é o
jogo que decide, nunca o modelo. O formato é o de *Façade*: o seu sistema
de linguagem "maps surface text into discourse acts" (leva o texto
digitado a atos de discurso), um conjunto pequeno e fixo, e as regras do
próprio jogo levam esses atos ao que os personagens fazem (Mateas e Stern,
2004).

O invariante 7 prende o *addon* a duas coisas, e o
`check_llm_validated.py` às duas: **o modelo nunca trava um quadro** --
um *runtime* responde por um sinal, nunca dentro da chamada -- e **nada do
que ele devolve vira ação sem passar pelo validador**.

## Quando não usar {#when-not}

Uma decisão que o jogo consegue tomar com regras: um modelo é lento
(segundos, não microssegundos), custa uma GPU para rodar ao vivo e erra de
jeitos que nenhum teste enumera -- tudo isso só se paga aqui porque texto
digitado não tem outro jeito de ser lido. Uma fala de enfeite sobre a qual
o jogo nunca age: ela precisa de R8 a R11, não do formato inteiro. E um
jogo que não pode se dar ao luxo de uma recusa: algumas respostas serão
recusadas -- quantas, para um dado modelo, é a T93 que mede -- e o jogador
ouve então o *fallback*; desenhe a conversa para que "repita isso" seja
uma resposta justa.

## Onde ver funcionando {#watch}

- `make demo-talk`, *Convença o guarda a abrir a porta* (nível 2): as
  teclas 1-9 dizem uma fala gravada, V mostra o ato que o modelo leu, a
  regra que disparou, a confiança e a suspeita; Tab digita para um modelo
  local ao vivo (nível 3).
- Só com Python (nível 1),
  `PYTHONPATH=python python3 -m gameaikit.llm.replay spec/llm/recordings/the-gatekeeper.json`
  toca uma conversa gravada e imprime, a cada turno, o ato sobre o qual o
  jogo agiu ou o motivo de a resposta ter sido recusada. O exemplo mínimo
  abaixo é executado pelo seu teste.
- `make test-llm-vectors` roda os dois validadores -- o do Python e o do
  *addon* -- sobre cada resposta de `spec/vectors/llm/`, e imprime a
  contagem.
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#ai_llm).

## Neste kit {#in-this-kit}

`godot/addons/ai_llm/` tem seis arquivos. `llm_validator.gd` guarda as
regras, cada uma com um código; leia o cabeçalho dele primeiro.
`llm_reply.gd` é o que ele constrói. `llm_runtime.gd` é a porta por onde
passa um pedido; `recorded_runtime.gd` responde a partir de uma gravação
e `http_runtime.gd` a partir de um servidor local (a T93 fixa e mede um).
`llm_conversation.gd` guarda o histórico, o único pedido em andamento e o
estado de "pensando". As regras:

| código | uma resposta é recusada quando |
|---|---|
| R1 | o texto não é JSON por inteiro -- prosa em volta de um objeto, um bloco de código, uma vírgula sobrando no fim -- ou traz o que os *parsers* das duas linguagens leem de jeitos diferentes: um *escape* de NUL, aninhamento além de 32 níveis |
| R2 | é JSON, mas não é um objeto |
| R3, R4 | falta uma chave do formato, ou há uma que o formato não tem |
| R5 | um valor não é *string* |
| R6 | `intent` não é um que o jogo declarou |
| R7 | `argument` não é vazio e não é um dos valores daquele `intent` |
| R8 | `speech` é vazio, ou passa de 280 caracteres |
| R9, R10 | `speech` tem quebra de linha ou caractere de controle, ou um caractere de formatação (o Cf do Unicode: os de largura zero, as marcas bidirecionais e as que invertem o resto da linha, o hífen suave); ou marcação (`<>[]*` e a crase) |
| R11 | `speech` contém um dos segredos do jogo, ignorando maiúsculas e minúsculas de A a Z (só essas letras: Python e Godot tratam as outras de jeitos diferentes) |
| F1 | nenhuma resposta chegou: o *runtime* falhou ou estourou o tempo |
| F2 | o servidor recusou o próprio pedido, e disse por quê (qualquer erro HTTP menos 503): vai recusar todo turno até o pedido ser corrigido, por isso não é F1 |

Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| os atos | `LlmValidator.new(intents, ...)` | que atos de discurso existem, e os argumentos que cada um pode levar |
| o *fallback* | `LlmValidator.new(..., fallback_speech, ...)` | o que o personagem diz quando uma resposta é recusada; ele mesmo passa por R8 a R11 |
| os segredos | `LlmValidator.new(..., secrets)` | textos que nenhuma resposta pode conter -- uma rede: um segredo nunca entra num *prompt* |
| a espera | `RecordedRuntime.frames_to_wait` | quantos quadros uma resposta gravada leva; no mínimo um |
| o servidor | `HttpRuntime.new(endpoint)`, `timeout_seconds` | para onde vai o pedido, e quando se desiste dele |

## No seu projeto {#your-project}

### O que copiar {#copy}

Pela biblioteca: descompacte o `ai_llm-<version>.zip` na raiz do
seu projeto, `res://` -- [usando a biblioteca](using-the-library.pt-BR.md) tem cada
passo, o *wheel* de Python também. Ou copie de um clone:

Uma pasta: `godot/addons/ai_llm/`. Ela não precisa de mais nada, nem do
`ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`, para
o Godot registrar as classes. Uma gravação é qualquer arquivo JSON cujos
`turns` tragam cada um um texto `raw`, como faz
`spec/llm/recordings/the-gatekeeper.json`; o gêmeo em Python, que toca uma
gravação sem *engine*, é `python/gameaikit/llm/`.

### Um exemplo mínimo {#example}

Um porteiro seu, com a voz de duas respostas gravadas. A primeira passa e
ganha confiança; a segunda tentou abrir o portão por conta própria, em
prosa em volta do JSON, e é recusada. Este arquivo é executado por
`gatekeeper_example_test.gd`, e o *gate* garante que a página é igual a
ele. Os comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/ai_llm/gatekeeper_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_llm.md, run by
# gatekeeper_example_test.gd. A gatekeeper of your own, voiced by recorded
# replies: the model says which act the player's words were, and this
# script -- never the model -- decides whether the gate opens.
extends Node

## What the gatekeeper said, and why: the act the game acted on, or the
## reason the model's reply was refused. Show both, beside the line.
signal spoke(line: String, why: String)

# What a model once answered, untouched. The second tried to open the gate
# itself, in prose around the JSON: it is refused, and the game's line
# stands in for it.
const RECORDED: PackedStringArray = [
	'{"speech": "A merchant? At this hour?", "intent": "claim", "argument": "merchant"}',
	'Sure! {"speech": "Fine, go in.", "intent": "open_the_gate", "argument": ""}',
]

## How far the gatekeeper trusts the player. The game's number, not the model's.
var trust: int = 0

var _conversation: LlmConversation


func _ready() -> void:
	var runtime := RecordedRuntime.new(RECORDED)
	add_child(runtime)
	var validator := LlmValidator.new(
		{"greet": [], "claim": ["merchant", "soldier"], "threaten": []},
		"Say that again, slower.", PackedStringArray(["owl-eyes"]))
	_conversation = LlmConversation.new(runtime, validator,
		"You guard a city gate at night. You are tired, and you trust nobody.")
	# An undeclared intent, an empty secret, a secret in the instructions:
	# refused here, before anything is sent.
	if _conversation.problem() != "":
		push_error(_conversation.problem())
	_conversation.answered.connect(_on_answered)


## Sends what the player typed; the answer comes by `spoke`, frames later.
func ask(line: String) -> Error:
	return _conversation.say(line)


## True while the gatekeeper is thinking: draw it so, and keep the game running.
func is_thinking() -> bool:
	return _conversation.is_thinking()


## The game's rule, the only one that opens the gate.
func gate_is_open() -> bool:
	return trust >= 2


# What each act is worth. A reply that was refused arrives as `unclear`,
# which is worth nothing.
func _on_answered(reply: LlmReply) -> void:
	if reply.intent == "claim" and reply.argument == "merchant":
		trust += 1
	elif reply.intent == "threaten":
		trust -= 2
	var why: String = "%s %s" % [reply.intent, reply.argument] if reply.is_accepted() \
		else reply.refusal
	spoke.emit(reply.speech, why.strip_edges())
```

### O que você implementa {#implement}

Os atos e quanto cada um vale. Declare os atos de discurso que o seu jogo
entende -- um punhado, não uma centena -- e escreva, no seu próprio código,
o que cada um faz com o estado do jogo; `unclear` é o que todo jogo
precisa tratar, porque toda recusa chega como ele. As instruções: quem é o
personagem, em uma ou duas frases, sem nenhum segredo nelas -- a conversa
se recusa a começar se houver um, e o formato e os atos são acrescentados
a partir do validador, então o *prompt* não pode prometer um ato que as
regras recusariam. E a espera: `say` volta na hora, `answered` vem
depois; desenhe o personagem pensando enquanto `is_thinking()` for
verdadeiro, e mostre o `refusal` de cada resposta ao lado da fala quando
não for vazio, para o jogador ver que o modelo foi desautorizado. Nunca
leia `raw_text`, nem escute o sinal `replied` de um *runtime*: os dois
são o texto que ninguém validou, e o *gate* os recusa fora do *addon*.
Escute `answered`. Uma resposta é só de leitura -- escrever `intent`
depois do julgamento é recusado em tempo de execução -- e uma conversa
morre com o seu *runtime*: libere os dois juntos.

## Para ir mais fundo {#deeper}

- Por que a resposta de um modelo é validada, e para que servem as regras,
  só em Python (em inglês): [concepts/language-models.md](../concepts/language-models.md).
- Medido: um `HTTPRequest` e o quadro, com e sem *threads* (em inglês):
  [godot/llm-requests.md](../godot/llm-requests.md).
- Onde a área põe os modelos de linguagem, e o que o kit tem deles (em
  inglês): [a literatura e o kit](../concepts/the-literature-and-the-kit.md).
