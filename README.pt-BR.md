# game-ai-kit

> English: [README.md](README.md). Os termos que ficam em inglês estão no
> [glossário](docs/techniques/glossary.pt-BR.md).

Ensinar IA em jogos, uma peça legível por vez.

Um conjunto de *addons* do Godot 4 que você pode levar **um de cada vez**, e
pequenos jogos em que cada um deles decide alguma coisa de verdade. O código
foi escrito para ser lido: se um trecho é rápido e ilegível, ele perde para o
lento e legível.

Esta página é a porta de entrada em português, e é curta: o que o kit é, os
níveis de máquina, e onde ler cada técnica. O resto -- as decisões, a
licença, como usar um *addon* no seu projeto -- está no
[README em inglês](README.md). O código, os nomes e os comentários ficam em
inglês, que é o que você vai digitar.

## O que o kit cobre

<!-- catalogue:summary -->
<!-- written by scripts/catalogue.py: edit the inputs, then `make catalogue` -->

A IA é o foco deste kit, então aqui ela está nos dois sentidos, gerada a partir dos manifestos dos módulos. ● o código da própria demo usa a técnica; ◐ ela a alcança pelo código de outro exemplo. [O catálogo](docs/techniques/catalogue.pt-BR.md) tem a matriz inteira, as teclas que mostram cada decisão e como as marcas são medidas.

