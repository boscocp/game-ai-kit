# Review: wave/155-a-bayesian-network-for-the-guard

T115 adds `ai_bayes`, a Bayesian network over discrete variables with
tables written by hand, asked by exact enumeration (AIMA fig. 13.10), and
what each piece of evidence did to the answer. It comes with a Python twin
and eight vectors from an independent `derive.py`. The infiltration guard
asks one whether anyone is there at all, from a noise, a door found open
and a partner gone quiet; above 0.3 it checks the sign, shuts the door and
its belief falls again. A panel under the radar shows the network.

A fresh context reviewed PR #111 at head 3da4d49. **Verdict: approve after
findings 1 to 3, no blocker: three shoulds and five nits.**

## What was reviewed

- The PR title and body, the task file and its proposed decisions.
- `godot/addons/ai_bayes/bayes_network.gd` and `python/gameaikit/bayes/`:
  enumeration, `influence`, `most_moved`, the refusals B1 to B5.
- `spec/vectors/bayes/`: `derive.py`, the README's hand-worked burglary,
  and the planted networks in both languages.
- The infiltration side: `guard_suspicion.gd`, `suspicion_view.gd`, the
  doors, the new action in `guard_actions.json`, `guard_acts.gd`, the
  overlay, and `suspicion_test.gd`.
- The technique pages in both languages, the stealth concept page, the
  infiltration page, the catalogue and the menu card.
- The branch's commits and their messages.

## Findings

1. **Should.** The panel's `>` marked `most_moved`, the largest change
   either way, while the guard acts on `lead_place`, the sign seen that
   raised the belief most. Measured: with nothing seen the mark sat on
   "noise: not seen, -0.01"; with a noise alone on "partner_quiet: not
   seen" (-0.087) over the noise (+0.059); with a partner gone quiet alone
   on "noise: not seen" (-0.205). The panel showed a different reason from
   the one acted on (invariant 13).
2. **Should.** Commit 3da4d49's message is wave 150's text (T143: the
   toolchain, `.gitignore`, ADR 0002), although its content is the removal
   of the door's legend line. The message file in the shared scratch
   folder was replaced between writing and committing.
3. **Should.** B5 accepted NaN (and infinity): `NaN < 0` is false, and a
   row holding NaN does not trip the sum check either.
4. **Nit.** `probability()` with a value the network lacks read
   `find() == -1` as the last row or column, in silence.
5. **Nit.** The Python twin took `"values": "yn"` as two values, because
   a string is iterable.
6. **Nit.** A sign counts as looked into within 1.5 m whatever way the
   guard faces; the header did not say so.
7. **Nit.** The explaining-away paragraphs did not say what to watch on
   the panel.
8. **Nit.** The view's signs came from `seen(world.time)`, and the belief
   and influences from the last question, so they could disagree for a
   step.

## What was done about them

1. `GuardSuspicion.lead` is the sign seen with the largest rise, computed
   with the rest each time the network is asked. `lead_place()` reads it,
   and the view marks it with `>`. `strongest` is kept as data, and the
   header says why it is not acted on. The overlay's `moved_most` is now
   `lead`. `suspicion_test.gd` pins the noise-alone case: the lead is the
   noise, while `strongest` is "partner not quiet" with a negative
   influence. A new test pins that with nothing seen there is no lead. The
   technique pages, the infiltration and stealth pages and the menu card
   now say "the one that raised it most", and the technique page explains
   how `most_moved` differs from the lead.
2. History is not rewritten. This record says so, and the PR is merged as
   a squash whose message is the PR's title and body, so the wrong message
   does not reach `main`.
3. B5 refuses a non-finite entry in both languages (`is_finite`,
   `math.isfinite`). NaN and infinity are planted in both unit suites, and
   the README's rule says "finite".
4. `probability()` checks both indices. GDScript pushes an error and reads
   0; Python's `list.index` raises ValueError, and its docstring says so.
   Both are pinned by a test. The two `ERROR:` lines in the gdUnit output
   are that test's own.
5. Both languages refuse values that are not a list, as B2. The README and
   both unit suites have it.
6. The header of `GuardSuspicion` says that being there is enough,
   whichever way the guard faces.
7. The stealth page, the infiltration page and the technique pages say
   what to watch: with only a partner gone quiet, the radio's chance of a
   fault is 0.548; once a door is also found open it falls to 0.047.
8. The view and the overlay draw `GuardSuspicion.asked`, the evidence the
   belief was last asked from.

After the rename, the overlay's `lead` was "" whenever no sign raised the
belief, and `make test-demo-overlays`, which refuses an empty field, failed.
That gate was not rerun after the review commit; T152's wave found it. The
overlay now says "none" when there is no lead (the word T152's stacked
branch uses), and the gate passes in en and pt_BR.

Rerun after the fixes: `make check-no-engine`, `make test-bayes-vectors`,
`make test-demo-overlays` (en and pt_BR), `make test-godot-some SUITES="test/ai_bayes test/infiltration"` (its
output read for `SCRIPT ERROR`: none), and `make lint-readability
lint-translations-docs`.
