# ai_bayes — tem alguém aí, e por que você acha isso?

<!-- doc-meta
half_life: practice
verified_on: 2026-11-07
tier: 1
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 13, Probabilistic Reasoning, sections 13.2 and 13.3.1, figures 13.2 and 13.10
invalidated_if: the kit's BayesNetwork signature or its data shape changes, or the infiltration demo stops asking it
teaches: stealth-ai
translation_of: 51e7ddcb9645bdb0cd08bcfd90cb3df495de2457160df0dd35209396b39d2669
-->

> English: [ai_bayes.md](ai_bayes.md). Os termos que ficam em inglês
> estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

Quão provável é algo que você não vê, a partir do que você vê -- e qual
das coisas que você viu te fez pensar assim. Uma rede bayesiana é uma lista
de variáveis discretas, cada uma com poucos valores ("yes" e "no"; ou
"calm", "windy", "storm") e seus pais, as variáveis de que ela depende
diretamente. Cada variável guarda uma tabela de probabilidade condicional:
uma linha para cada jeito que os pais podem estar, e em cada linha a chance
de cada um dos seus valores. Essas linhas são todos os números que existem.
A rede diz que uma variável, sabidos os pais, não se importa com mais nada
acima dela; então a chance de uma atribuição inteira é um produto, uma
entrada de tabela por variável.

`BayesNetwork.ask(query, evidence)` responde P(query | evidence) como o
ENUMERATION-ASK da 4ª edição do AIMA (13.3.1, fig. 13.10): para cada valor
da consulta, com a evidência e esse valor fixos, soma o produto sobre todo
valor de toda variável que ficou escondida, e depois normaliza. O exemplo
do livro, o alarme contra ladrão sobre o qual John e Mary telefonam, dá
0,284, feito à mão no [README dos vetores](../../spec/vectors/bayes/README.md).
`influence(query, value, evidence)` diz então o que cada peça de evidência
fez: a resposta com ela, menos a resposta sem ela. A maior delas em módulo
é `most_moved` -- para qualquer lado, então pode ser um sinal que não foi
visto e baixou a crença ("nenhum barulho"). O que o guarda usa é mais
estreito: o sinal que ele viu e que mais subiu a crença, a pista dele, que
é para onde ele anda e o que o painel dele marca.

Uma causa que explica um efeito torna menos prováveis as outras causas
desse efeito: um alarme explicado por um terremoto torna um roubo menos
provável do que o alarme sozinho tornava. Isso é *explaining away*, e sai
das somas sem nenhuma regra escrita para isso. A rede do guarda tem um: um
parceiro que ficou em silêncio é obra do intruso, a menos que o rádio esteja
com defeito.

## Quando não usar {#when-not}

Quando a rede tem dezenas de variáveis: a enumeração é exponencial nas
escondidas, e cada variável de sim ou não dobra o trabalho. A eliminação de
variáveis (AIMA 13.3.2) guarda os produtos parciais de cada soma em vez de
calculá-los de novo, e é o próximo passo; não está construída aqui, nem a
amostragem (13.4). Quando uma variável é um número, e não poucos valores:
discretize-a, ou use um filtro, como as partículas do `ai_perception` fazem
para um lugar. Quando a crença tem de acompanhar o tempo -- alguém estava
aqui há um minuto, então pode estar ali agora --, isso é uma rede dinâmica
(cap. 14); esta é perguntada de novo a cada vez, e o jogo decide por quanto
tempo um sinal vale. E quando as tabelas são palpites que ninguém consegue
defender: a aritmética é exata, mas só tão boa quanto o que ela multiplica.
Aqui as tabelas são escritas à mão, em dados, e nunca mudam durante o jogo
(invariante 6); aprendê-las de registros seria no Python, fora do jogo.

## Onde ver {#watch}

- `make demo-infiltration` -- o painel embaixo do radar é a rede do guarda
  observado: "tem alguém aí?", com a crença numa barra e uma marca onde
  começa a verificação dos indícios (0,3); a chance de o rádio estar com
  defeito; cada sinal -- barulho, porta aberta, parceiro em silêncio --
  visto ou não, com o que fez à crença, a pista -- o sinal visto que mais a
  subiu, para onde o guarda vai andar -- marcada com `>`;
  e a última mudança, qual sinal e a crença antes e depois. Vá até uma
  porta, aperte **F** para abri-la e saia: um guarda que a vê aberta passa
  da marca, vai até ela (a ação dele diz "verificar os indícios"), fecha a
  porta, e a crença dele cai de novo. **Tab** observa o próximo guarda.
  No mercado (**L** depois dos níveis gerados, T152) um quarto sinal, o
  vulto que o olho do guarda destacou de uma multidão: ande no passo com um
  grupo e ele "se mistura", baixando a crença; corra ou agache e ele
  "destoa", subindo-a.
- Que demo usa que técnica, nos dois sentidos: o
  [catálogo](catalogue.pt-BR.md).

## Neste kit {#in-this-kit}