| técnica | o que decide | onde ver |
| --- | --- | --- |
| [ai_adversarial](docs/techniques/ai_adversarial.pt-BR.md) | a melhor jogada contra quem responde | ● [`make run`](docs/techniques/catalogue.pt-BR.md#run) |
| [ai_behaviour](docs/techniques/ai_behaviour.pt-BR.md) | o que fazer em seguida | ● [`make demo-behaviour`](docs/techniques/catalogue.pt-BR.md#demo-behaviour), ● [`make demo-rts`](docs/techniques/catalogue.pt-BR.md#demo-rts), ● [`make demo-tactical`](docs/techniques/catalogue.pt-BR.md#demo-tactical) |
| [ai_fuzzy](docs/techniques/ai_fuzzy.pt-BR.md) | quanto, aos poucos | ● [`make demo-stealth`](docs/techniques/catalogue.pt-BR.md#demo-stealth), ● [`make demo-infiltration`](docs/techniques/catalogue.pt-BR.md#demo-infiltration), ◐ [`make demo-behaviour`](docs/techniques/catalogue.pt-BR.md#demo-behaviour) |
| [ai_learning](docs/techniques/ai_learning.pt-BR.md) | usando o que o Python aprendeu | ● [`make demo-skirmish`](docs/techniques/catalogue.pt-BR.md#demo-skirmish), ● [`make demo-tactical`](docs/techniques/catalogue.pt-BR.md#demo-tactical), ● [`make demo-fighting`](docs/techniques/catalogue.pt-BR.md#demo-fighting) |
| [ai_opponent](docs/techniques/ai_opponent.pt-BR.md) | o que o jogador vai fazer agora? | ● [`make demo-fighting`](docs/techniques/catalogue.pt-BR.md#demo-fighting) |
| [ai_perception](docs/techniques/ai_perception.pt-BR.md) | o que um guarda vê, ouve e acredita | ● [`make demo-stealth`](docs/techniques/catalogue.pt-BR.md#demo-stealth), ● [`make demo-infiltration`](docs/techniques/catalogue.pt-BR.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.pt-BR.md#demo-botmatch), ● [`make demo-behaviour`](docs/techniques/catalogue.pt-BR.md#demo-behaviour) |
| [ai_planning](docs/techniques/ai_planning.pt-BR.md) | os passos até um objetivo que ninguém escreveu | ● [`make demo-rts`](docs/techniques/catalogue.pt-BR.md#demo-rts), ● [`make demo-tactical`](docs/techniques/catalogue.pt-BR.md#demo-tactical) |
| [ai_rts_core](docs/techniques/ai_rts_core.pt-BR.md) | muitas unidades, um quadro | ● [`make demo-rts`](docs/techniques/catalogue.pt-BR.md#demo-rts) |
| [ai_search](docs/techniques/ai_search.pt-BR.md) | achar um caminho | ● [`make demo-skirmish`](docs/techniques/catalogue.pt-BR.md#demo-skirmish), ● [`make demo-search`](docs/techniques/catalogue.pt-BR.md#demo-search), ● [`make demo-stealth`](docs/techniques/catalogue.pt-BR.md#demo-stealth), ● [`make demo-infiltration`](docs/techniques/catalogue.pt-BR.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.pt-BR.md#demo-botmatch), ● [`make demo-behaviour`](docs/techniques/catalogue.pt-BR.md#demo-behaviour) |
| [ai_steering](docs/techniques/ai_steering.pt-BR.md) | para que lado empurrar, e com que força | ● [`make demo-steering`](docs/techniques/catalogue.pt-BR.md#demo-steering), ● [`make demo-racing`](docs/techniques/catalogue.pt-BR.md#demo-racing), ● [`make demo-racing3d`](docs/techniques/catalogue.pt-BR.md#demo-racing3d) |
| [ai_teamwork](docs/techniques/ai_teamwork.pt-BR.md) | pesar ações, e um time que divide o trabalho | ● [`make demo-infiltration`](docs/techniques/catalogue.pt-BR.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.pt-BR.md#demo-botmatch) |
| [MENACE](docs/techniques/menace.pt-BR.md) | a máquina de caixas de fósforo que aprende jogo da velha | ● [`make demo-tictactoe`](docs/techniques/catalogue.pt-BR.md#demo-tictactoe) |
| [Avaliação aprendida](docs/techniques/learned_evaluation.pt-BR.md) | dar nota a uma posição com pesos ajustados aos resultados | ● [`make run`](docs/techniques/catalogue.pt-BR.md#run) |
| [Behaviour cloning](docs/techniques/behaviour_cloning.pt-BR.md) | o lutador que joga como você | ● [`make demo-fighting`](docs/techniques/catalogue.pt-BR.md#demo-fighting) |
| [O piloto de corrida](docs/techniques/racing_driver.pt-BR.md) | um ponto à frente, um perfil de velocidade, sem *rubber band* | ● [`make demo-racing`](docs/techniques/catalogue.pt-BR.md#demo-racing) |

| demo | como | a IA nela |
| --- | --- | --- |
| [`make run`](docs/techniques/catalogue.pt-BR.md#run) Damas | damas, você contra o computador | ● [ai_adversarial](docs/techniques/ai_adversarial.pt-BR.md), ● [Avaliação aprendida](docs/techniques/learned_evaluation.pt-BR.md) |
| [`make demo-skirmish`](docs/techniques/catalogue.pt-BR.md#demo-skirmish) A escaramuça (*skirmish*) | uma batalha pequena de Advance Wars | ● [ai_learning](docs/techniques/ai_learning.pt-BR.md), ● [ai_search](docs/techniques/ai_search.pt-BR.md) |
| [`make demo-tictactoe`](docs/techniques/catalogue.pt-BR.md#demo-tictactoe) Jogo da velha | jogo da velha, contra a máquina de caixas de fósforo de Michie | ● [MENACE](docs/techniques/menace.pt-BR.md) |
| [`make demo-search`](docs/techniques/catalogue.pt-BR.md#demo-search) Quatro buscas | o clicar-e-andar de qualquer jogo de estratégia, em câmera lenta, uma célula por vez | ● [ai_search](docs/techniques/ai_search.pt-BR.md) |
| [`make demo-stealth`](docs/techniques/catalogue.pt-BR.md#demo-stealth) *Stealth* | o *stealth* visto de cima do primeiro Metal Gear | ● [ai_fuzzy](docs/techniques/ai_fuzzy.pt-BR.md), ● [ai_perception](docs/techniques/ai_perception.pt-BR.md), ● [ai_search](docs/techniques/ai_search.pt-BR.md) |
| [`make demo-steering`](docs/techniques/catalogue.pt-BR.md#demo-steering) *Steering* | os inimigos de um jogo de ação perseguindo e parando, uma força por vez | ● [ai_steering](docs/techniques/ai_steering.pt-BR.md) |
| [`make demo-racing`](docs/techniques/catalogue.pt-BR.md#demo-racing) Corrida | Micro Machines, visto de cima, a IA no mesmo carro que o seu | ● [ai_steering](docs/techniques/ai_steering.pt-BR.md), ● [O piloto de corrida](docs/techniques/racing_driver.pt-BR.md) |
| [`make demo-racing3d`](docs/techniques/catalogue.pt-BR.md#demo-racing3d) Corrida em 3D | Gran Turismo, com pneus que derrapam | ● [ai_steering](docs/techniques/ai_steering.pt-BR.md) |
| [`make demo-infiltration`](docs/techniques/catalogue.pt-BR.md#demo-infiltration) Infiltração | Metal Gear Solid, em terceira pessoa | ● [ai_fuzzy](docs/techniques/ai_fuzzy.pt-BR.md), ● [ai_perception](docs/techniques/ai_perception.pt-BR.md), ● [ai_search](docs/techniques/ai_search.pt-BR.md), ● [ai_teamwork](docs/techniques/ai_teamwork.pt-BR.md) |
| [`make demo-botmatch`](docs/techniques/catalogue.pt-BR.md#demo-botmatch) Partida de *bots* | uma partida contra *bots* em Unreal Tournament ou Counter-Strike | ● [ai_perception](docs/techniques/ai_perception.pt-BR.md), ● [ai_search](docs/techniques/ai_search.pt-BR.md), ● [ai_teamwork](docs/techniques/ai_teamwork.pt-BR.md) |
| [`make demo-behaviour`](docs/techniques/catalogue.pt-BR.md#demo-behaviour) Um guarda, quatro jeitos de decidir | um guarda fazendo a ronda, como em Metal Gear ou Thief | ● [ai_behaviour](docs/techniques/ai_behaviour.pt-BR.md), ◐ [ai_fuzzy](docs/techniques/ai_fuzzy.pt-BR.md), ● [ai_perception](docs/techniques/ai_perception.pt-BR.md), ● [ai_search](docs/techniques/ai_search.pt-BR.md) |
| [`make demo-rts`](docs/techniques/catalogue.pt-BR.md#demo-rts) Estratégia em tempo real | StarCraft ou Age of Empires, contra um comandante que planeja | ● [ai_behaviour](docs/techniques/ai_behaviour.pt-BR.md), ● [ai_planning](docs/techniques/ai_planning.pt-BR.md), ● [ai_rts_core](docs/techniques/ai_rts_core.pt-BR.md) |
| [`make demo-tactical`](docs/techniques/catalogue.pt-BR.md#demo-tactical) Tática | Advance Wars | ● [ai_behaviour](docs/techniques/ai_behaviour.pt-BR.md), ● [ai_learning](docs/techniques/ai_learning.pt-BR.md), ● [ai_planning](docs/techniques/ai_planning.pt-BR.md) |
| [`make demo-fighting`](docs/techniques/catalogue.pt-BR.md#demo-fighting) Luta, modo treino | o modo treino de Street Fighter, contra um boneco que aprende você | ● [ai_learning](docs/techniques/ai_learning.pt-BR.md), ● [ai_opponent](docs/techniques/ai_opponent.pt-BR.md), ● [Behaviour cloning](docs/techniques/behaviour_cloning.pt-BR.md) |

<!-- /catalogue:summary -->

Cada técnica tem uma página em português, ao lado da inglesa, em
[`docs/techniques/`](docs/techniques/): o que ela decide, quando não usar,
onde vê-la decidir, e um exemplo mínimo que roda.

O `ai_core` fica embaixo de todos, e é pequeno de propósito: a grade e a
interface do *pathfinding* ([página](docs/techniques/ai_core.pt-BR.md)).
Leve qualquer *addon* e o `ai_core` com ele, e mais nada.

O aprendizado de máquina entra em **peças específicas**, nunca no jogo
inteiro. É esse o ponto: uma regressão logística que decide *atacar ou
recuar* tem pesos que você imprime e explica. Uma rede neural que joga o
jogo inteiro não ensina nada.

## Vai rodar na minha máquina?

Quatro níveis. **Nenhuma lição vive só no nível caro.**

| nível | você precisa de | você pode |
|---|---|---|
| **0** | nada | ler `docs/concepts/` -- os algoritmos e por que funcionam (em inglês) |
| **1** | Python 3 (já vem no Linux e no macOS) | ler e verificar um domínio PDDL, treinar as regressões, ler os pesos. Só a biblioteca padrão -- **sem pip, sem numpy, sem passo de instalação** |
| **2** | Godot 4 (~130 MB, roda em placa de vídeo integrada) | jogar, abrir as demos, modificar os *addons* |
| **2, em 3D** | Godot 4 e uma placa integrada que desenhe uma cena 3D | os exemplos 3D em `godot/game3d/`, com `make assets-3d` para os modelos ou formas simples sem eles; as decisões rodam sobre retratos do estado com gêmeos em Python, então a lição é de nível 1 |
| **3** | uma GPU com alguma VRAM | rodar um LLM local de verdade, quando o `ai_llm` existir; gerar a sua própria arte com um modelo local de imagem. Opcional: nada precisa deste nível |

O jogo mira 1280×720 a 60 fps em placa integrada, com o renderizador
Compatibility (OpenGL).

## Para começar

Nível 1, só com Python:

```bash
python3 -m unittest discover -s python/tests -t python
PYTHONPATH=python python3 -m gameaikit.tactical.report   # what the models learned
```

Nível 2, com o Godot:

```bash
make bootstrap     # downloads the pinned Godot and its Linux export templates to the large disk, SHA-512 verified
make menu          # every example on one menu: a card says what its AI decides and how; Esc comes back
make run           # checkers against minimax and alpha-beta
make demo-skirmish # the learned policy plays blue on the skirmish board
make demo-tictactoe # MENACE, the matchbox machine, at four ages of training
make demo-search   # the four searches on a board you can paint
make demo-tactical # Advance Wars style turns against the computer, at three levels
make check         # every gate
```

Os comentários dos blocos acima ficam em inglês, como no código.
