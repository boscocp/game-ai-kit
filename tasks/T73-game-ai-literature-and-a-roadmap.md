# T73 — The game-AI literature against this kit, and a roadmap

Size: M · Prereqs: T58 · Files: `docs/concepts/the-literature-and-the-kit.md`, `tasks/`

## Goal

The owner, 2026-10-22, in their words: "tbm quero em paralelo uma tarefa pra
listar todos os modelos que temos no AIMA e outras fontes da literatura
focadas em IA pra jogos de boa reputação e mercado. comparando as que ja
temos aqui. pra montar um roadmap de aplicar e ver se podemos adicionar nas
demos já existentes, ou se precisamos de mais variedades de demos com
diferentes jogos seja pra testar os novos modelos ou pra testar e
aperfeicoar a generalizacao e modularidade da lib e modelos de IA aqui
presente."

So: one page that lists the techniques of the field's standard sources,
says for each whether the kit has it (which addon or module, which demo,
which tier), and a roadmap the owner chooses from. Two kinds of roadmap
entry, kept apart:

- **a technique the kit does not have**, and the demo it belongs in --
  an existing one, or a new game where it would actually decide something;
- **a technique the kit has, in a second game**, to test the claim T58 to
  T63 made: that an addon is a module any game can configure. A technique
  shown in one game only is not yet shown to be general. Today
  `ai_teamwork` is used by the bot match alone, `ai_fuzzy` by the stealth
  hall alone, `ai_opponent` by the fighting game alone (from `modules/*.json`).

This runs in parallel with everything else: it writes a page and task
files, and changes no code.

## Steps

1. **The house rule for sources** (`docs/concepts/*`): a source is cited
   only if it was opened; a source read in part says which part; a figure
   that cannot be sourced is not given. A book that cannot be opened is
   listed by its table of contents as published, and said so.
2. **The sources**, at least:
   - Russell & Norvig, *Artificial Intelligence: A Modern Approach*, 4th
     ed. -- by chapter: agents and environments; uninformed and informed
     search, local search; adversarial search and MCTS; constraint
     satisfaction; logic and knowledge representation; classical planning,
     HTN; probabilistic reasoning, Bayesian networks, HMMs, Kalman and
     particle filters; decision theory, utility, MDPs and POMDPs;
     reinforcement learning; supervised learning and neural networks;
     multiagent systems and game theory; natural language and LLMs;
     robotics where it touches motion.
   - Millington, *AI for Games* (3rd ed.); Buckland, *Programming Game AI
     by Example*; the *AI Game Programming Wisdom* series; Rabin (ed.),
     *Game AI Pro* 1-3 and *Game AI Pro 360*; Yannakakis & Togelius,
     *Artificial Intelligence and Games* (2nd ed.).
   - Named industry practice: Orkin's GOAP (F.E.A.R.); HTN in Killzone and
     Horizon Zero Dawn; utility AI and infinite-axis utility (Dave Mark,
     GDC); behaviour trees (Isla, Champandard); influence maps and
     tactical positions; MCTS in games; procedural content generation;
     player modelling and dynamic difficulty; director AI (Left 4 Dead);
     LLM agents in games. GDC AI Summit talks where they are freely watchable.
   - The kit's own pages already researched: `racing-ai.md`,
     `shooter-ai.md`, `stealth-ai.md`, `rts-ai.md`, `fighting-game-ai.md`,
     `planning-in-strategy-games.md` -- reused, not redone.
3. **The table**: one row per technique -- the technique, where the
   literature puts it (source and chapter), the kind of game it is known
   for, and the kit's state: an addon and module (`modules/*.json`), the
   demos that use it, its tier (README), or "not in the kit". A row the kit
   has must name a real module or file -- step 6's gate holds that.
4. **The roadmap**, as a ranked list the owner decides, each entry with:
   what it teaches that the kit does not yet; where it goes (an existing
   demo, or a new game -- and which known game, the owner's rule of
   building on games people already know); the tier it needs; its size;
   and for "a second game" entries, which addon is reused and what the
   second use would show about its interface. Candidates the research
   should at least weigh: MCTS (a board game or the tactical game),
   utility AI as its own addon, influence maps shared by the RTS and the
   bot match, a director that paces a level, Bayesian or particle-filter
   tracking of an unseen player (stealth, T69/T70), MDP/value iteration on
   a small grid game, CSP or WFC level generation, `ai_llm` (invariant 7,
   still unwritten), player modelling for difficulty.
5. **Task files** for the entries the owner picks -- not before: the page
   ends with the questions the owner must answer, and the follow-up tasks
   are written after the answers, numbered then.
6. **A gate on the table**: every row that names a module or a path must
   name one that exists, so the page cannot claim what the kit lost. A
   planted row naming a missing addon must fail.

## Acceptance

```bash
python3 scripts/check_doc_freshness.py
python3 scripts/check_literature_table.py
python3 scripts/check_literature_table.py --self-test
make lint-tasks lint-status
```

## Manual check

The owner reads the roadmap and picks the entries; the follow-up tasks are
written from those answers. Does each row the kit claims to have match what
the demo shows?
