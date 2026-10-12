# T1 — The gates, before any game code

Size: L · Prereqs: T0 · Files: `scripts/check_*.py`, `Makefile`, `.githooks/`

## Goal

Every invariant in `CLAUDE.md` defended by a script that can fail, so the rules
are commands rather than prose. No game code is written until this is done: a
rule added after the code has to argue with the code.

## Steps

1. Port from the author's `desk-panel`: `check_commit_msg.py`,
   `check_acceptance.py`, `check_status.py`, `check_links.py`,
   `check_workflow.py`. The acceptance gate has no `--self-test` there; the port
   gains one, and its hanging-command rules change from `adb` to Godot without
   `--headless`.
2. Write fresh: `check_disk_layout.py`, `check_renderer.py`,
   `check_readability.py`, `check_license.py`, `check_no_employer_refs.py`,
   `check_doc_freshness.py`, `check_addon_deps.py`, `check_tiers.py`.
3. Every one carries a `--self-test` with a planted case it must reject, and
   `lint-selftests` discovers them by glob rather than by a list.

## Acceptance

```bash
make check
make lint-selftests
```

Each gate must reject its planted case. The self-tests assert that internally;
these two prove the wiring, by making a real file wrong and watching a real
gate go red:

```bash
cp godot/test/smoke_test.gd /tmp/smoke.bak
printf '\n\nfunc planted(a):\n\tvar z = 1\n\treturn z\n' >> godot/test/smoke_test.gd
! python3 scripts/check_readability.py
cp /tmp/smoke.bak godot/test/smoke_test.gd
python3 scripts/check_readability.py
```

```bash
sed -i 's/gl_compatibility/forward_plus/' godot/project.godot
! python3 scripts/check_renderer.py
sed -i 's/forward_plus/gl_compatibility/' godot/project.godot
python3 scripts/check_renderer.py
```

## Manual check

Read one gate's docstring end to end and decide whether a stranger could tell,
from it alone, what the rule is and why it exists.
