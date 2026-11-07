# Conformance vectors: bayes

<!-- doc-meta
half_life: structure
verified_on: 2026-11-06
tier: 1
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- sections 13.2 and 13.3.1, figures 13.2 and 13.10
invalidated_if: the network's data shape, the order a table's rows are read in, the refusal rules or what `influence` measures changes
teaches: none
-->

> One network, two languages, and the files that say they answered the same.

`ai_bayes`'s `BayesNetwork` (GDScript) and `gameaikit.bayes` (Python) read
the same network data and answer the same questions. Each vector is one
`.json` file: a `network`, and either the `problem` -- the rule it must be
refused by -- or the `queries` asked of it. A query names the variable
asked about (`query`), what was seen (`evidence`, a variable to a value),
the value whose chance is followed (`value`), and the claims: the
`distribution`, one chance per value of the query in their order, and the
`influence` of each piece of evidence on the followed chance. Both sides
check every claim against the file, never against each other: `make
test-bayes-vectors` on the GDScript side, `make test-python` on the Python
side.

The rules the two follow, and that a third implementation must follow to
agree:

1. a network is `{"variables": [...]}`, each `{"name", "values",
   "parents", "table"}`, a parent always given before its child;
2. a table has one row per combination of the parents' values, **the first
   parent varying slowest**: with parents A (a1, a2) and B (b1, b2, b3) the
   rows are a1b1, a1b2, a1b3, a2b1, a2b2, a2b3; each row gives one chance
   per value of the variable, in its order, and sums to 1;
3. `ask(query, evidence)` is ENUMERATION-ASK (AIMA 4th ed., figure 13.10):
   for each value of the query, the sum over every value of every variable
   not fixed of the product of every variable's table entry, then each sum
   over their total; empty when the total is 0 -- evidence that cannot
   happen has no answer;
4. `influence(query, value, evidence)` is, for each piece of evidence in
   its order, P(query = value | all of it) less P(query = value | all but
   that piece): positive, it raised the belief; empty when the evidence
   cannot happen;
5. a network is refused, by the first rule it breaks, variable by variable:
   **B1** no variables; **B2** a variable with no name, a name taken,
   values that are not a list, or fewer than two distinct values; **B3** a parent not given before it;
   **B4** a table without one row per combination, or a row without one
   chance per value; **B5** an entry that is not a finite chance of 0 or more, or
   a row not summing to 1 within 1e-9.

`derive.py` wrote every file. It imports nothing from the repository, and it
does not enumerate: it writes out the whole joint distribution -- every
assignment of every variable, each the product of one entry a variable --
and adds the rows that agree with the question (AIMA 12.3). Same numbers by
a different road; the sums differ in order, so both sides allow 1e-12.

## The burglary, by hand

AIMA's figure 13.2: a burglary (0.001) or an earthquake (0.002) sets off
the alarm -- 0.95 for both, 0.94 burglary only, 0.29 earthquake only, 0.001
neither -- and John (0.90 if it rings, 0.05 if not) and Mary (0.70, 0.01)
call. Both called. Is there a burglar?

Fix burglary = yes. The earthquake and the alarm are hidden, so sum over
their four combinations, each the product of five entries:

| earthquake | alarm | P(e) | P(a \| b, e) | P(j \| a) | P(m \| a) | product with P(b) = 0.001 |
|---|---|---|---|---|---|---|
| yes | yes | 0.002 | 0.95 | 0.90 | 0.70 | 0.0000011970 |
| yes | no | 0.002 | 0.05 | 0.05 | 0.01 | 0.0000000001 |
| no | yes | 0.998 | 0.94 | 0.90 | 0.70 | 0.0005910156 |
| no | no | 0.998 | 0.06 | 0.05 | 0.01 | 0.0000000299 |

Their sum is 0.00059224. With burglary = no (0.999) the same four rows,
alarm chances 0.29 and 0.001, sum to 0.00149186. Normalised: 0.00059224 /
(0.00059224 + 0.00149186) = **0.284**, and 0.716 for no -- the book's
answer, and `burglary-john-and-mary-call.json`'s first query.

Its influence: without Mary's call, P(burglary | john) is 0.0163; without
John's, P(burglary | mary) is 0.0561. So John's call added 0.284 - 0.0561 =
0.228 and Mary's 0.284 - 0.0163 = 0.268. Mary moved the belief more: she
rarely calls for nothing (0.01 against John's 0.05).

## The files

| file | what it holds |
|---|---|
| `burglary-john-and-mary-call.json` | the worked answer, the alarm asked, and the prior with no evidence |
| `burglary-explained-away.json` | an alarm explained away by an earthquake: the earthquake's influence is negative |
| `three-values-and-two-parents.json` | values of three and of two; a six-row table read the wrong way round lands on another row |
| `impossible-evidence.json` | evidence of chance 0: no distribution, no influence |
| `the-guards-intruder.json` | the infiltration guard's network, all eight ways its evidence can be; the game's file is held to it |
| `refused-a-parent-after-its-child.json` | B3 |
| `refused-a-row-short.json` | B4 |
| `refused-a-row-not-summing-to-one.json` | B5 |