`godot/game3d/infiltration/intruder_network.json` é a rede do guarda: o
intruso (0,05) e um rádio com defeito (0,02) como causas; um barulho
ouvido, uma porta encontrada aberta e um parceiro em silêncio como sinais.
O `GuardSuspicion` guarda os sinais de cada guarda -- um som de um tipo que
o arquivo nomeia, uma porta que os olhos dele viram aberta, um parceiro que
ele notou em silêncio --, cada um visto "yes" enquanto o arquivo o mantém,
"no" no resto do tempo, e pergunta à rede de novo sempre que o que é visto
muda. O *explaining away* aparece no painel: só com um parceiro em
silêncio, a chance de o rádio estar com defeito é 0,548; quando uma porta
também é encontrada aberta, ela cai para 0,047 -- agora o intruso explica o
silêncio. Um barulho sozinho dá 0,07, uma porta sozinha 0,42, os dois 0,94. Num nível com multidão entra um `figure` com o intruso como pai, observado só enquanto o olho do guarda destaca alguém de um grupo e somado no resto do tempo: misturar-se dá 0,0018 onde nada visto dá 0,0036, destoar sozinho 0,08 -- ainda abaixo do limiar -- e com um barulho 0,65. O
seletor do guarda (`ai_utility`) lê a crença como mais um número: a ação
"verificar os indícios" pontua de 0,3 para cima, e o guarda anda até o sinal
que mais subiu a crença. Lá o sinal se resolve -- uma porta que ele encontra
aberta é fechada -- e a crença cai de novo. As mesmas tabelas são um vetor
de conformidade, então os números do jogo são conferidos nas duas linguagens.
Os ajustes:

| ajuste | onde | o que muda |
|---|---|---|
| variáveis | `{"name", "values", "parents", "table"}` nos dados, um pai antes do filho | sobre o que se raciocina, e o que depende de quê |
| tabela | uma linha por combinação dos valores dos pais, o primeiro pai variando mais devagar | toda chance que existe; uma linha precisa somar 1 |
| evidência | o dicionário passado ao `ask`, de variável para valor | o que foi visto; uma variável que fica de fora é somada |
| limiar | o degrau da ação "check the evidence" sobre `intruder`, em `guard_actions.json` | quão certo um guarda precisa estar antes de ir olhar |
| remember_for, settled_within | cada sinal em `intruder_network.json`, e o arquivo | por quanto tempo um sinal conta, e quão perto o guarda precisa chegar para resolvê-lo |

## No seu projeto {#your-project}

### O que copiar {#copy}

Da biblioteca: descompacte `ai_bayes-<versão>.zip` na raiz do seu projeto,
`res://` -- [usando a biblioteca](using-the-library.pt-BR.md) tem cada
passo, o *wheel* de Python também. Ou copie de um clone:

Uma pasta: `godot/addons/ai_bayes/`. Ela não precisa de mais nada, nem do
`ai_core`. Abra o projeto uma vez, ou rode `godot --headless --import`, para
o Godot registrar a classe. O gêmeo em Python é o `gameaikit.bayes`, para
perguntar à mesma rede sem a *engine*.

### Um exemplo mínimo {#example}

Um vigia noturno seu que ouve o cachorro e vê o portão, e quer saber se
alguém entrou -- e por que acha isso. Este arquivo é executado pelo
`watchman_example_test.gd`, e o *gate* mantém a página igual a ele.

<!-- example: godot/test/ai_bayes/watchman_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_bayes.md, run by
# watchman_example_test.gd. A night watchman of your own who hears the dog
# and sees the gate, and wants to know whether anyone came in -- and why he
# thinks so.
extends Node

# Written by hand: a parent before its child, one row per way its parents
# can be, the chances in a row summing to 1. Nothing here changes them.
const NETWORK: Dictionary = {"variables": [
	{"name": "intruder", "values": ["yes", "no"], "parents": [], "table": [[0.05, 0.95]]},
	{"name": "dog_barks", "values": ["yes", "no"], "parents": ["intruder"], "table": [[0.8, 0.2], [0.1, 0.9]]},
	{"name": "gate_open", "values": ["yes", "no"], "parents": ["intruder"], "table": [[0.6, 0.4], [0.02, 0.98]]},
]}

var _network := BayesNetwork.new(NETWORK)
# What the watchman has noticed, yes or no; what he has not checked is left
# out, and the network sums over it.
var _seen: Dictionary = {}


func _ready() -> void:
	# A parent given after its child, a row short or a row not summing to 1
	# is refused here.
	if _network.problem() != "":
		push_error(_network.problem())


## He noticed `evidence` -- "dog_barks" or "gate_open" -- happen, or not.
func noticed(evidence: String, happened: bool) -> void:
	_seen[evidence] = "yes" if happened else "no"


## He stops counting `evidence`: he checked, and it meant nothing.
func forget(evidence: String) -> void:
	_seen.erase(evidence)


## The chance someone came in, from what he has noticed.
func chance_of_intruder() -> float:
	return _network.ask("intruder", _seen)[0]


## What moved his belief most -- the line to show over his head.
func reason() -> String:
	return BayesNetwork.most_moved(_network.influence("intruder", "yes", _seen))
```

### O que você implementa {#implement}

As tabelas, e o que conta como cada peça de evidência. Escreva um pai antes
do filho; dê a cada tabela uma linha por combinação dos valores dos pais, o
primeiro pai variando mais devagar, cada linha somando 1; chame `problem()`
depois de montar -- `""` quer dizer que ela pode ser perguntada, e qualquer
outra coisa nomeia a regra quebrada (B1 a B5, o README dos vetores lista).
Decida, no seu jogo, quando uma variável é vista "yes", vista "no", ou não
vista: deixada fora da evidência, ela é somada, o que é diferente de "no".
O `ask` devolve um *array* vazio quando a evidência não pode acontecer com
as suas tabelas (uma chance de 0), então leia antes de indexar. E mantenha
a rede pequena: cada variável escondida dobra o trabalho de cada pergunta.

## Mais a fundo {#deeper}

- Como os guardas de *stealth* percebem e decidem, e onde esta rede fica ao
  lado da *awareness* e do mapa de crença:
  [concepts/stealth-ai.md](../concepts/stealth-ai.md).
- O roubo feito à mão, e as regras que uma terceira implementação precisa
  seguir: [spec/vectors/bayes/README.md](../../spec/vectors/bayes/README.md).
- Onde as redes bayesianas ficam entre as técnicas da área:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
