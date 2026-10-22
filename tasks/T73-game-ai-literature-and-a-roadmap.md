# T73 — The game-AI literature against this kit, and a roadmap

Size: M · Prereqs: T58 · Files: `docs/concepts/the-literature-and-the-kit.md`, `scripts/check_literature_table.py`, `Makefile`, `tasks/`

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

This runs in parallel with everything else: it writes a page, its gate
and task files, and changes no game or addon code.

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
   second use would show about its interface. Each entry also names the
   invariants it touches: **6** (no training at game time -- player
   modelling and difficulty that adapts are exactly that, and ADR 0016's
   count-during-one-fight is the only exception the owner has made) and
   **7** (the LLM never blocks a frame and its output passes a validator --
   `ai_llm`, and any LLM agent). Candidates the research
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
   planted row naming a missing addon must fail. `scripts/check_literature_table.py`
   with `--self-test`, exit codes 0/1/2.
7. **Wire the gate in**: a `Makefile` target, in `make check`, and its
   self-test in `make lint-selftests` (`scripts/run_selftests.py`).

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

## Done in wave 81 (2026-10-22)

`docs/concepts/the-literature-and-the-kit.md`: 43 techniques in seven
tables, each against the kit -- a module, a path or `not in the kit`, the
demo's make target, the tier. Sources, all opened on 2026-10-22 and each
saying how much was read: AIMA 4th ed.'s full contents with section
titles; Yannakakis & Togelius 2nd ed.'s contents; Millington 3rd ed.'s
chapter titles; the Game AI Pro index; and fifteen chapters, slides and
papers by their opening pages (Booth's Left 4 Dead slides in part).
Buckland's book, the AI Game Programming Wisdom series, Isla's Halo 2
paper and Mark's GDC 2015 talk could not be opened and are listed under
"Could not be checked", not used.

What it found: the decision layer is well covered and AIMA's part IV is
not (MCTS, CSP, filters, MDPs, bandits); nothing teaches content
generation or pacing; `ai_teamwork`, `ai_opponent`, `ai_adversarial` and
`ai_rts_core` are each shown in one game only. The roadmap has eight new
techniques and six "second game" entries, each with its tier, size and
the invariants it touches -- bandits and player modelling fall squarely
under invariant 6, `ai_llm` under 7. It ends with seven questions for the
owner, in Portuguese and English; the follow-up tasks are written after
the answers, as step 5 says.

`scripts/check_literature_table.py` (`make lint-literature`, in `make
check` through `check-no-engine`, its self-test found by
`lint-selftests`): rules L1-L5, six self-test cases -- no table, a cell
that names nothing, a missing addon, a missing path, a missing demo, an
empty directory (exit 2). On its first run it caught the page itself:
the planned `ai_llm`, written in backticks as if it were a module.
