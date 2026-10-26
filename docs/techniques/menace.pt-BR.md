# MENACE — a máquina de caixas de fósforo que aprende jogo da velha

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Donald Michie, "Experiments on the mechanization of game-learning, part I", The Computer Journal 6(3), 1963
invalidated_if: MenacePlayer, the bead file's shape or gameaikit.menace's report change, or demo-tictactoe is renamed
teaches: reinforcement-learning
translation_of: 32014ed4d006654b7c173b7f16ea5e8cf4b4b0b5f2e0bc48e9f767aa19f606ce
-->

> English: [menace.md](menace.md). Os termos que ficam em inglês estão no
> [glossário](glossary.pt-BR.md).

## O que decide {#what}

Onde jogar no jogo da velha, sorteando uma conta. A máquina de Donald
Michie, de 1961, era uma caixa de fósforo para cada posição que ela podia
encontrar, cada uma com contas coloridas, uma cor por casa vazia. Para
jogar, tira-se uma conta da caixa desta posição e joga-se na casa dela;
depois da partida, acrescentam-se contas em toda caixa usada se ela
ganhou, menos se empatou, e tiram-se contas se perdeu. Uma casa que
continua ganhando junta contas e é sorteada mais vezes. Isso é aprendizado
por reforço só com a recompensa, com a política inteira na mesa para
contar. Posições que são o mesmo tabuleiro girado ou espelhado dividem uma
caixa. O artigo: Michie, *The Computer Journal*, 1963.

## Quando não usar {#when-not}

Qualquer jogo com mais posições do que você montaria em caixas de fósforo:
o jogo da velha tem algumas centenas de caixas depois de dobradas as
simetrias; um jogo com milhões não tem caixa para a maior parte do que
encontra, e não aprende nada sobre uma posição que nunca viu. E aprender
enquanto uma pessoa joga: acrescentar contas é treinar, então aqui isso
acontece no Python, a partir de uma semente, e o jogo joga com as contas
que recebeu (invariante 6).

## Onde ver funcionando {#watch}

- `make demo-tictactoe` -- o MENACE joga primeiro. **Espaço** sorteia a
  conta dele, e cada casa vazia mostra as suas contas e a chance de ser
  sorteada; **clique** numa casa para responder. **1-4** escolhem a idade
  dele -- depois de 10, 100, 1.000 ou 10.000 partidas -- e **M** mostra o
  que o jogo perfeito (*minimax*) acha de cada casa, para você ver onde o
  MENACE concorda com ele.
- Qual demo usa qual técnica, nos dois sentidos: o catálogo (T76, a caminho).

## Neste kit {#in-this-kit}

O aprendizado é `python/gameaikit/menace/`: `matchbox.py` é a máquina e a
regra de Michie, `train.py` a faz jogar a partir de uma semente, e
`report.py` publica as contas em quatro idades em
`godot/game/tictactoe/menace_beads.json` (`make train-menace`). No Godot,
`godot/game/tictactoe/menace_player.gd` lê esse arquivo só para leitura e
sorteia; `check_no_training.py` recusa uma contagem de contas escrita em
GDScript (N5) e um arquivo que uma execução nova não escreveria (N6). Os
ajustes que importam:

| ajuste | onde | o que muda |
|---|---|---|
| contas iniciais | `STARTING_BEADS` em `python/gameaikit/menace/matchbox.py` | o quanto uma caixa nova tem certeza; com menos, uma partida a mexe muito |
| as recompensas | `REWARDS` no mesmo arquivo | contas acrescentadas numa vitória e num empate, tiradas numa derrota |
| o adversário | `python/gameaikit/menace/opponents.py` | contra quem ele aprende, e portanto o que aprende |
| a idade | `MenacePlayer.move_for(age, board, chance)` | que retrato publicado joga: um iniciante ou um veterano |

## No seu projeto {#your-project}

### O que copiar {#copy}

O lado Python treina: `python/gameaikit/menace/` (só a biblioteca padrão)
-- `board.py` é o jogo e as suas simetrias, e é o que você reescreve para
outro jogo pequeno. Rode `PYTHONPATH=python python3 -m
gameaikit.menace.report --write <sua pasta>` para publicar as contas. O
lado Godot só faz inferência: `godot/game/tictactoe/menace_player.gd` e o
`tictactoe_board.gd` com que ele lê as caixas, mais o JSON publicado.

### Um exemplo mínimo {#example}

Um jogador seu que joga com as contas publicadas e mostra o quanto tem
certeza. `move_for(".........")` é uma casa de 0 a 8; `chances` é o que
desenhar sobre cada casa. Este arquivo é executado por
`menace_example_test.gd`, e o *gate* garante que a página é igual a ele. Os
comentários do código ficam em inglês, como no arquivo.

<!-- example: godot/test/tictactoe/menace_example.gd -->
```gdscript
# The minimal example on docs/techniques/menace.md, run by
# menace_example_test.gd. A player of your own that plays noughts and
# crosses by the beads Python published, and never adds or takes one.
extends Node

## How many games MENACE had played when the beads were published: 10,
## 100, 1000 or 10000. Fewer, and it plays like a beginner.
var age: int = 10000

var _menace: MenacePlayer = MenacePlayer.load_published()
var _dice := RandomNumberGenerator.new()


## The square, 0 to 8, MENACE plays on `board` -- nine characters, "X",
## "O" or "." row by row -- or -1 when its box is empty and it resigns.
func move_for(board: String) -> int:
	return _menace.move_for(age, board, _dice.randf())


## Each empty square's chance of being drawn: what the panel draws, so the
## player sees how sure the machine is.
func chances(board: String) -> Dictionary:
	var by_square: Dictionary = {}
	for square: Dictionary in _menace.squares_for(age, board):
		by_square[square["square"]] = square["probability"]
	return by_square
```

### O que você implementa {#implement}

Do lado Python, para um jogo seu: as posições como *strings*, as jogadas,
as simetrias (ou nenhuma), um adversário contra quem aprender e as
recompensas. Do lado Godot, nada que aprenda: leia o arquivo publicado,
sorteie com um número em [0, 1) -- o mesmo número dá a mesma casa no Python
e no Godot, o que `spec/vectors/menace/` garante -- e nunca escreva uma
conta. `MenacePlayer.draw(beads, chance)` é só a regra do sorteio, para
caixas suas.

## Para ir mais fundo {#deeper}

- A máquina de Michie, a sua regra e o que ela aprende em quantas partidas
  (em inglês): [concepts/menace.md](../concepts/menace.md).
- O aprendizado no kit, e por que ele acontece no Python (em inglês):
  [concepts/learning.md](../concepts/learning.md).
