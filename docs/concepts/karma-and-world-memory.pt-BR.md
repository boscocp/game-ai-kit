# Como os jogos se lembram do que o jogador fez: carma e memória do mundo

<!-- doc-meta
half_life: concept
verified_on: 2026-11-11
tier: 1
source: https://en.wikipedia.org/wiki/Ultima_IV:_Quest_of_the_Avatar
invalidated_if: a página em inglês muda, ou a ADR 0025 muda o que pode persistir entre sessões
teaches: karma-and-world-memory
-->

> Tradução de [karma-and-world-memory.md](karma-and-world-memory.md). Os
> termos que ficam em inglês estão no [glossário](../techniques/glossary.pt-BR.md).

> Um jogo que se lembra do que o jogador fez precisa decidir duas coisas:
> o que guarda, e o que lê daquilo que guardou. Esta página lê como nove
> jogos lançados responderam, e um sistema de pesquisa, e depois diz o que
> o exemplo do vale toma deles (ADR 0025, T164-T165). Cada jogo é citado
> pelo que o seu artigo dizia quando foi lido em 2026-11-11, e só isso; o
> que não pôde ser conferido está listado no fim e não é usado.

## A versão curta {#short}

- **A maioria dos jogos guarda um número sobre o jogador.** Pontos de bem
  e de mal, lado da luz e lado sombrio, uma reputação: um número, ou
  poucos, movidos pelo que o jogador faz, lidos pelas pessoas que ele
  encontra.
- **Alguns guardam o mundo.** Um celeiro queimado continua queimado; uma
  história é escrita em frases. O próprio mundo é a memória, e o jogador
  lê o mundo em vez de um medidor.
- **O vale faz a segunda coisa, e deriva a primeira.** Guarda só os
  feitos, como `{day, verb, place}`. O mundo de qualquer dia e a reputação
  do jogador (a `Standing` do código) são reconstruídos a partir deles a cada
  sessão, por regras e pesos que um designer escreveu. Nada derivado é
  salvo.
- **O que é recusado:** um número ajustado ao jogador, uma memória sobre
  uma pessoa, e qualquer coisa que torne o jogo mais difícil por causa do
  que o jogador fez. A reputação define consequências -- um preço, uma
  porta, um cumprimento -- nunca um desafio.

## Um medidor sobre o jogador {#meter}

- **Ultima IV** (1985) fez do caráter do jogador o seu assunto. O jogo
  abre com dilemas éticos, e as respostas ordenam as oito virtudes. Depois,
  as ações sobem e descem cada virtude: pagar de menos a um mercador marca
  o jogador como desonesto, fugir de uma batalha baixa a coragem, esmola
  a mendigos sobe o sacrifício; e "a virtude afeta como os NPCs interagem
  com o jogador" [Ultima IV].
- **Fable** (2004) divide em pontos de bem e de mal. Salvar aldeões é bom,
  matar inocentes é mau, e até a comida conta. O alinhamento muda a
  aparência do herói -- uma auréola, ou chifres -- e "afeta como os
  personagens não jogáveis respondem"; o renome e a roupa decidem se o
  povo o elogia ou o teme [Fable].
- **Star Wars: Knights of the Old Republic** (2003) acompanha "ações e
  falas, das pequenas escolhas de palavras às grandes decisões da trama"
  rumo ao lado da luz ou ao sombrio, e o lado decide o final [KOTOR].
- **Fallout** (1997) chama de reputação: conforme o jogador conclui as
  missões, ganha ou perde pontos de reputação, "que determinam como os
  outros o tratam" [Fallout].
- **Elite** (1984) guarda o registro mais simples de todos, uma
  classificação de combate, e o jogo leva o nome do posto mais alto
  [Elite].

Todos esses guardam um valor sobre o jogador. As pessoas que ele
encontra leem o valor; ninguém consegue dizer, só pelo valor, qual feito
o pôs ali.

## Uma memória que esquece de propósito {#forgets}

- **Grand Theft Auto III** (2001) guarda um nível de procurado, até seis
  estrelas, que sobe com os crimes. É uma memória feita para sumir: fora
  da vista dos policiais o medidor "recua aos poucos", e um suborno tira
  uma estrela [GTA III].
- **Hades** (2020) é o caso oposto. O jogador morre e recomeça, e o mundo
  se lembra da tentativa: os diálogos "avançam a cada tentativa", e o
  jogador pode melhorar a sua relação com os personagens do Submundo
  entre uma morte e outra [Hades].

Os dois mostram que o que um jogo guarda é uma escolha de design, não uma
consequência de ter um arquivo salvo: GTA esquece o que um save poderia
guardar; Hades se lembra através do que parece um recomeço.

## O mundo como memória {#world}

- **Dwarf Fortress** (2006) guarda mundos. Um mundo é gerado com anos de
  história, e persiste: se a fortaleza é aposentada ou a colônia é
  destruída, o mundo continua. O modo Legends registra o que os
  personagens fizeram em frases -- mortes, alianças, rivalidades -- e os
  feitos das fortalezas do jogador entram nesses registros [Dwarf
  Fortress]. É o parente lançado mais próximo do vale: um registro de
  feitos, legível como tal.
- **RimWorld** (2018) mostra o que o vale recusa. O seu contador de
  histórias "gera eventos proceduralmente e define a dificuldade",
  escolhendo-os pela leitura que faz da situação do jogador [RimWorld].
  É uma leitura do jogador transformada em desafio -- exatamente o que a
  ADR 0025 proíbe à reputação, e por que o vale não tem dificuldade
  nenhuma.

