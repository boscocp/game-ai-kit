# O catálogo: cada demo, e a IA que há nela

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 0
source: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html ; book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019
invalidated_if: a demo stops showing a technique its scene still reaches, or a known game or a key in games.json no longer matches its demo
teaches: none
-->

> English: [catalogue.md](catalogue.md). Os termos que ficam em inglês estão no [glossário](glossary.pt-BR.md).

Gerado por `scripts/catalogue.py` a partir de `modules/*.json`, dos alvos `run` e `demo-*` do Makefile, dos cartões do menu, de `non_module_techniques.json` e de `games.json`. Não edite à mão: `make catalogue` escreve de novo, e `make lint-catalogue` falha enquanto estiver desatualizado.

## As demos e suas técnicas {#matrix}

Uma linha por demo, uma coluna por técnica; cada marca leva à página da técnica, e as linhas abaixo dão os nomes dos algoritmos.

| demo | `ai_adversarial` | `ai_behaviour` | `ai_fuzzy` | `ai_learning` | `ai_opponent` | `ai_perception` | `ai_planning` | `ai_rts_core` | `ai_search` | `ai_steering` | `ai_teamwork` | `ai_utility` | `menace` | `learned_evaluation` | `behaviour_cloning` | `racing_driver` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [Damas](#run) | [●](ai_adversarial.pt-BR.md) |  |  | [○](ai_learning.pt-BR.md) |  |  |  |  |  |  |  |  |  | [●](learned_evaluation.pt-BR.md) |  |  |
| [A escaramuça (*skirmish*)](#demo-skirmish) |  |  |  | [◐](ai_learning.pt-BR.md) |  |  |  |  | [●](ai_search.pt-BR.md) |  |  |  |  |  |  |  |
| [Jogo da velha](#demo-tictactoe) |  |  |  |  |  |  |  |  |  |  |  |  | [●](menace.pt-BR.md) |  |  |  |
| [Quatro buscas](#demo-search) |  |  |  |  |  |  |  |  | [●](ai_search.pt-BR.md) |  |  |  |  |  |  |  |
| [*Stealth*](#demo-stealth) |  |  | [●](ai_fuzzy.pt-BR.md) |  |  | [●](ai_perception.pt-BR.md) |  |  | [●](ai_search.pt-BR.md) |  |  |  |  |  |  |  |
| [*Steering*](#demo-steering) |  |  |  |  |  |  |  |  |  | [●](ai_steering.pt-BR.md) |  |  |  |  |  |  |
| [Corrida](#demo-racing) |  |  |  |  |  |  |  |  |  | [●](ai_steering.pt-BR.md) |  |  |  |  |  | [●](racing_driver.pt-BR.md) |
| [Corrida em 3D](#demo-racing3d) |  |  |  |  |  |  |  |  |  | [●](ai_steering.pt-BR.md) |  |  |  |  |  | [●](racing_driver.pt-BR.md) |
| [Infiltração](#demo-infiltration) |  |  | [●](ai_fuzzy.pt-BR.md) |  |  | [●](ai_perception.pt-BR.md) |  |  | [●](ai_search.pt-BR.md) |  | [●](ai_teamwork.pt-BR.md) | [●](ai_utility.pt-BR.md) |  |  |  |  |
| [Partida de *bots*](#demo-botmatch) |  |  |  |  |  | [●](ai_perception.pt-BR.md) |  |  | [●](ai_search.pt-BR.md) |  | [●](ai_teamwork.pt-BR.md) | [●](ai_utility.pt-BR.md) |  |  |  |  |
| [Um guarda, quatro jeitos de decidir](#demo-behaviour) |  | [●](ai_behaviour.pt-BR.md) | [◐](ai_fuzzy.pt-BR.md) |  |  | [●](ai_perception.pt-BR.md) |  |  | [●](ai_search.pt-BR.md) |  |  |  |  |  |  |  |
| [Estratégia em tempo real](#demo-rts) |  | [●](ai_behaviour.pt-BR.md) |  |  |  |  | [●](ai_planning.pt-BR.md) | [●](ai_rts_core.pt-BR.md) |  |  |  |  |  |  |  |  |
| [Tática](#demo-tactical) |  | [●](ai_behaviour.pt-BR.md) |  | [●](ai_learning.pt-BR.md) |  |  | [●](ai_planning.pt-BR.md) |  |  |  |  |  |  |  |  |  |
| [Luta, modo treino](#demo-fighting) |  |  |  | [●](ai_learning.pt-BR.md) | [●](ai_opponent.pt-BR.md) |  |  |  |  |  |  |  |  |  | [●](behaviour_cloning.pt-BR.md) |  |

## Demo por demo {#by-demo}

- <a id="run"></a>**Damas**, `make run` -- parecido com damas, você contra o computador.
  - teclas: espaço faz a jogada das brancas; 1-6 até onde ela olha; E troca a avaliação pela aprendida.
  - técnicas: ● [ai_adversarial](ai_adversarial.pt-BR.md) (*minimax* com *alpha-beta*); ○ [ai_learning](ai_learning.pt-BR.md) (declarada no manifesto, nunca alcançada pela cena); ● [Avaliação aprendida](learned_evaluation.pt-BR.md) (uma avaliação aprendida).
- <a id="demo-skirmish"></a>**A escaramuça (*skirmish*)**, `make demo-skirmish` -- parecido com uma batalha pequena de Advance Wars.
  - teclas: espaço encerra o seu turno, e cada unidade azul diz então o que decidiu, e com que probabilidade.
  - técnicas: ◐ [ai_learning](ai_learning.pt-BR.md) (por `tactical`; uma regressão treinada no Python); ● [ai_search](ai_search.pt-BR.md) (A*).
- <a id="demo-tictactoe"></a>**Jogo da velha**, `make demo-tictactoe` -- parecido com jogo da velha, contra a máquina de caixas de fósforo de Michie.
  - teclas: espaço sorteia a conta do MENACE; 1-4 a idade dele; M o que o jogo perfeito faz de cada casa.
  - técnicas: ● [MENACE](menace.pt-BR.md) (as caixas de fósforo do MENACE).
  - escrito dentro do próprio exemplo: jogo perfeito por *minimax*.
- <a id="demo-search"></a>**Quatro buscas**, `make demo-search` -- parecido com o clicar-e-andar de qualquer jogo de estratégia, em câmera lenta, uma célula por vez.
  - teclas: 1-4 escolhem a busca; espaço mostra a próxima célula expandida; B o próximo tabuleiro.
  - técnicas: ● [ai_search](ai_search.pt-BR.md) (BFS, DFS, Dijkstra, A*).
- <a id="demo-stealth"></a>***Stealth***, `make demo-stealth` -- parecido com o *stealth* visto de cima do primeiro Metal Gear.
  - teclas: espaço espera, e o cone e a suspeita de cada guarda seguem mudando; D mostra o mapa de perigo.
  - técnicas: ● [ai_fuzzy](ai_fuzzy.pt-BR.md) (lógica *fuzzy*); ● [ai_perception](ai_perception.pt-BR.md) (cone de visão com linha de visão e audição, mapa de influência); ● [ai_search](ai_search.pt-BR.md) (A*).
- <a id="demo-steering"></a>***Steering***, `make demo-steering` -- parecido com os inimigos de um jogo de ação perseguindo e parando, uma força por vez.
  - teclas: o clique move um alvo; espaço pausa; . um passo.
  - técnicas: ● [ai_steering](ai_steering.pt-BR.md) (*seek*, *arrive*, *pursue*, *avoid*).
- <a id="demo-racing"></a>**Corrida**, `make demo-racing` -- parecido com Micro Machines, visto de cima, a IA no mesmo carro que o seu.
  - teclas: 1-3 o nível da IA; Tab assiste às três IAs correndo.
  - técnicas: ● [ai_steering](ai_steering.pt-BR.md) (*seek*); ● [O piloto de corrida](racing_driver.pt-BR.md) (*pure pursuit*, perfil de velocidade).
- <a id="demo-racing3d"></a>**Corrida em 3D**, `make demo-racing3d` -- parecido com Gran Turismo, com pneus que derrapam.
  - teclas: 1 PID, 2 *heat line*, 3 aderência medida -- cada um liga ou desliga; Tab assiste ao próximo carro.
  - técnicas: ● [ai_steering](ai_steering.pt-BR.md) (controlador PID, *heat line*); ● [O piloto de corrida](racing_driver.pt-BR.md) (perfil de velocidade, *pure pursuit*).
  - escrito dentro do próprio exemplo: aderência medida.
- <a id="demo-infiltration"></a>**Infiltração**, `make demo-infiltration` -- parecido com Metal Gear Solid, em terceira pessoa.
  - teclas: 1-5 ligam e desligam cada parte do raciocínio dos guardas; Tab segue o próximo guarda.
  - técnicas: ● [ai_fuzzy](ai_fuzzy.pt-BR.md) (lógica *fuzzy*); ● [ai_perception](ai_perception.pt-BR.md) (forma da visão com luz e audição, *awareness*, mapa de crença); ● [ai_search](ai_search.pt-BR.md) (A*); ● [ai_teamwork](ai_teamwork.pt-BR.md) (uma busca dividida, árbitro de papéis); ● [ai_utility](ai_utility.pt-BR.md) (ações pesadas por *utility*).
- <a id="demo-botmatch"></a>**Partida de *bots***, `make demo-botmatch` -- parecido com uma partida contra *bots* em Unreal Tournament ou Counter-Strike.
  - teclas: 1-3 a marcação de posições, o comandante e o recuo do azul; Tab um *bot*; T assume o controle dele; M o mapa.
  - técnicas: ● [ai_perception](ai_perception.pt-BR.md); ● [ai_search](ai_search.pt-BR.md) (A*); ● [ai_teamwork](ai_teamwork.pt-BR.md) (posições táticas com marcação, comandante do time sobre a influência, confiança do esquadrão e recuo em ondas); ● [ai_utility](ai_utility.pt-BR.md) (ações pesadas por *utility*).
- <a id="demo-behaviour"></a>**Um guarda, quatro jeitos de decidir**, `make demo-behaviour` -- parecido com um guarda fazendo a ronda, como em Metal Gear ou Thief.
  - teclas: 1-4 trocam a máquina de estados, a *behaviour tree*, GOAP e HTN no meio da ronda; espaço um turno.
  - técnicas: ● [ai_behaviour](ai_behaviour.pt-BR.md) (máquina de estados, *behaviour tree*, GOAP, HTN); ◐ [ai_fuzzy](ai_fuzzy.pt-BR.md) (por `stealth`); ● [ai_perception](ai_perception.pt-BR.md); ● [ai_search](ai_search.pt-BR.md).
- <a id="demo-rts"></a>**Estratégia em tempo real**, `make demo-rts` -- parecido com StarCraft ou Age of Empires, contra um comandante que planeja.
  - teclas: V assiste a dois computadores; H o planejador; I o mapa de influência; F tira a névoa.
  - técnicas: ● [ai_behaviour](ai_behaviour.pt-BR.md) (HTN, máquina de estados); ● [ai_planning](ai_planning.pt-BR.md) (STRIPS sobre PDDL); ● [ai_rts_core](ai_rts_core.pt-BR.md) (*flow fields*).
  - escrito dentro do próprio exemplo: fila de prioridade de desejos, *utility* por região, mapa de influência.
- <a id="demo-tactical"></a>**Tática**, `make demo-tactical` -- parecido com Advance Wars.
  - teclas: C troca o computador, cuja próxima decisão aparece em rosa antes de o espaço jogá-la; S troca de lado.
  - técnicas: ● [ai_behaviour](ai_behaviour.pt-BR.md) (máquina de estados, *behaviour tree*, GOAP, HTN); ● [ai_learning](ai_learning.pt-BR.md) (uma regressão treinada no Python); ● [ai_planning](ai_planning.pt-BR.md) (STRIPS sobre PDDL).
  - escrito dentro do próprio exemplo: regras escritas à mão, *lookahead* com chances exatas, mapa de influência.
- <a id="demo-fighting"></a>**Luta, modo treino**, `make demo-fighting` -- parecido com o modo treino de Street Fighter, contra um boneco que aprende o seu jeito de jogar.
  - teclas: M troca o modo do boneco; espaço um quadro; P pausa.
  - técnicas: ● [ai_learning](ai_learning.pt-BR.md) (a consulta de casos do *ghost*); ● [ai_opponent](ai_opponent.pt-BR.md) (*n-gram*); ● [Behaviour cloning](behaviour_cloning.pt-BR.md) (*behaviour cloning*).
  - escrito dentro do próprio exemplo: regras escritas à mão, atraso de reação.

## Técnica por técnica {#by-technique}

- <a id="ai_adversarial"></a>[ai_adversarial](ai_adversarial.pt-BR.md) -- a melhor jogada contra quem responde. Veja em: ● [`make run`](#run) (*minimax* com *alpha-beta*).
- <a id="ai_behaviour"></a>[ai_behaviour](ai_behaviour.pt-BR.md) -- o que fazer em seguida. Veja em: ● [`make demo-behaviour`](#demo-behaviour) (máquina de estados, *behaviour tree*, GOAP, HTN); ● [`make demo-rts`](#demo-rts) (HTN, máquina de estados); ● [`make demo-tactical`](#demo-tactical) (máquina de estados, *behaviour tree*, GOAP, HTN).
- <a id="ai_fuzzy"></a>[ai_fuzzy](ai_fuzzy.pt-BR.md) -- quanto, aos poucos. Veja em: ● [`make demo-stealth`](#demo-stealth) (lógica *fuzzy*); ● [`make demo-infiltration`](#demo-infiltration) (lógica *fuzzy*); ◐ [`make demo-behaviour`](#demo-behaviour) (por `stealth`).
- <a id="ai_learning"></a>[ai_learning](ai_learning.pt-BR.md) -- usando o que o Python aprendeu. Veja em: ○ [`make run`](#run) (declarada no manifesto, nunca alcançada pela cena); ◐ [`make demo-skirmish`](#demo-skirmish) (por `tactical`; uma regressão treinada no Python); ● [`make demo-tactical`](#demo-tactical) (uma regressão treinada no Python); ● [`make demo-fighting`](#demo-fighting) (a consulta de casos do *ghost*).
- <a id="ai_opponent"></a>[ai_opponent](ai_opponent.pt-BR.md) -- o que o jogador vai fazer agora? Veja em: ● [`make demo-fighting`](#demo-fighting) (*n-gram*).
- <a id="ai_perception"></a>[ai_perception](ai_perception.pt-BR.md) -- o que um guarda vê, ouve e acredita. Veja em: ● [`make demo-stealth`](#demo-stealth) (cone de visão com linha de visão e audição, mapa de influência); ● [`make demo-infiltration`](#demo-infiltration) (forma da visão com luz e audição, *awareness*, mapa de crença); ● [`make demo-botmatch`](#demo-botmatch); ● [`make demo-behaviour`](#demo-behaviour).
- <a id="ai_planning"></a>[ai_planning](ai_planning.pt-BR.md) -- os passos até um objetivo que ninguém escreveu. Veja em: ● [`make demo-rts`](#demo-rts) (STRIPS sobre PDDL); ● [`make demo-tactical`](#demo-tactical) (STRIPS sobre PDDL).
- <a id="ai_rts_core"></a>[ai_rts_core](ai_rts_core.pt-BR.md) -- muitas unidades, um quadro. Veja em: ● [`make demo-rts`](#demo-rts) (*flow fields*).
- <a id="ai_search"></a>[ai_search](ai_search.pt-BR.md) -- achar um caminho. Veja em: ● [`make demo-skirmish`](#demo-skirmish) (A*); ● [`make demo-search`](#demo-search) (BFS, DFS, Dijkstra, A*); ● [`make demo-stealth`](#demo-stealth) (A*); ● [`make demo-infiltration`](#demo-infiltration) (A*); ● [`make demo-botmatch`](#demo-botmatch) (A*); ● [`make demo-behaviour`](#demo-behaviour).
- <a id="ai_steering"></a>[ai_steering](ai_steering.pt-BR.md) -- para que lado empurrar, e com que força. Veja em: ● [`make demo-steering`](#demo-steering) (*seek*, *arrive*, *pursue*, *avoid*); ● [`make demo-racing`](#demo-racing) (*seek*); ● [`make demo-racing3d`](#demo-racing3d) (controlador PID, *heat line*).
- <a id="ai_teamwork"></a>[ai_teamwork](ai_teamwork.pt-BR.md) -- um time que divide o trabalho. Veja em: ● [`make demo-infiltration`](#demo-infiltration) (uma busca dividida, árbitro de papéis); ● [`make demo-botmatch`](#demo-botmatch) (posições táticas com marcação, comandante do time sobre a influência, confiança do esquadrão e recuo em ondas).
- <a id="ai_utility"></a>[ai_utility](ai_utility.pt-BR.md) -- pesar todas as opções de uma vez. Veja em: ● [`make demo-infiltration`](#demo-infiltration) (ações pesadas por *utility*); ● [`make demo-botmatch`](#demo-botmatch) (ações pesadas por *utility*).
- <a id="menace"></a>[MENACE](menace.pt-BR.md) -- a máquina de caixas de fósforo que aprende jogo da velha. Veja em: ● [`make demo-tictactoe`](#demo-tictactoe) (as caixas de fósforo do MENACE).
- <a id="learned_evaluation"></a>[Avaliação aprendida](learned_evaluation.pt-BR.md) -- dar nota a uma posição com pesos ajustados aos resultados. Veja em: ● [`make run`](#run) (uma avaliação aprendida).
- <a id="behaviour_cloning"></a>[Behaviour cloning](behaviour_cloning.pt-BR.md) -- o lutador que joga como você. Veja em: ● [`make demo-fighting`](#demo-fighting) (*behaviour cloning*).
- <a id="racing_driver"></a>[O piloto de corrida](racing_driver.pt-BR.md) -- um ponto à frente, um perfil de velocidade, sem *rubber band*. Veja em: ● [`make demo-racing`](#demo-racing) (*pure pursuit*, perfil de velocidade); ● [`make demo-racing3d`](#demo-racing3d) (perfil de velocidade, *pure pursuit*).

## Como as marcas são medidas {#how}

Uma marca é medida, não escrita. O catálogo parte das técnicas que o manifesto da demo declara (`depends_on` em `modules/<exemplo>.json`, direto ou por outro exemplo que ela usa) e segue o código a partir da cena que o alvo do `make` abre, arquivo por arquivo, com a regra que o `check_demos.py` aplica aos cartões do menu: uma classe conta quando o código a constrói, a chama ou a estende, e um caminho `res://` quando nomeia um script ou uma cena. Comentários, *strings*, anotações de tipo e leituras de constante não contam, e os testes ficam de fora:

- ● o código da própria demo alcança a técnica;
- ◐ só o código de outro exemplo a alcança, e a linha diz qual;
- ○ o manifesto da demo a declara e nada que a cena alcança a usa: a dependência é de um código que a demo não roda -- o Python que a treina, ou um arquivo que a cena nunca carrega.

Os algoritmos vêm do cartão da demo no menu (`godot/menu/catalogue.json`): cada um fica sob a técnica cujo código tem a classe que o cartão dá como evidência, ou sob *escrito dentro do próprio exemplo* quando essa classe é do exemplo.

O que uma leitura não vê: um script carregado de um caminho montado durante a execução, e se um ramo que usa uma classe chega a ser tomado. Abrir a demo é a verificação das duas coisas.

Uma técnica que vive no Python e numa demo, e não num *addon* (`non_module_techniques.json`), recebe ● nas demos que esse arquivo cita, e `make lint-catalogue` falha quando a cena de uma delas não alcança nenhum dos scripts Godot da técnica. O jogo conhecido, as teclas e os nomes curtos dos algoritmos vêm de `games.json`, a única entrada escrita à mão, e as teclas são conferidas com a linha de `make help` de cada alvo.
