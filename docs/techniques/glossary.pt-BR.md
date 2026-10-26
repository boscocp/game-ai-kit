# Glossário: os termos que ficam em inglês

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 0
source: book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 ; book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020
invalidated_if: a technique page in pt-BR translates a term this list says stays in English, or a new technique brings a term missing here
teaches: none
-->

Desenvolvedores brasileiros de jogos falam de IA metade em inglês: ninguém
diz "busca de caminho" numa conversa sobre *pathfinding*. As páginas em
português deste kit seguem esse uso. Os termos abaixo ficam em inglês, em
itálico na primeira vez que aparecem numa página, e esta lista diz o que cada
um quer dizer. Ela vale para as páginas de técnica (T74, T75) e para os
textos dos jogos (T78).

Os nomes no código -- classes, métodos, campos -- nunca são traduzidos: são o
que você vai digitar. Nem os comentários e as *docstrings* do código: o
código fica em inglês, e só a documentação é traduzida. Um termo no plural
(*features*, *bots*) está aqui no singular; títulos de livros e de artigos,
também em itálico, ficam como foram publicados.

## Termos {#terms}

| termo | o que é |
|---|---|
| *pathfinding* | achar um caminho de um ponto a outro num mapa ou grafo |
| A\* | a busca que soma o custo já pago a uma estimativa do que falta; lê-se "A estrela" |
| *breadth-first* / *depth-first* | busca em largura / em profundidade; os nomes em português também são comuns, e as páginas dão os dois |
| *frontier* (fronteira) | o que a busca já viu e ainda não expandiu; traduzido, pois "fronteira" é o termo dos livros em português |
| *heuristic* (heurística) | o palpite do A\* sobre o que falta; traduzido, pelo mesmo motivo |
| *steering* | decidir para que lado empurrar um veículo agora, e com que força |
| *seek*, *arrive*, *pursue*, *avoid* | os comportamentos de *steering* de Reynolds; ficam em inglês porque são os nomes das classes e dos artigos |
| *flow field* | um campo que diz, em cada célula, para que lado ir até o objetivo |
| *heat line* | o "calor" de Melder ao longo da largura da pista, para escolher onde ficar |
| PID | controlador proporcional, integral e derivativo |
| *behaviour tree* | árvore de comportamento; fica em inglês porque é assim que a indústria fala |
| *state machine* (máquina de estados) | traduzido: o termo em português é o de uso comum |
| GOAP | *Goal-Oriented Action Planning*, o planejador do F.E.A.R. |
| HTN | *Hierarchical Task Network*, rede hierárquica de tarefas |
| STRIPS | o planejador clássico, de Fikes e Nilsson |
| *tick* | uma vez em que a IA é consultada; um quadro, um turno |
| *waypoint* | um ponto de passagem num mapa |
| *gate* | um comando com código de saída que impede um erro de entrar no repositório |
| *addon* | uma pasta em `godot/addons/` que você copia para o seu projeto |
| *minimax*, *alpha-beta* | a busca dos jogos de dois jogadores, e o seu corte |
| *fuzzy* | lógica *fuzzy* (nebulosa): verdade em graus, não só sim ou não |
| *behaviour cloning* | aprender a jogar copiando partidas gravadas de uma pessoa |
| *ply* (*plies*) | a jogada de um só jogador; duas fazem uma rodada. É a unidade de profundidade do *minimax* |
| *expectiminimax* | o *minimax* com nós de sorte, para jogos com dados |
| *n-gram* | uma tabela do que veio depois de cada sequência curta de ações |
| *prior*, *decay* | as contagens imaginárias com que toda ação começa, e o quanto uma contagem antiga pesa diante de uma nova |
| *feature* | um número (ou uma palavra) medido do jogo que um modelo lê; os textos brasileiros de aprendizado de máquina dizem também "característica" ou "atributo", e o kit fica com *feature*, que é o nome no código |
| *bias* | o termo constante de um modelo linear, o `b` de `w·x + b` |
| *self-play* | o programa jogando contra si mesmo para gerar partidas |
| *ghost*, *clone* | os dois adversários do *behaviour cloning*: a tabela consultada e o modelo ajustado |
| *utility* | dar nota a todas as ações de uma vez e ficar com a maior; "IA de *utility*" é o nome corrente |
| *bot* | um jogador controlado pela IA num jogo de tiro |
| *stealth* | o gênero de jogos de infiltração, em que o jogador evita ser visto |
| *awareness* | o quanto um guarda está atento a um estímulo, de calmo a alerta |
| *raycast* | um raio lançado pela física da *engine* para saber se algo está no caminho |
| *engine* | o motor do jogo, aqui o Godot |
| *designer* | quem desenha o jogo e ajusta os números; "projetista" quase não se usa |
| *spatial hash*, *quadtree* | duas formas de achar quem está perto de um ponto sem perguntar a todo mundo |
| *frame budget* | quanto de um quadro cada parte do jogo pode ocupar |
| *pure pursuit* | perseguir um ponto a uma distância fixa à frente no caminho |
| *lookahead* | a distância à frente para onde o piloto mira |
| *rubber band* | a trapaça de acelerar o carro que ficou para trás; o piloto deste kit não usa |
| *string*, *array* | os tipos de texto e de lista; ficam em inglês como no código |
| *docstring* | o comentário de documentação de uma função ou classe, o `##` do GDScript |
| *softmax* | a função que transforma as notas de várias respostas em probabilidades que somam 1 |
| *shadow* | o adversário de Killer Instinct treinado com as lutas do próprio jogador; as *Shadows* do jogo |
| *baked* | pré-calculado: os pontos que o Godot calcula uma vez ao longo de uma curva |
| *skirmish* | a escaramuça: a demo por turnos em que o azul é a política aprendida |
| *easy*, *medium*, *hard* | os nomes dos níveis de dificuldade como aparecem na tela das demos |
| *wave* | uma rodada de trabalho neste repositório: um ramo, uma revisão, uma junção ao principal |
