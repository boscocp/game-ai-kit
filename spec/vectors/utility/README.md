# Conformance vectors: utility

<!-- doc-meta
half_life: structure
verified_on: 2026-10-29
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a choice's rule changes -- a curve's comparison, the product's veto, the tie, an errand's gain or cost -- or the bot match's actions.json or rules.json numbers these copy change
teaches: none
-->

> Two choices, two languages, and the files that say they gave the same
> answers.

`ai_utility` (GDScript) and `gameaikit.utility` (Python) implement the same
two things: `ActionChoice`, every action scored by its considerations and
the highest taken (T67), and `ErrandChoice`, each errand weighed as a gain
less its costs (T67, T68). Each vector is one `.json` file: a query and the
answer it must get. Both sides answer it and check every value against the
file, never against each other: `make test-utility-vectors` on the GDScript
side, `make test-python` on the Python side.

These were teamwork vectors until T101 moved utility choice out of
`ai_teamwork`, for nothing in it is about a team. They moved unchanged:
`derive.py` here writes every file byte for byte as
`spec/vectors/teamwork/derive.py` wrote it before the move.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the rules in plain dictionaries that imports nothing from this
repository. Independent of the code, not of its author: it makes the same
choices -- the first of equal scores wins, going back wins a tie -- so it
catches a slip in transcribing them, not a choice that is wrong.

`ActionChoice` was asked whether each comparison matters: its step's `>=`,
the choice's strict `>` and its floor of zero, both ends of the line's
clamp and the 0 an absent percept counts as -- each changed once in
GDScript and once in Python, and each change failed a vector. So was
`ErrandChoice`: the fetcher's strict `>`, the three comparisons of the
choice, and each of the weighing's branches -- the earned weapon, the empty
bot, attacking, a weapon not there. T68's additions were asked the same in
the Python twin: the choice of three's `>=` and its floor of zero -- each
fails a vector. So, after T68's review, do dropping `health_worth` or the
exposure from either gain: a vector weighs health at 0.5, and one is the
review's case, a hurt bot nobody sees, which stays.

    python3 spec/vectors/utility/derive.py spec/vectors/utility

## The tolerance

1e-4 on every number, the same as the teamwork vectors it came from. Every
score is a 64-bit float on both sides; a name or an index must be equal.

## The kinds

| kind | query | answer |
|---|---|---|
| `action` | actions as plain data (weight, considerations with their curves), records of percepts | for each record, every action's score, every consideration's answer, and the action taken (-1: none) |
| `errands` | the weights; facts for going back, for fetching and for hiding to heal (T68); each team's fetching scores; pairs -- or triples, with hiding -- of scores | each weighing as [gain, walk, cost, score], hiding's walk the seconds away; whom each team sends (-1: nobody); each pair's errand ("": none) |

## The twenty-one

| file | what it pins |
|---|---|
| `the-best-reason-wins` | loaded, shoot; empty, a veto on shooting and reload; nothing to do, hold |
| `one-zero-vetoes-the-rest` | one answer of 0 makes the product 0 whatever the others say |
| `a-step-on-its-threshold-is-above` | a percept exactly on a step's `at` answers `above`: the comparison is `>=` |
| `a-line-is-clamped-at-both-ends` | a line below 0 answers 0, above 1 answers 1 |
| `equal-scores-take-the-first` | of two actions tied, the first listed is taken |
| `nothing-above-zero-chooses-nothing` | every action vetoed: -1, not the first of zeros |
| `an-absent-percept-is-nothing` | a percept not given counts as 0 |
| `the-bot-match-weighs-its-actions` | the match's own six actions (a copy of `actions.json`) on five moments of a fight |
| `the-bot-match-weighs-its-pace` | the match's walk-or-sprint: far, a tie on the threshold, danger, an enemy's veto, not moving |
| `the-bot-match-weighs-its-posture` | the match's stand-or-crouch, the same technique: idle, at low cover, reloading, shooting over cover, walking |
| `back-for-rounds-when-spent-and-near` | spent and near its base it goes back; full, the same walk is not worth it |
| `an-empty-bot-has-no-post-to-leave` | with no round left, leaving its post costs nothing |
| `home-heals-whole-so-health-counts` | under fire, a deep wound is worth the walk home; a quarter gone is not |
| `unseen-it-heals-where-it-stands` | nobody sees it and nothing hits it: the health is worth nothing to an errand |
| `health-worth-half-of-the-rounds` | `health_worth` at 0.5 halves what the wound is worth, going back and hiding alike |
| `the-streak-earns-the-power-weapon-at-home` | a full bot whose kills earned the power weapon goes back for it |
| `fetch-unless-far-guarded-or-gone` | the walk and each enemy near the weapon cost; a weapon not there is worth nothing |
| `the-team-sends-the-one-it-is-worth-most-to` | the first of the highest, and nobody when none is above zero |
| `going-back-wins-a-tie-and-zero-is-no-errand` | back on a tie; a score of exactly 0 is no errand |
| `hide-when-the-wound-is-deep-and-the-wait-short` | a deep wound, near cover, a short wait: hide; a scratch, a long wait, or nowhere to hide: no |
| `the-highest-of-three-and-ties-go-back-then-fetch` | of three, the highest; ties go back, then fetch, then hide; all below zero, none |
