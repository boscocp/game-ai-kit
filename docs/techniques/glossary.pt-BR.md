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
que você vai digitar.

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
