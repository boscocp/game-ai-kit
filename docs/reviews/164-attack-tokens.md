# Review: wave/164-attack-tokens

The PR adds T154's `AttackTokens` to `ai_teamwork`
(`godot/addons/ai_teamwork/attack_tokens.gd`), its Python twin
(`python/gameaikit/teamwork/tokens.py`), a `tokens` vector kind with ten
vectors from `derive.py`, a suite on each side, the concept page
`docs/concepts/action-combat-ai.md`, a section in the technique page in
English and pt-BR, and six glossary rows.

A fresh context reviewed PR #125 at head 4cc1b55. **Verdict: approve, no
blocker. There are three shoulds and six nits.** The grant order is
correct and the starvation bound holds; what the review found is a test
that looks like it holds the bound and does not, a way out of the queue
that only death provides, and a few places where the docs say a little
more or less than the code and the sources.

## What was reviewed

- The acceptance commands, run on the branch (load average about 3 on
  12 threads, other worktrees testing):
  - `make test-godot-some SUITES="test/ai_teamwork"`: exit 0, 23 cases,
    0 failures, no `SCRIPT ERROR` in the output;
  - `make test-teamwork-vectors`: exit 0, "42 file(s), 0 failure(s)";
  - `make test-python`: exit 0, 683 tests;
  - `make lint-tiers`: exit 0.
- `make check-affected BASE=origin/main`: exit 0 in 50 minutes, with the
  load rising to 14 while other worktrees tested. It selected every gate.
  Nine `SCRIPT ERROR` lines, all of them the known planted ones
  (`ai_core/interfaces_test.gd`, `board/policy_interface_test.gd`,
  `menu/demo_overlays.gd`). No timing gate failed, so nothing had to be
  rerun on its own.
- The vectors: `derive.py` regenerated into an empty folder and compared
  with `diff -r`; identical to the committed ten. `derive.py` is a third
  copy of the rules -- its own `fnv`, its own sort key, its own step loop,
  importing nothing from the repository -- so the two implementations are
  checked against it, not against each other. The three tie vectors give
  `right`, `right`, `left`: the same winner for seed 7 either way round,
  the other for seed 8, so a tie broken by storage order fails one of them.
- The hash: FNV-1a with the published offset and prime, masked to 32 bits
  after each multiply in both languages; `fnv1a("a") == 0xE40C292C` on
  both sides. In GDScript the product stays below 2^56, inside `int`'s 64
  bits, and the hash fits a `float` exactly, so the sort key loses nothing.
- **The planted cases, planted in the implementation itself** (not only
  the subclasses in the suites), one at a time, restored after each, and
  `__pycache__` cleared after the round:

  | plant | Python | GDScript |
  |---|---|---|
  | leaking pool (`_take` does nothing) | random-fight test and 10 vectors fail | random-fight test fails (60 trials), 46 vector failures |
  | no timeout (`_time_out` returns nothing) | forgetful-holder test and `death-and-timeout` fail | forgetful-holder test fails, 3 vector failures |
  | tie by storage order | tie test and `seed-7-left-first` fail | tie test fails, 3 vector failures |
  | no patience (`patient` always false) | `patience-serves-the-passed-over` fails | `test_patience_is_what_stops_the_low_from_starving` fails, 5 vector failures |
  | overtaking (serve the first that fits) | `the-boss-goes-first-and-is-not-overtaken` fails | not planted |
  | patience `>=` for `>` | the patience vector fails | not planted |
  | the grant delay ignores the player's state | two vectors fail | not planted |

  Every planted case the task names is rejected on both sides.
- The grant order and the bound, read in the code and then pushed. A
  waiter is passed over at most `patience` grants of its kind before it is
  patient. After that, only a patient waiter with an earlier key
  (`asked_at`, then distance, hash, id) can go before it, and each of those
  was already waiting: a requester that asks again after a grant gets a
  new `asked_at`, and a new one starts at `passed = 0`, so it cannot be
  patient. No overtaking cannot break the count, because when the head
  does not fit nobody is granted and nobody is passed over. Attempts at a
  counterexample -- a stream of priority-3 requests against one priority-0,
  a re-request at the same `now`, a heavy head behind light holders,
  revoke and death mid-queue -- all stayed inside `patience` plus the
  number ahead. Over 500 random fights of the suite's shape in the Python
  twin, the worst passes were 4 for melee and 3 for ranged, inside
  `patience + 3` and `patience + 1`.
