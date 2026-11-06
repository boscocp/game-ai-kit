# Review: wave/145-the-guard-s-last-line-is-shown-whole

T136 fixes the talk game's `History` label, 150 px with `clip_text`,
which cut Bram's newest line when three exchanges wrapped past six
lines. `TalkPanel.show_history` now sets the label to the last
`HISTORY_TURNS` exchanges, then to fewer, until `_fits` says the label
shows every line. With a line pending it may go down to none, so
"Bram is thinking..." stays in view. `TalkPanel.history` gains a
`shown` count. `docs/godot/talk.md` records how `Label.get_line_count`
and `get_visible_line_count` behave on 4.7.2.

A fresh context reviewed PR #96 at head e2636aa (base origin/main
b45a20a) in a throwaway worktree. It reverted the fix, planted four
faults one at a time and restored each one before the next. It also
measured the label on the pinned engine with throwaway `-s` scripts,
deleted afterwards. It made no commit, push or PR comment.

**Verdict: changes requested. No blocker, three should-fix findings
and two nits.** The fix does what the task asks for every realistic
answer, and the test fails for the right reason without it. The weak
spots are the one case the loop cannot fix, a single exchange taller
than the label, and two branches of the new code that no test holds.

## What was reviewed

- `CLAUDE.md` (invariants 1, 3, 4, 11 and 12, "Readable by a person",
  "Check the documentation before writing the rule", the traps), the
  task file, the PR body and its decisions, and
  `docs/reviews/142-wave-function-collapse-for-the-squad-maps.md` for
  the format.
- The diff: `godot/game/talk/talk_panel.gd`, `godot/game/talk/talk.gd`,
  `godot/test/talk/talk_test.gd`, `docs/godot/talk.md`,
  `tasks/STATUS.md`, `tasks/T136-the-guard-s-last-line-is-shown-whole.md`.
- For context: `godot/game/talk/talk.tscn` (History is 608 x 150 at
  fixed offsets on a `CanvasLayer`; `project.godot` sets no stretch
  mode, so a window resize does not change its size), `talk.gd`'s
  `_notification` (a language change restarts the conversation, so the
  history starts empty in the new language),
  `godot/addons/ai_llm/llm_validator.gd` (`SPEECH_LIMIT` 280) and
  `spec/talk/gate.json` (`player_line_limit` 100).

## What was run

- `make test-godot-some SUITES="test/talk"` at e2636aa: 24 cases, 0
  failures, exit 0, no `SCRIPT ERROR`.
- The same with `talk.gd:305` put back to
  `_history.text = TalkPanel.history(guard.turns, pending)`: 1 failure,
  `Expecting to be less than or equal: 6 but was 9` at
  `talk_test.gd:241`, no `SCRIPT ERROR`. That is the right reason. The
  `ends_with` assertion on line 239 passed in that run (finding 4).
- `python3 scripts/check_readability.py`: exit 0.
- Measurements, a `Label` 608 x 150, font size 14,
  `AUTOWRAP_WORD_SMART`, `clip_text`, Godot 4.7.2.stable.official.ed1daf0bf, headless:
  - not in the tree: `get_line_count` 1, `get_visible_line_count` 1 for
    an eight-line text, as the page says;
  - in the tree, after "one\ntwo" was counted, then an eight-line text
    with `get_visible_line_count` asked first: 2, then
    `get_line_count` 8 and `get_visible_line_count` 6, as the page says;
  - a label added to a running tree answers 8 and 6 in the same frame;
  - one exchange at the limits (a 100-character player line, a
    280-character speech): ordinary words 6 lines, all-capital words
    ("WHO GOES THERE") 6, a wide-glyph speech ("MMMM...") 10 lines, 6
    shown; with a short player line, 5, 5 and 8 (finding 1).
- The Godot claim against the docs: the class reference page could not
  be fetched from this context, and `--doctool` without the doc base
  writes empty descriptions. It did confirm that 4.7.2's `Label` has
  `lines_skipped` and `max_lines_visible`, used in finding 1. The page's
  claims stand on the measurement above, which agrees with them. The
  page carries the Label class URL in `source:` and
  `verified_on: 2026-11-06`.

### Planted faults

| planted | where | caught by |
|---|---|---|
| fix reverted (`_history.text = TalkPanel.history(...)`) | `talk.gd:305` | 1 failure, 9 > 6 |
| `_fits` never measures (`if true:`) | `talk_panel.gd:76` | 1 failure |
| `_fits` asks the visible count first | `talk_panel.gd:84-85` | **survives** (finding 3) |
| `fewest` always 1, a pending line cannot push the last exchange out | `talk_panel.gd:73` | **survives** (finding 2) |
| `fewest` always 0, the label may end empty with no line pending | `talk_panel.gd:73` | **survives** (finding 1) |

## Findings

