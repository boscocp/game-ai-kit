# Behaviour cloning — o lutador que joga como você

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct
invalidated_if: ClonedPlayer, SoftmaxModel, CaseTable, the clone file's shape or gameaikit.cloning's publish change, or demo-fighting is renamed
teaches: behaviour-cloning
translation_of: e2ce9edda44129f243560af79ef924216ee403fda90393cbe721c82d53034285
-->

> English: [behaviour_cloning.md](behaviour_cloning.md). Os termos que
> ficam em inglês estão no [glossário](glossary.pt-BR.md).

## O que decide {#what}

O que um jogador gravado faria nesta situação. Cada luta que o jogador
joga é guardada como um registro de comandos; cada decisão nela vira uma
linha -- a situação em poucas palavras (a última ação, a distância, a vida,
um canto) e a ação que o jogador escolheu. Das linhas saem dois
adversários. Um *ghost* (`CaseTable`) consulta a situação: o que o jogador
fez exatamente nela, ou nas mais próximas que encontrou. Um *clone*
(`SoftmaxModel`) é um modelo ajustado no Python, que dá uma probabilidade
para cada ação até numa situação que o jogador nunca encontrou. As
*Shadows* de Killer Instinct são deste tipo: se você nunca defende enquanto
treina a sua *shadow*, ela nunca defende.

## Quando não usar {#when-not}

Um adversário que deve ser bom: um *clone* é tão bom quanto o jogador
gravado, e só nas situações que o jogador encontrou. Poucas gravações: o
*ghost* então não sabe nada da maior parte da luta, e o *clone* chuta a
partir do pouco que viu. Muitas *features* com muitas palavras cada: as
situações se multiplicam além de qualquer coisa que um jogador encontre. E
o tempo que um jogador segura uma ação: as linhas guardam uma decisão por
troca de ação, então o *clone* decide antes do que o jogador decidia.

## Onde ver funcionando {#watch}

- `make demo-fighting` -- **M** troca o boneco de treino: "ghost: exact",
  "ghost: nearest" e "clone" lutam como o jogador gravado. O painel mostra
  a situação que ele leu e entre o que ele sorteou; **P** pausa, **espaço**
  avança um quadro.
- `make record-fights` -- jogue o modo de treino e guarde cada luta, para o
  próximo *clone* aprender com ela.
- Qual demo usa qual técnica, nos dois sentidos: [o catálogo](catalogue.pt-BR.md#behaviour_cloning).

## Neste kit {#in-this-kit}

O Godot grava e reproduz: `make record-fights` guarda cada luta como um
registro de comandos em `data/fights/`, e `make clone-rows` as reproduz e
corta uma linha por decisão em `data/cloning/rows.json` -- só o Godot
consegue reproduzir uma luta. O Python ajusta: `python/gameaikit/cloning/`
ajusta o modelo *softmax*, conta a tabela do *ghost* e escreve os dois em
`godot/game/fighting/clone_weights.json` (`make train-clone`).
`godot/game/fighting/fight_clone_opponent.gd` joga com ele por meio do
`ClonedPlayer`. Os ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| o jogo de quem | `CLONE_PLAYER` para `make train-clone` | o jogador gravado, ou um substituto programado |
| as *features* | a situação com que as linhas são cortadas | o que o *clone* consegue distinguir; cada palavra é uma coluna |
| exata ou mais próxima | `CaseTable.exact`, `CaseTable.nearest` | o que um *ghost* faz numa situação que o jogador nunca encontrou |
| *ghost* ou *clone* | **M** no jogo | uma consulta ou um modelo ajustado, das mesmas linhas |

## No seu projeto {#your-project}

### O que copiar {#copy}

A metade Godot está na biblioteca, o `ai_learning-<version>.zip` ([usando a
biblioteca](using-the-library.pt-BR.md)). A metade Python é do exemplo de
luta e não vai no *wheel*, então é uma cópia:

O lado Python ajusta: `python/gameaikit/cloning/` (só a biblioteca padrão)
-- `softmax.py` o modelo, `ghost.py` a tabela, `publish.py` o arquivo. O
lado Godot só lê: `godot/addons/ai_learning/`, cujo
`ClonedPlayer.load_from(path)` carrega e confere o arquivo, e cujos
`SoftmaxModel` e `CaseTable` respondem. Gravar e cortar as linhas é do seu
jogo: as do kit estão em `godot/game/fighting/` e
`godot/test/fighting/export_clone_rows.gd`.

### Um exemplo mínimo {#example}

Um adversário seu que joga como um jogador gravado, a partir do arquivo
que o Python publicou: a resposta mais provável do *clone*, as suas
chances, e o que o *ghost* faria. Este arquivo é executado por
`clone_example_test.gd`, e o *gate* garante que a página é igual a ele. Os
comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/fighting/clone_example.gd -->
```gdscript
# The minimal example on docs/techniques/behaviour_cloning.md, run by
# clone_example_test.gd. An opponent of your own that plays like a recorded
# player: the model Python fitted to its decisions, and the ghost -- the
# table of what it did in each situation it met.
extends Node

var _player: ClonedPlayer


## Load the cloned player Python published at `path`. Returns "" when it
## loaded, or why not, with a code -- a half-read file is never played.
func load_player(path: String) -> String:
	_player = ClonedPlayer.load_from(path)
	return _player.error


## What the clone does in `situation` -- its features by name, each a word
## -- the likeliest answer of the fitted model.
func clone_answer(situation: Dictionary) -> String:
	return _player.model.likeliest(situation)


## How likely each answer is in `situation`: what a panel draws, so the
## player sees how sure the clone is.
func clone_chances(situation: Dictionary) -> Dictionary:
	return _player.model.probabilities(situation)


## What the recorded player did in the situations nearest `situation`, as
## answer to count: the ghost, looked up rather than fitted.
func ghost_counts(situation: Dictionary) -> Dictionary:
	return _player.cases.nearest(situation)["counts"]
```

### O que você implementa {#implement}

Uma gravação: os comandos do seu jogo, quadro a quadro, para uma luta poder
ser jogada de novo. Linhas: reproduza cada gravação e escreva, a cada
decisão, a situação em palavras e a ação escolhida -- as mesmas palavras
que o seu jogo vai montar quando perguntar. Depois ajuste no Python,
publique, e no Godot monte a situação a cada decisão e pergunte. Chame
`load_player` e mostre a mensagem dele quando não for `""`: um arquivo com
qualquer problema é recusado inteiro, com um código (C1 a C7), nunca jogado
pela metade. Uma palavra que o modelo nunca viu não soma nada e deixa a
resposta para as outras *features*.

## Para ir mais fundo {#deeper}

- As *Shadows*, o *ghost* e o *clone*, medidos (em inglês):
  [concepts/behaviour-cloning.md](../concepts/behaviour-cloning.md).
- O arquivo e o lado Godot (em inglês): [godot/cloning.md](../godot/cloning.md).
- A metade do *addon* que é o modelo: [ai_learning](ai_learning.pt-BR.md).