- Invariant 2: `attack_tokens.gd` preloads and names nothing outside
  itself -- not even `ai_core` -- and `check_addon_deps.py` exits 0.
- Readability: `check_readability.py` exits 0. The file is 291 lines, the
  longest function is well under 40, every public function has a `##`
  comment saying what and why, every variable is typed, and the code has
  no single-letter names (`derive.py`'s `h`, `w`, `e` are the house's
  style for that file and outside the gate).
- Dawe's chapter, downloaded from the URL the page cites and read through
  `pdftotext`. Every claim the concept page attributes to it is in the
  text: the kung-fu circle and why it is too strict (28.2), the grid and
  attack capacities with the soldier 4, troll 8, capacity 12 example and the
  charge 6, sword 3, lunge 5 attack example (28.3), the two circles
  (28.3.1), the three behaviours and the quotations (28.4), difficulty as
  the capacities (28.5), stealing, the lock and the cooldowns (28.6). The
  "less than" versus 12 - 4 - 8 = 0 observation is right: the text says
  "less than" and its own troll is "still within" a capacity of exactly 8.
- Thompson's article (Game Developer, 6 August 2018) has every quoted
  sentence: tokens per attack type, request and release, "a different set
  of token counts for each attack type", stealing, and "unfair if the
  demons are attacking when the player cannot respond".
- Erunsal's forum thread has all four quoted phrases.
- The Spider-Man talk: the page claims nothing from it, lists it under
  "Could not be checked", and says `revoke_kind` and the busy multiplier
  are the task's own design. Honest.
- pt-BR: *attack token*, *melee*, *ranged*, *telegraph*, *hash* and
  *timer* stay in English, italicised, and each has a glossary row; *seed*
  already had one. Code and comments in the example stay English. The
  links to English-only pages say "(em inglês)", as the other pages do.
- Invariant 13: the technique page says in both languages that
  `AttackTokens` has no demo until T157, and the task's Notes say its half
  is open until then.

## Findings

1. **Should. The random-fight bound test passes with patience removed.**
   `test_every_requester_is_served_within_patience_and_those_ahead`
   asserts `served.max() <= patience + FIGHTERS - 1`, that is 8. With
   `patient` planted always false, this test still passed in GDScript (the
   suite's first failure was the next test,
   `test_patience_is_what_stops_the_low_from_starving`). Its bound is
   looser than the one the code keeps: the melee fighters are four, so the
   true bound is `patience + 3`, and the ranged two, `patience + 1`. Over
   500 random fights without patience the Python twin reached 10 passes
   for melee; with it, 4. As written, the test that reads like the proof
   of the bound proves only that 60 random fights did not starve anyone
   much, and the technique page's "the suite holds that bound" leans on
   the deterministic test alone. The Python suite has no bound test and no
   no-patience plant at all; only the vector holds patience there.
   **Fix:** bound per kind -- `patience + (fighters of that kind) - 1` --
   and add a planted run with `patience = 1000` that must exceed it (more
   trials, or a fight shaped so priority varies more, if 60 are not
   enough). Add the same test and plant to `test_teamwork_tokens.py`.