1. **should fix** -- `godot/game/talk/talk_panel.gd:72-77`. When one
   exchange alone is taller than the label, the loop ends on
   `history(turns, "", 1)`, which still does not fit, and the bottom
   is clipped. The bottom is the newest line, the one the task says
   is never cut. With ordinary words, a 100-character player line and
   a 280-character speech come to exactly 6 lines, so there is no
   margin left. Wide glyphs reach 10 (measured above), and a longer
   pt-BR prefix or a bigger font would too. The loop always ends: the
   range is finite and it returns on the first fit. It shows nothing
   only when there are no turns. **Fix:** set `label.lines_skipped = 0`
   on entry. After the loop, if `_fits` is still false, set
   `label.lines_skipped = label.get_line_count() - label.get_visible_line_count()`,
   so the top of the player's line is cut and the speech is not. Add a
   test with one short player line and a speech of wide glyphs. If the
   owner prefers not to fix it, say the limit in `docs/godot/talk.md`
   and in the PR body. Right now both read as if no case is left.
2. **should fix** -- `godot/test/talk/talk_test.gd:219` (no test).
   The pending branch (`fewest` 0), which decision 2 of the PR body
   relies on, is not tested. Planting `fewest: int = 1` passes the
   suite. **Fix:** a second test. After the three exchanges of the
   existing test, say a fourth line while the runtime holds its reply
   (or call `show_history` directly on the scene's label with a
   `pending` string). Assert that the text ends with
   `tr("Bram is thinking...")` and that `get_line_count() <=
   get_visible_line_count()`.
3. **should fix** -- `godot/game/talk/talk_panel.gd:84-85`. The
   page's own measured finding, that the lines must be counted first,
   is not held by any test. Swapping the order passes the suite. A
   stale visible count is never larger than the old line count, so the
   wrong order cannot clip. What it does is drop exchanges that would
   have fit. **Fix:** a direct test on a bare `Label` in the tree, with
   the scene's size, font size and autowrap. Set `text = "x"` and call
   `get_line_count()`, then call `show_history` with three one-word
   exchanges (six lines). Assert that all three are shown: the text
   begins with the first exchange's "You:" line.
4. **nit** -- `godot/test/talk/talk_test.gd:239`. `assert_str(history.text).ends_with(...)`
   passes with the fix reverted, because `text` holds the whole speech
   even while the screen cuts it. Only the line-count assertion on 241
   is the regression check. **Fix:** replace it with an assertion that
   the oldest exchange was dropped. For example, the text does not
   contain the first answer ("Hm."), which shows the drop came from the
   top. Or say in a comment that line 241 is the check.
5. **nit** -- `godot/game/talk/talk_panel.gd:81-83`. `_fits`'s comment
   says the lines are counted first, but the local `lines` reads like a
   name for readability's sake. Someone tidying it into one expression
   would bring back finding 3's order. **Fix:** in the comment, say
   that the local exists to fix the order of the two calls, or let
   finding 3's test hold it and keep the comment as it is.

Not findings: the readability rules hold (`show_history` 7 lines, `_fits`
2, doc comments say what and why, static types, no abbreviations). The
scope matches the task. The task file's `Files:` line was widened
honestly to `docs/godot/talk.md`. The STATUS row is accurate. There is
no tooling byline in the commit e2636aa (author Adalberto Pereira
<adalbertobosco@gmail.com>), the PR title or the PR body. A label not
yet in the tree "fits" any text, and this is harmless: `_refresh` runs
from `_ready` with no turns, and later refreshes happen with the label
already in a running tree, which answers correctly in the same frame.

## What was done about them

Applied on the same branch. Main had not moved (b45a20a). Each plant
below was put in `talk_panel.gd` alone, the talk suite run, and the file
restored.

1. **Should-fix, fixed.** `show_history` sets `lines_skipped` to 0 on
   entry. If one exchange still does not fit after the loop, it sets
   `lines_skipped` to the line count less the visible count, so the top
   of that exchange is cut and its newest line shows.
   `test_one_exchange_taller_than_the_label_loses_its_top_not_its_end`
   uses a short player line and a speech of seven 35-letter "M" words.
   It asserts that the skipped and visible lines add up to all of them,
   and that a short exchange afterwards skips none. The plant (no skip
   after the loop) turns it red: expecting 8, but was 6.
2. **Should-fix, fixed.**
   `test_a_pending_line_pushes_out_the_newest_exchange_when_it_must`
   shows three exchanges, the last one long, plus a pending line on the
   scene's History label. It asserts that the text ends in "Bram is
   thinking..." and that every line shows. The plant `fewest: int = 1`
   turns it red: 7 lines, 6 shown.
3. **Should-fix, fixed.** `test_the_lines_are_counted_before_the_visible_ones`
   counts "x" first on a bare copy of the History label, then shows
   three one-word exchanges. It asserts that the text begins with the
   first exchange's "You:" line. The plant (visible count asked first)
   turns it red: the first exchange was dropped.
4. **Nit, fixed.** The `ends_with` assertion is now
   `not_contains("Bram: Hm.")`. The oldest exchange gave way, and the
   drop came from the top.
5. **Nit, fixed.** `_fits`'s comment now says the local `lines` is there
   to fix the order of the two calls, and what the other order does.