## O que a pesquisa acrescenta {#research}

- **Talk of the Town** (Ryan e colegas, 2015) é o jogo para o qual um
  framework de pesquisa foi construído: personagens não jogáveis que
  observam e formam conhecimento sobre o mundo, o passam a outros
  personagens, se lembram errado, esquecem, e mentem. Ele parte de um
  defeito que nomeia: personagens numa parte do mundo que parecem saber o
  que o jogador fez em outra antes que a notícia pudesse ter chegado
  [Ryan et al.]. A memória ali pertence às pessoas, e pode estar errada.

O vale não faz isso, de propósito: nenhum aldeão guarda nada, e nenhum lê
outro. Essa é a linha entre este exemplo e Talk of the Town, e o caso em
"Quando não usar", abaixo.

## O que o kit toma {#kit}

- **Guardar os feitos, não o jogador** (ADR 0025). Um feito é `{day, verb,
  place}`; o esquema não tem campo para uma pessoa, então o registro não
  pode virar um diário do que o jogador fez a quem. O save é o registro e
  nada mais: `ValleySave`, `user://valley/deeds.json`.
- **Reconstruir o mundo, como Dwarf Fortress o guarda.** `ValleyRules`
  reaplica o registro sobre regras noturnas escritas por um designer: um
  celeiro queimado deixa o mercado sem pão no dia seguinte. Cada fato
  guarda o motivo que o mudou por último, e a tela pode dizer qual feito
  está por trás dele.
- **Derivar o medidor, como Ultima IV o lê.** `Standing` soma pesos fixos
  sobre os feitos, em cuidado e medo. Dois jogadores que fizeram os mesmos
  feitos têm a mesma reputação, como quer que tenham jogado.
- **Deixar poucos lerem, nunca os aldeões.** Três pessoas com um jeito
  fixo (`VillagerManner`) leem a reputação e definem um preço, uma porta e
  um cumprimento -- o povo de Fable, escrito como dados. Os aldeões
  planejam o dia só a partir dos fatos do mundo (`ValleyVillager`): quando
  a ponte cai, assam o próprio pão porque o mercado ficou fora de
  alcance, não porque sabem quem a derrubou.
- **Um feito que não muda nada não é guardado**, ou o jogador ganharia
  reputação fechando uma porteira já fechada todo dia.
- **Apagar é um botão.** O registro é a única coisa guardada, então
  removê-lo devolve o vale ao primeiro dia.

## Quando não usar {#when-not}

- **Quando a memória é o que as pessoas acreditam, não o que aconteceu.**
  Uma cidade onde a fofoca se espalha, é lembrada errado e mente -- o tema
  de Talk of the Town -- precisa de memórias que pertencem aos personagens
  e podem estar erradas. Um registro de feitos é verdadeiro por construção
  e não pertence a ninguém.
- **Quando o registro cresceria sem fim.** Reconstruir o dia n repete n
  noites. Um jogo jogado por milhares de dias precisa de um checkpoint do
  mundo, que é estado derivado em disco -- o que a ADR 0025 recusa --,
  então precisa de outro design.
- **Quando o objetivo é o jogo se adaptar ao jogador.** Um contador de
  histórias que lê o jogador e define o desafio é outra técnica, e o kit a
  mantém à parte (as regras N9, N13 e N14 da ADR 0016: contadas durante
  uma luta, nunca salvas).

## Não conferido {#unchecked}

Citados no levantamento e não usados acima, porque as páginas lidas em
2026-11-11 não diziam isso:

- O status legal de Elite (limpo, infrator, fugitivo) e a resposta da
  polícia a ele: o artigo lido só cobre a classificação de combate.
- O carma de Fallout como número separado da reputação: o artigo lido só
  fala em pontos de reputação.
- As memórias de eventos dos colonos de RimWorld: o artigo lido descreve
  humor e relações, não memórias.

## Fontes {#sources}

- [Ultima IV] https://en.wikipedia.org/wiki/Ultima_IV:_Quest_of_the_Avatar
- [Fable] https://en.wikipedia.org/wiki/Fable_(2004_video_game)
- [KOTOR] https://en.wikipedia.org/wiki/Star_Wars:_Knights_of_the_Old_Republic
- [Fallout] https://en.wikipedia.org/wiki/Fallout_(video_game)
- [Elite] https://en.wikipedia.org/wiki/Elite_(video_game)
- [GTA III] https://en.wikipedia.org/wiki/Grand_Theft_Auto_III
- [Hades] https://en.wikipedia.org/wiki/Hades_(video_game)
- [RimWorld] https://en.wikipedia.org/wiki/RimWorld
- [Dwarf Fortress] https://en.wikipedia.org/wiki/Dwarf_Fortress
- [Ryan et al.] J. O. Ryan, A. Summerville, M. Mateas, N. Wardrip-Fruin,
  "Toward Characters Who Observe, Tell, Misremember, and Lie",
  Experimental AI in Games, AIIDE 2015 Workshop:
  https://cdn.aaai.org/ojs/12825/12825-52-16341-1-2-20201228.pdf
- O exemplo: [o vale](../godot/valley.md); a regra:
  [ADR 0025](../adr/0025-a-save-is-a-record-of-deeds.md).