2. **Should. Only death takes a requester out of the queue.**
   `release(id, reason)` erases a *waiter* only when `reason == DIED`; an
   enemy that was staggered, knocked away or changed its mind while
   waiting stays queued, and with no overtaking it can become the head,
   be granted, and hold a token nobody uses until the timeout (or for ever,
   with no timeout configured -- see 4). The only way a game can withdraw a
   request today is to report a death that did not happen, and that is not
   logged, so a view cannot tell the two apart. **Fix:** either let
   `INTERRUPTED` also leave the queue (and say so in `release`'s comment),
   or add a `withdraw(id, now)` that removes a waiter and logs it; one
   vector in `derive.py` for it.

3. **Should. Asking again with another kind or cost is silently ignored.**
   A waiter that asks again keeps its place and takes the new priority and
   distance, but its `kind` and `cost` stay what they were; the call
   answers `WAITING`, as if the new request had been queued. A troll that
   switches from a light swing (1) to its charge (2) while waiting is
   granted the light one. Likewise a holder of `ranged` asking for `melee`
   is told `HOLDING`, which is true but not of that kind. `derive.py` does
   the same, so the vectors cannot see it. **Fix:** say it in `request`'s
   comment at the least; better, treat a different kind or cost as a new
   request (it loses its place, which is honest), and pin it with a vector.

4. **Nit. The safety net is opt-in.** `Config.timeouts` is empty by
   default, so a kind with no timeout reads `INF`, and a holder that forgets
   blocks its whole kind for ever: no overtaking means nobody behind it is
   served either. The header and the technique page present the timeout
   as the net. **Fix:** one line on `timeouts` saying a kind without one
   has no net, or refuse a `Config` with a pool and no timeout.

5. **Nit. The player's state sets the *next* wait, at grant time.** The
   multiplier is read when a token is granted and fixes `_next_grant`; if
   melee pressure starts a moment after a ranged grant, the next ranged
   grant still comes at the unstretched time. That may be the intent, but
   `step`'s comment ("picks the delay's multiplier") and the page's
   "longer when busy" suggest it reacts to the state now. **Fix:** say "the
   state at a grant sets the wait until the next one", or compare against
   `last_grant + delay_for(kind, state)` at each step.

6. **Nit. The bound's statement says "asked before it".** The code's key
   after patience is `asked_at`, then distance, hash and id, so a waiter
   that asked at the same moment and is nearer also goes first. **Fix:**
   "plus the number still waiting who asked no later than it", in the
   technique page (both languages) and the task's Notes; the suite's own
   comment already says "no later".

7. **Nit. The concept page's references say two things that are not
   so.** Thompson is "2018 (the year as T154's sources give it; not
   re-read)" and, on the next line, "read, 2026-11-10"; the article is
   dated 6 August 2018, so the hedge can go. Erunsal's is "its date not
   shown", but the thread shows a date on each post, and the quoted
   phrases come from two of them (21 December 2025 and 28 October 2026).
   **Fix:** give the dates.

8. **Nit. "Only the one attacking steps into the inner [ring]."** Dawe
   says creatures "granted permission to perform a particular attack" move
   in -- plural, as the attack capacity allows several. **Fix:** "only
   those attacking".

9. **Nit. `Waiter` and `Holder` have no `##` line.** They are public inner
   classes a reader meets in the signatures of `_grant` and `_return`.
   **Fix:** a line each: what one entry of the queue and of the holders
   keeps.

## Not findings

- **The vectors are not the implementation checking itself.** `derive.py`
  was written by the same wave, but it imports nothing, is shaped
  differently (one loop over a script, lists not objects), and its output
  is byte-for-byte the committed files.
- **No overtaking does not starve anyone.** When the head does not fit
  nobody is granted, so the holders drain (by release or timeout) and the
  head fits; and nobody's pass count moves while it waits.
- **`release` with `TIMED_OUT` returns false.** Timing out is the pool's
  own act, not the game's; `RETURN_REASONS` leaves it out on purpose.
- **"Five ways" in the technique page against the task's "four".** The
  page counts ended, interrupted, died, revoked and timed out separately;
  the task grouped interrupted and died. Both lists are the same.
- **No `Gak` prefix.** Not a port (ADR 0024), as the task's owner
  decision says.
- **Dawe's lock and the kit's holding.** Dawe locks a slot *during* an
  attack and gives the slot back right after launching it; the kit holds
  the token until the attack ends. The page calls the kit's holder "Dawe's
  lock held for the whole attack", which is a fair reading and says what
  the kit leaves (stealing).
- **`O(waiting log waiting)` per grant.** `waiting()` sorts the kind's
  queue once per grant; with a handful of enemies per target, it is the
  readable choice.
