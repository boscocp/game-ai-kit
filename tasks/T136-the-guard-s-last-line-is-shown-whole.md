# T136 — The guard's last line is shown whole

Size: S · Prereqs: T130 · Files: `godot/game/talk/`, `godot/test/talk/`, `docs/godot/talk.md`

## Goal

Found by the owner on 2026-11-06, playing `make demo-talk` in English: Bram's
last line read "Then step aside and let me check the serial number before you
burn out the", and stopped. The model did not stop there. The `History`
label in `talk.tscn` is 150 px tall with `clip_text = true`, and
`TalkPanel` shows the last `HISTORY_TURNS` (3) turns: six lines when every
line fits, and a seventh, wrapped, is cut off below the label's edge. The
newest line is the one cut, and it is the one the person is reading.

## Decisions written down first (the owner confirms in review)

- **The newest line is never the one hidden.** Show fewer old turns, not
  less of the new one: the history drops from the top until what is left
  fits the label (measured with the label's font, not a guessed line
  count), and the newest turn is always whole.
- `HISTORY_TURNS` stays as the most turns shown, not the number shown.
- The speech is not shortened: R8 already holds it to 280 characters.

## Steps

1. A test that fails today: three turns whose last speech wraps to a
   seventh line; the label's visible text holds the whole last speech.
2. Fit the history from the newest turn back.
3. One sentence in the talk game's page, if it names the history.

## Acceptance

```bash
make test-godot-some SUITES="test/talk"
make test-demo-overlays
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

`make demo-talk`, live, and say enough that Bram answers at length three
times in a row: is his newest line always whole?

## Notes

- Opened by the owner's manual checks of 2026-11-06 (screenshot of turn 5).
