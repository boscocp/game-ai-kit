# Review: wave/118-library-in-two-languages

T77: how to use the library, in two languages. `docs/techniques/using-the-library.md`
and its pt-BR, eight `library-step` markers, `scripts/library_check.py`
rewritten to follow them, `scripts/library/stranger.gd` and
`chance_from_python.gd`, `GUIDE_PAGES` in `check_translations_docs.py`,
every technique page's `{#copy}` section in both languages, the README
link, the Makefile description, the task file and the STATUS row.

A fresh context reviewed PR #59 at head 9f651cd, reading only, in a
throwaway worktree.

**Verdict: changes requested, one blocker.** One blocker, four should-fix
findings and four nits.

## What was run

- The task's acceptance commands, all exit 0: `check_translations_docs.py`
  (and `--self-test`), `check_doc_freshness.py`, `make lint-tasks lint-status`,
  `library_check.py` ("the 8 steps ... ran outside the repository") and
  `library_check.py --self-test` (ok). Also `check_readability.py` and
  `check_modules.py`, exit 0.
- Planted by hand: the example file changed (`85.0` to `86.0` in
  `chance_from_python.gd`) -- D9 names both pages; the pt-BR Python block
  changed -- D8 names it. Removing the `unlink` of the planted `aim.py` --
  the self-test fails, as it should. The other two mutations are findings
  3 and 4.
- The archives built with `release.py --build`. `ai_core-0.1.0.zip` holds
  one top folder `ai_core/` (LICENSE, NOTICE, README.md, VERSION, the `.gd` and
  `.uid` files), so `unzip -d addons/` gives `addons/ai_core/`. The wheel
  carries `dist-info/licenses/LICENSE` and `NOTICE`. The addon names each
  page's `{#copy}` line gives match every manifest's `depends_on` (only
  `ai_perception`, `ai_rts_core` and `ai_search` name `ai_core`, and they are
  the three that need it).
- pt-BR read against English paragraph by paragraph. It is faithful. Code
  and code comments stay English, as the glossary says they must.

## Findings

