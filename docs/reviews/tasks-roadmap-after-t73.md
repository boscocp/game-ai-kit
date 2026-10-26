# Review: tasks/roadmap-after-t73

A fresh context reviewed PR #34 at `d28347f`: the task files written from
the owner's answers of 2026-10-26 to T73's seven questions, the
amendment to ADR 0016, the STATUS rows and the note on
`docs/concepts/the-literature-and-the-kit.md`. It ran the task, status,
link, freshness, translation and literature lints, all green, and
checked the citations against their sources: Roelofs (GAP3 ch. 28), the
Pac-Man Dossier, Booth's *Left 4 Dead* slides, llama.cpp's grammars
README and Façade's language paper all say what the tasks quote.

**Verdict: fix before merge** -- one blocker and thirteen should-fixes,
all applied on the branch after rebasing on `5a09376`.

## Findings, and what was done

**B1 (blocker): T84 and T85 built a new game and called it a mode.** Its
own menu card, `make demo-squad`, its own scene, pieces, combat and
roster; it shared only the `board` kernel. The owner chose "a mode of the
tactical game, not a new game". *Done*: the code was read
(`board_state.gd`, `tactical.gd`, `tactical_combat.gd`,
`tactical_rules.gd`, `tactical_turn.gd`, `tactical_roster.gd`) and an
honest mode is feasible without changing `board`:

- `BoardState`, `Unit`, `UnitType`, `Move`, `Attack`, the tactical map
  and terrain, the walking pieces and their Kenney pictures, the views,
  `TacticalTurn`, `BlueController` and the keys are reused unchanged;
  `UnitType.sight`, which `TacticalRules` says "nothing reads" until
  there is fog, gets its first reader.
- XCOM's two actions map onto `movement_points` and the tactical turn
  (walk, then perhaps attack, then spent): a dash is a walk past one
  action's range, a shot spends the piece.
- `tactical` gains a seam, `TacticalRuleset`, with the existing classes
  wrapped unchanged as `AdvanceWarsRuleset`; module `squad` holds
  `SquadRuleset` and depends on `tactical`, never the other way.
- One card with `modes`, one scene with an M key, `make demo-tactical
  MODE=squad`; `SquadRoster` apart from `TacticalRoster` so the league's
  seating is not re-rolled.
- If T84's first step finds the seam would change the Advance Wars
  results, the task stops and puts both options to the owner with their
  cost.

T85, T87, T88, T89 and T96 follow; T89 (art) now runs only if T85's
manual check asks for it, and T96's WFC builds maps from the tactical
game's own terrain. The literature page's answer 2 and the STATUS rows
say the same.

1. **ADR 0016's amendment allowed more than was answered.** *Done*: it
   names the three covered components (the n-gram, N9; the bandit in
   `ai_bandit`, N13; the bot match's difficulty model, N14), and anything
   else needs the owner. Answer 3 is quoted, the question is said to have
   recommended neither answer, and the reading ("extend") is stated as the
   ADR's, for the owner to confirm in T99's review. The new wording of
   invariant 6 in `CLAUDE.md` is marked proposed.
2. **An incremental mean has the refused shape.** *Done*: sums and counts,
   the mean computed on read; N13's planted cases include `/ n` as well
   as `*`.
3. **How N13 and N14 find their targets.** *Done*: as N9 does
   (`OPPONENT_ADDON`, `TABLE_HOLDERS_RE`) -- the folder, plus any script
   naming the class; T100's event log is said not to be an N14 finding.
4. **T97's new rule would have taken N13.** *Done*: the MDP task (now T98)
   writes N15.
5. **The literature page contradicted itself.** *Done*: T73's roadmap is
   kept as written and each statement the answers changed is marked
   *(superseded)* with its task -- "the one exception ... n-gram alone",
   A.1's new module, A.7's home, A.8, part B (only B.2 and B.6 are
   tasks), and "A new game, or the ones there are?".
6. **T86's acceptance.** *Done*: `make test-checkers-vectors` added;
   `outcomes` is a concrete default method, so checkers keeps compiling.
7. **Random draws in the search.** *Done*: every draw inside the search
   uses the shared xorshift; only the real game's dice are the board's.
8. **Ownership.** *Done*: the addon's vectors are on Nim and a toy dice
   game, and the squad positions are the squad's gate; the player model's
   Python is `python/gameaikit/botmatch/`, owned by `botmatch`.
9. **Files lists.** *Done*: T84 lists `godot/game/board/`,
   `godot/test/board/` and the tactical paths; the squad search tasks list
   `spec/squad/`.
10. **The invariant 7 gate.** *Done*: `check_llm_validated.py` is static
    (V1-V3), skips vendored and dot folders; refusals are held by
    `make test-llm-vectors`.
11. **The runtime task.** *Done*: `check_acceptance.py` learns
    `llm-smoke`, `llm-serve` and the port; `llm-smoke` starts and stops the
    server itself; model licences recorded and named beside the
    recordings; size M; the pinned build is a prebuilt release archive
    (checked with `gh api`: CPU, Vulkan, CUDA, ROCm, SYCL and OpenVINO
    builds for Linux x64), not a local build. One claim was corrected on
    the way: llama-server's default port is 9931 by its README, not 8080.
12. **T86 was L.** *Done*: split into T86 (MCTS and the relaxed interface
    in the addon, on Nim; no prereqs) and T87 (MCTS in the XCOM mode). The
    tasks after it moved up by one, T87-T100 becoming T88-T101, with every
    reference, prereq, the ADR and the STATUS rows renumbered.
13. **T96 (was T95) depended on searches it did not list.** *Done*: the
    step that re-ran them on generated maps is dropped.

Nits, all done: the bandit task's "ADR 0016" prereq removed; T95's key
named (K); a topmost "Resuming after 2026-10-26" pointer in STATUS; the
bandit task updates N9's docstring; `RecordedRuntime` answers
asynchronously.

## What the reviewer found sound

- Every part of the owner's seven answers lands in a task, and the order
  follows answer 1.
- The citations: each quoted sentence is in its source.
- Invariant 7's design -- the LLM as Façade's first phase only, the rules
  deciding, the secret never in a prompt -- and invariant 6's line drawn
  at fitting, not at saving.
- The tier-1 lessons: every technique has a Python half, and `ai_llm`'s
  lesson runs from recordings.

## Checks run after the fixes

`make lint-tasks lint-status`, `check_acceptance.py`, `check_links.py`,
`check_doc_freshness.py`, `check_translations_docs.py`,
`check_literature_table.py` and `check_no_employer_refs.py`: all exit 0.
