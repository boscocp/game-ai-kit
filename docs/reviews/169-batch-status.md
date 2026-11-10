# Review: wave/169-batch-status

Docs and tasks only: a resuming section in `tasks/STATUS.md` for batch
164-168, the T162 task and row, T162 added to T161's prereqs, "A faster
batch" in `docs/howto/parallel-batch.md`, and
`docs/godot/project-manager-black.md`.

A fresh context reviewed PR #127 on `origin/wave/169-batch-status`, on the
short list of commands only.
**Verdict: approve after the shoulds. No blocker; three shoulds and one
nit.**

## What was reviewed

- `git diff origin/main...origin/wave/169-batch-status` (5 files), CLAUDE.md,
  `docs/reviews/168-published-archive.md` for the format.
- **The commits and PR numbers.** `git log origin/main`: #122 `75caf84`
  (T140), #123 `9ded03f` (T148), #124 `cd67a05` (T146), #125 `b474617`
  (T154), #126 `dfb51d6` (T159). Every pairing in the section matches.
- **What each task did**, against its STATUS row and notes: T140's R9
  cleaning; T148's 11 crashes in 115 threaded cold imports, none in 160,
  godotengine/godot#125245, `docs/godot/cold-import.md`; T146's
  `make test-demos-exit` over 17 scenes (T146 notes, review 166) plus the
  squad mode (`MODE_REQUIRED` has exactly that one), owner-approved, owned
  by `menu`; T154's `AttackTokens` in `ai_teamwork`, Python twin, 13
  shared vectors; T159's `make check-published`. All agree.
- **The store file is v0.1.0.** `tools/store/published.json`: size 314853,
  sha256 `8538106a…ecbbd1db`, provenance `v0.1.0`, shown 322.41 KB; the
  section's numbers and the 1.024 / 1000 arithmetic match it and review 168.
- **CI claims.** `gh run list --branch main`: #121 and #122 completed
  success; #123-#126 in progress. The #122 run went 14:47 to 16:38 UTC,
  the "1 h 51 min" in parallel-batch.md.
- **T162's acceptance commands exist**: `check_published.py --self-test`
  (line 416), Makefile targets `library-check` (1293) and `test-demos-exit`
  (749). `scripts/store/load_every_class.gd` and `docs/godot/exit-leaks.md`
  exist. That `godot_checked.py` does not count the line is true and
  deliberate: its self-test has the case "a leak report, forgiven".
- **The faster routine is a proposal**, not an owner ruling: "The
  coordinator proposes it as the routine; the owner confirms that, batch by
  batch", and STATUS decision 2 says "ask the owner to confirm it for the
  next batch". It does not claim permanence (but see finding 1).
- **The black Project Manager page** (finding 2).
- **Employer and byline.** `make check-affected` ran `lint-employer-refs`
  and `lint-commits` green. The one commit is authored by the owner, with
  no trailer or tool mention; the diff and PR body name no tool.
- **Commands.** `make check-affected BASE=origin/main`: exit 0, "selected:
  no module, only the lints". `python3 scripts/check_status.py`: 0.
  `python3 scripts/check_doc_freshness.py`: 0.

## Findings

1. **should -- parallel-batch.md cites STATUS for decisions STATUS does
   not record.** "The owner decided the following for that batch
   (`tasks/STATUS.md`, 2026-11-10)" heads five bullets. STATUS's decisions
   record only the `--admin` merge without the PRs' CI (decision 2);
   "at most three waves" appears only in **Next**, and the reviewer's
   scope, one push for findings, and `check-no-engine` in place of the full
   `make check` appear nowhere in STATUS. A reader would take those four as
   owner rulings with a source that does not hold them.
   *Fix:* either add them to STATUS's decision list, if the owner did make
   them, or reword to "For that batch the owner decided the merge rule
   (STATUS decision 2); the coordinator proposes the rest, and all of it as
   the routine, for the owner to confirm".

2. **should -- the black Project Manager page leaves unclear which run
   printed the log, and the inference does not fit it.** "The editor's
   output began with these lines" follows a paragraph where the editor
   (`--path godot -e`) drew normally and the Project Manager did not. If
   the lines came from the working editor run, they do not explain the
   black window. If they came from the Project Manager, the log shows it
   already on the OpenGL path (a GLX context, then GLES), which sits badly
   with "with no project open, nothing pins the renderer". The page does
   hedge ("inferred from the log and not traced"), and it says "measured
   once", so this is not an overclaim of the fix, only of the cause.
   *Fix:* name the run the lines came from (`-p` or `-e`), and if it was
   `-p`, say the cause is unknown rather than offering the renderer pin as
   the likely reason; keep "what worked" as is.

3. **should -- T162 relies on T160 without naming it.** Its third decision
   has `library-check`'s install of the kit zip "from T160" fail on the
   leak line, and its acceptance runs `make library-check`, but Prereqs are
   only T159 and T146, and Files lack `scripts/library_check.py`. Today
   `library-check` does not install the kit zip, so a wave that took T162
   before T160 could not meet that decision. **Next** happens to order
   T160 first, but the task file is what a wave opens.
   *Fix:* Prereqs `T159, T146, T160`; add `scripts/library_check.py` to
   Files. Optionally note that the "forgiven" case in `godot_checked.py`
   stays, so the other gates are unchanged and only these two checks
   start counting the line.

4. **nit -- the project setting's key.** The page writes
   `rendering_method="gl_compatibility"`; `godot/project.godot` line 41 is
   `renderer/rendering_method="gl_compatibility"`. *Fix:* use the full key.

## Not findings

- T154's "the bound per kind" is the STATUS row's own wording.
- The heading "(waves 164 to 169)" counts this wave; it is the batch plus
  this record, as the section says.
- "Nine agents ... load 15-20 on 12 threads" and the 50-minute
  `make check` are the coordinator's observations; not checkable from the
  repository and presented as such.
- T161's prereq change adds T162 only; the STATUS row and the task file
  agree.
- The nemesis note names a patent family and the owner's process, no
  employer and no task; it stays under "Waiting for the owner".
- The `~/teste` project is outside the repository and was the owner's
  manual install; nothing this repository writes went there.
- `verified_on: 2026-11-10` on parallel-batch.md is right: the page gained
  a section measured that day.
