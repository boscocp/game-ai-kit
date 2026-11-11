# T168 — A slow self-test is not a hang

Size: S · Prereqs: none · Files: `scripts/run_selftests.py`, `scripts/library_check.py`, `python/tests/`

## Goal

Main's CI went red from #132 on: `lint-selftests` killed
`library_check.py --self-test` at 120 s on GitHub's runner. It takes about
75 s locally. Wave 179 raised the one limit for every self-test to 300 s as
a stopgap, a number that was not measured on the runner. Now a real hang in
any self-test holds the job for five minutes, and the next slow self-test
will meet the same wall.

## Decisions written down first

_From the review of wave 179 (finding 3), 2026-11-11. The wave confirms the details._

- **Measure first.** Print each self-test's duration in
  `run_selftests.py`'s output, so the CI log shows who is slow before the
  limit is touched again.
- **Make the slow one fast, not the limit long.** `library_check.py`
  follows the page with Godot once per planted fault (17 cases, about
  4.4 s each), in a row. Each case has its own folder. Run them in
  parallel, or plant several faults per run where they cannot mask each
  other. Check first that parallel Godot runs do not share a `user://`
  that one of them clears.
- **Then bring the limit back down** to what the measurement supports,
  and keep the planted hang in `run_selftests.py --self-test` failing.

## Acceptance

```bash
python3 scripts/run_selftests.py --self-test
python3 scripts/library_check.py --self-test
make lint-selftests
```

## Manual check

- On GitHub's runner, read `lint-selftests`' durations in the CI log: no
  self-test within half of the limit.