1. **Blocker -- the page's first step does not work for a stranger, and
   the check does not take it.** `using-the-library.md:61-66` (pt-BR
   `:62-68`) tells the reader to run `make release`. `Makefile:965` is
   `release: export`, and `Makefile:958` is `export: import`. `export.py:97`
   refuses with "no release template ... run `make bootstrap`". Even
   `import` goes through `scripts/godot`, which exits 2 at `scripts/godot:53`
   ("toolchain missing ... run 'make bootstrap'"). So on a fresh clone the
   page's step 1 needs the pinned engine and its export templates
   installed on the large disk (invariant 8's layout). It then exports and
   starts the whole menu game and needs a clean tree, and none of that is
   on the page. `library_check.py:146-147` runs `release.py --build`
   instead, which needs none of it. So the step marked `release` is not the
   step the check takes, which is the gap step 2 of the task exists to
   close. Reproduce: in a clone with no `toolchain/`, `make release`, and it
   exits 2 before any zip is written. Fix: print the command the check runs
   (`python3 scripts/release.py --build`, whose zips land in `dist/`), or
   have the check run what the page prints.
2. **Should-fix -- the printed commands do not run as printed, and nothing
   notices.** The check matches step *names*. It does not run the commands
   under them, yet `:16-19` says "Every step on it is one `make library-check`
   takes".
   - `:79-81`: `cd my_game` then `unzip ai_core-0.1.0.zip`. The zip is in
     the checkout's `dist/`, not in `my_game`, so this fails with
     "cannot find or open".
   - `:145-146`: `pip install --no-index <wheel>` with a relative wheel path,
     while the check (`library_check.py:190`) adds `--no-deps`. If the wheel
     ever declares a dependency, the page's command fails and the check
     stays green.
   - `:155-159`: the Python block is "run from your project's folder", but
     the page gives no file name and no command. That leaves it unclear
     whether the reader runs it with `.venv/bin/python` (which `.venv`, made
     where?) or with `python3`, which has no `gameaikit`. The check writes it
     to `my_training.py` and runs it with the venv's interpreter from the
     project (`:200-202`). Print that.
   Reproduce: follow `:79-81` in a fresh folder beside a checkout.
3. **Should-fix -- a script error after the frame wait hangs the check for
   300 s, then crashes with a traceback.** `stranger.gd:29-30` awaits a frame
   and then reads `walker.route`. If the example's field is renamed (the
   page's block and the file are held equal, so this is an ordinary edit),
   the read is a SCRIPT ERROR. The coroutine aborts, `quit` is never called,
   and Godot keeps running. `library_check.py:231-232` then raises
   `subprocess.TimeoutExpired` after 300 s, uncaught, with exit 1 and no
   `library-check:` line saying what failed. Reproduce: in
   `godot/test/ai_search/route_example.gd`, rename `route` to `steps` (both
   lines), then `time python3 scripts/library_check.py`. Measured: 5 min 7 s
   and a traceback. Fix: catch the timeout as a finding, use a much shorter
   limit, and/or read the field with `get("route")` and check for null
   before using it.
4. **Should-fix -- the marker requirement has no planted case
   (invariant 4).** The docstring (`:23-24`) and `stranger.gd:11-12` say the
   run must exit 0 *and* print both markers, because a `-s` script error
   still exits 0. With `library_check.py:235`'s `or missing` deleted, the
   self-test still passes. Measured: "self-test: ok" in 25 s. Every planted
   Godot fault also fails the exit code, so nothing proves the markers are
   read. Plant a case that exits 0 without a marker, for example a runner
   that quits 0 early. Otherwise the half the docstring sells as the reason
   for the design goes unenforced.
5. **Should-fix -- terms kept in English that the glossary does not
   define.** The pt-BR pages italicise *wheel*, *cache*, *release* and
   *tiles* as English terms: `using-the-library.pt-BR.md:32,42,94,145,237`,
   and *wheel* in every `{#copy}` line this PR added, 25 lines in total.
   None of the four is in `glossary.pt-BR.md`. Under the convention
   (glossary `:14-17`, and the owner's 2026-10-26 scope), every italicised
   English term is one the glossary lists and defines. Also, the
   glossary's `addon` entry (`:48`, "uma pasta em `godot/addons/` que você
   copia") is now half the story. Reproduce:
   `grep -n -iw "wheel\|cache\|release\|tiles" docs/techniques/glossary.pt-BR.md`
   finds nothing. No gate catches this, which may deserve its own line for the
   owner.
6. **Nit -- "the check below runs that one"** (`:227`, pt-BR `:233`).
   There is no check below on the page. Write "`make library-check` runs
   that one".
7. **Nit -- "the nine `Gak` names above, which your code extends"**
   (`:230`). ADR 0024 `:31` says nothing extends `GakGridGraph`, and
   `GakGameDomain` is copied. The page's own table says so.
8. **Nit -- `0.1.0` is written into the commands** (`:80-81,146,191`), but
   `invalidated_if` names `release.py`, ADR 0024 and `.godot-version`. It
   does not name `python/pyproject.toml`'s `version`, so a version bump
   leaves the page stale with nothing saying so.
9. **Nit -- the `aim` planted case names its fault by a three-letter
   substring** (`library_check.py:321`). It passes for the right reason
   today (removing the unlink fails it). Still, `"aim" in line` is met by
   any line holding "claim" or "maim". The wave already fixed one
   path-name coincidence of this kind, so match `'aim'` or
   `gameaikit.utility` instead.

## For the owner

- The PR's five decisions, unratified: (1) 0.1.0 promises only the nine
  `Gak` names, any other name free below 1.0. ADR 0024 says the prefixed
  names are a promise but says nothing about the rest, so the "below 1.0"
  sentence is new policy. (2) The second example in `scripts/library/`,
  with no gdUnit case. (3) The check unzips all three addons and imports
  once, while the reader imports twice. (4) `GUIDE_PAGES` as a third kind of
  page. (5) `DecisionPolicy` replaced by the nine names.
- Finding 1 needs a choice of public command: either the page prints
  `release.py --build` (no Godot, no templates, no executable), or
  `make release` stays the documented way and the page says it needs
  `make bootstrap`.
- Whether the glossary convention (finding 5) should get a gate, since it
  is prose today.
- The task's manual check is yours: follow the pt-BR page from a fresh
  Godot project on a machine that never cloned the repository. Findings 1
  and 2 predict where it will break today.
- `CLAUDE.md:92` still says "the wheel and two addons". The PR says so
  itself.

## Applied

Every finding was applied on the branch, each as below, in one commit after
9f651cd.

1. **The archives step.** The page now prints the command the check runs,
   `python3 game-ai-kit/scripts/release.py --build --output library`. It
   needs Python and git only: measured, it builds every zip and the wheel
   with no Godot involved. `make release` is mentioned as the full release,
   with what it needs (`make bootstrap`, the export templates, a clean tree)
   and the reason a library user does not need it. Which command is public
   is listed for the owner in the PR.
2. **The commands run as printed.** The page states its layout: one folder
   holding `game-ai-kit/` and `my_game/`, with `godot` meaning the pinned
   engine. Every command uses paths from there (`library/dist/...`,
   `my_game/addons/`, `--path my_game`). The Python block has a file name,
   `my_game/my_training.py`, and its own run command,
   `cd my_game && ../.venv/bin/python my_training.py`. `--no-deps` is gone
   from the check, and the page says why `--no-index` is enough: a
   dependency would make the printed command fail, and the check with it.
   `library_check.py` now builds that folder (`game-ai-kit` a link to the
   checkout, a blank `my_game`, a `godot` shim on the PATH) and runs every
   bash block under each step with `bash -e`, in the page's order. It saves
   the Python block and the examples where the page says. So the check
   also takes the reader's two imports, not one. A misprinted unzip path is
   a planted case, and it fails naming the step `unzip`.
3. **No hang.** `stranger.gd` takes `-- route` or `-- infer`, reads the
   example's field with `get()` and checks its type, so a renamed field is
   a finding rather than a script error: "the route example holds no
   route: <null>". Every way out calls `quit`. The check also bounds each
   run at 60 s (240 s for a command block) and reports a timeout as a
   finding. Reproduced: renaming `route` to `steps` in
   `route_example.gd` now fails in 3 s, with one `library-check:` line
   and exit 1.
4. **The marker has a planted case.** A runner that quits 0 having
   printed nothing must fail, naming the marker it lacks. Measured: with
   `or MARKERS[step] not in output` deleted, the self-test fails on that
   case.
5. **Glossary.** `docs/techniques/glossary.pt-BR.md` gains *release*,
   *wheel*, *cache*, *tile* / *tileset*, and *template* (de exportação),
   which the reworded page now uses. Its `addon` entry says the zip from a
   release, or the copy from a clone.
6. "the check below" now reads "`make library-check` runs that one".
7. "which your code extends" now reads "the ones your code names as a
   type ... breaks every game that uses it", as ADR 0024 puts it.
8. `invalidated_if` names `python/pyproject.toml`'s version. The page
   also says that 0.1.0 is the number in the commands. A version bump
   makes the printed unzip fail, so the check notices.
9. The `aim` case matches `cannot import name 'aim'`. The NOTICE case
   matches `carries no NOTICE`.

Runs after the fixes: `library_check.py` (the 8 steps, green, about 11 s),
`library_check.py --self-test` (ok, about 36 s, under the 120 s limit
of `lint-selftests`), `check_translations_docs.py` and its self-test,
`check_doc_freshness.py`, `make lint-tasks lint-status`, and `make
check-affected BASE=origin/main`, recorded in the PR.

Not changed: `CLAUDE.md:92`, left for the owner.
