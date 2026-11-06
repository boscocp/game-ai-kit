# Review: before the repository opens (T112, wave 143)

Reviewed 2026-11-06, on `main` at `f6f9c2c`, by a context that wrote none
of the repository and read it cold: as someone who arrives from a search,
wants one technique, and has never heard of a wave. This is a report, not
a rewrite (T112's first decision). Fixes smaller than a sentence landed
with it; everything larger is a task, named below. Making the repository
public, turning CI back on and publishing are the owner's, and are listed
as recommendations at the end, never done here.

Severity: **high** -- a stranger hits it on first contact, or it cannot be
undone once the repository is public; **medium** -- wrong or missing, and
someone will trip on it; **low** -- polish.

## What was run

| command | exit | note |
|---|---|---|
| `make check` | 0 | run alone, on the clean `f6f9c2c`. Nine `SCRIPT ERROR` lines, every one from a planted `gdscript://` script (`demo_overlays.gd`'s crashing step, the abstract-class cases); none from a real file. No signal 11 |
| `make library-check` | 0 | "the 8 steps of using-the-library.md ran outside the repository"; no `SCRIPT ERROR` |
| `make release` | 0 | 15 addon zips, the wheel and the Linux executable into `dist/`, `check_license.py` over them clean |
| `python3 scripts/check_no_employer_refs.py` (tree and history) | 0 | the term list was present (copied by `make worktree-setup`); nothing printed, so no `E0` note: it checked |
| the same list over every ref's commit messages and identities | 0 findings | a scratch script reusing the gate's own matcher on `git log --all` (finding 9) |
| a secret-shaped scan of every blob on every ref, and every message | 0 | 12,526 blobs; AWS, GitHub, Anthropic, OpenAI, Hugging Face, Slack and Google keys, private-key blocks, JWTs, URLs with a password, `password = "..."` shapes. Two hits were the gates' own planted fixtures (`selftest@example.invalid`), not secrets |
| every third-party URL the repository names, downloaded and hashed | 14 of 18 | finding 12: the manifests' 16 URLs and `LICENCES.md`'s two archives; the four kenney.nl ones answered 403 |
| invariant 11 over the history: `git log --all` for a `Co-Authored-By:` trailer, a "Generated with" line or the robot emoji | 0 | every ref, so the finished branches that become public with the repository (finding 7) are covered too |
| referenced-only art in history, by content hash and by path | 0 | no Bos Wars sheet, fighter sheet or 3D pack file was ever committed (ADR 0015, 0018, 0020 hold over the whole history) |

`make release` has no publishing step to switch off: it builds into `dist/`
and runs `check_license.py` over what it built. Nothing was uploaded
anywhere.

## What was read

One line per item T112 lists, with what came of it.

- `README.md` and `README.pt-BR.md`, as a first page: findings 1, 2 and 11.
- Every technique page, both languages (19 and their twins, plus
  `ai_core.md`, `catalogue.md` and the glossary): the stale catalogue
  lines (finding 3) and `ai_llm`'s "No demo yet" (finding 2); nothing
  else found.
- The library guide, `using-the-library.md` and its twin (T77): nothing
  found. `make library-check` follows it outside the repository and
  passed, and its Python 3.12 line is the one the README should match.
- Every ADR's status line: finding 10; the other 23 are accepted, dated
  and name their task.
- The invariants table against the gates: finding 5; every other row's
  gate exists and is reached from `make check`, CI or the hooks.
- LICENSE, NOTICE and the third-party art: findings 4 and 12; LICENSE is
  Apache-2.0 at the root, in every addon and in `python/`, as
  `lint-license` holds.
- Invariant 10 over the history: nothing found; the gate's gap is
  finding 9.
- Secrets in the history: nothing found.
- Stale worktrees and remote branches: finding 7.
- The size of the history: finding 8, nothing found.
- Invariant 11 over the history: nothing found.
- What a community needs: `CONTRIBUTING.md`, templates, a code of
  conduct: finding 6.
- How pt-BR and en are kept in step: held by `lint-translations-docs`
  (`translation_of` hashes, which this wave's catalogue lines had to
  update) and `lint-glossary`; nowhere written for a contributor, which
  is in finding 6 and T144.
- What tier 1 means for a contributor's machine: the README's tier table
  is clear for a reader, but says "Python 3" where 3.12 is needed
  (finding 2), and nothing tells a contributor which tier a change needs
  (`make check` needs tier 2): finding 6 and T144.

## Findings

### 1. A stranger's `make bootstrap` writes to the author's disk -- high

`Makefile:21` defaults `TOOLCHAIN` to `/mnt/games/gamedev/toolchain`, and
`scripts/godot:41`, `scripts/llm:26`, `scripts/artgen:22`,
`scripts/export.py:64` and `scripts/check_disk_layout.py:99` default
`GAK_TOOLCHAIN` to the same path. On anyone else's machine that folder
does not exist and is not theirs to create. The README's "Getting
started" (`README.md:189`) says `make bootstrap` "downloads the pinned
Godot ... to the large disk" and never says which disk, or how to choose
one.

Two more steps make it worse:

- the two knobs are different names. `make bootstrap TOOLCHAIN=~/x`
  installs into `~/x`, and the next `make menu` looks in `/mnt/games`
  again, because `scripts/godot` reads `GAK_TOOLCHAIN` and the Makefile
  passes it only to `lint-disk-layout` (`Makefile:47`). CI works only
  because it sets both (`.github/workflows/ci.yml:80`, `:89`).
- `make check` refuses any machine where Godot has ever run normally.
  Measured: `check_disk_layout.py --home <a home holding
  .local/share/godot/>` prints `D1 ... exists on the small disk (0 bytes)`
  and exits 1. A contributor who has the Godot editor installed has that
  folder, and invariant 8 -- the author's own disk layout -- fails their
  first `make check` for something this repository did not write.

The README's tier table does not say which systems `make bootstrap`
supports (Linux x86_64, and Windows through Git Bash, `scripts/bootstrap.sh:34`; on macOS
it would fetch the Linux build), and
`docs/howto/windows.md` is linked from nowhere a stranger starts.

Task: **T143**.

### 2. The first page says things that stopped being true -- high

- `README.md:12-14`: "the first vertical slice is complete -- a board,
  four searches, a STRIPS planner and two trained regressions". The table
  ten lines below lists 19 techniques and 16 demos.
- `README.md:66-69`: `ai_llm`'s "local runtime (T93) and the text game
  that uses it (T94) are still to come". Both landed; the table at
  `README.md:31` links `make demo-talk`, and `README.md:93` documents
  `make llm-serve`.
- `README.md:106-175`: "What you will see" describes 5 of the 16 demos,
  and ends "Recordings of all five are still to be made."
- `README.md:90` and `README.pt-BR.md:90`: tier 1 is "Python 3 (already on
  Linux and macOS)". `python/pyproject.toml:19` requires 3.12, and the
  library guide says so (`docs/techniques/using-the-library.md:155`);
  macOS's own `python3` is older.
- `README.md:68`, `:101` and `:126` (`Until T27 this was make run`): task ids
  a stranger cannot resolve.
- `docs/techniques/ai_llm.md:48-49` and `ai_llm.pt-BR.md:52`: "No demo
  yet: the text game that uses it is T94". The page's own
  `invalidated_if` (`ai_llm.md:8`) names exactly this -- "T94's game lands
  and this page does not name it" -- and `check_doc_freshness.py` reads
  only the date, so nothing caught it.
- The README links neither `CONTRIBUTING.md` nor the Windows how-to.

Task: **T142**.

### 3. Thirteen technique pages promised a catalogue that exists -- medium, fixed here

Each of `ai_adversarial`, `ai_behaviour`, `ai_fuzzy`, `ai_opponent`,
`ai_perception`, `ai_planning`, `ai_rts_core`, `ai_search`,
`ai_steering`, `behaviour_cloning`, `learned_evaluation`, `menace` and
`racing_driver` ended its "Where to watch it" with "the catalogue (T76,
coming)", in both languages. T76 landed; the catalogue is
`docs/techniques/catalogue.md`. Each line is now a link to the page's own
anchor there, as `ai_llm.md` already did. Twenty-six lines, none longer
than the phrase it replaced.

### 4. NOTICE credited all the committed art to Kenney -- medium, fixed here

`NOTICE:17-19` (and `python/NOTICE`, which must match it byte for byte)
said the pictures under `godot/assets/` "are CC0 1.0, from Kenney". The
walking sheets are Shade's (Puny Characters) and the fighters' strips are
cut from Puffolotti's Mustermann 2, both on OpenGameArt, as
`godot/assets/LICENCES.md:34-50` says correctly. CC0 asks for no credit,
so this was never a licence breach, but a credit that names the wrong
artist is worse than none. The sentence now names all three.

### 5. The invariants table understates invariant 13 -- low, fixed here

`CLAUDE.md:30` said invariant 13's gate is "**none yet** --
`check_demos.py`, named in T21". `scripts/check_demos.py` exists and runs
in `make check` as `lint-demos` ("every example has a target, a scene, a
legend and its decision"). The row now says it is half held by it and by
`godot/test/menu/demo_overlays.gd`, which is what the paragraph under
invariant 13 already claimed. Every other row
was checked against the Makefile: each gate it names exists and is
reached from `make check`, `lint-pr-message` (CI) or the hooks.

### 6. CONTRIBUTING.md is written for the author's own agents -- high for a community, not for opening

`CONTRIBUTING.md` exists, which T112's notes did not expect, and it is
the wave flow, not a guide for an outsider:

- `:8`, `:12`: a contributor must cut `wave/07-a-slug` and write
  `docs/reviews/07-a-slug.md` -- wave numbers are exactly what T112 says
  an outsider should not need;
- `:6-13` assumes push access to this repository (`make wave-start`
  branches here, `make wave-merge` merges); a fork's pull request is not
  described;
- `:10`: `make check`, which needs tier 2 and runs for a long time, where
  the project itself now asks a wave for `make check-affected`;
- `:80-82`: "a CI step ... reads the PR's title and body" -- CI is off
  until the repository opens;
- nothing on how a pt-BR page is kept in step with its English one
  (`check_translations_docs.py`, the glossary), or which tier a
  contributor's machine needs for which change.

There is no issue template, no pull request template, no code of conduct
and no `SECURITY.md` (`.github/` holds only `workflows/`). The code of
conduct is the owner's choice, so it is not written here.

Task: **T144**, after the owner's choice.

### 7. 105 stale branches on the remote -- medium, the owner's

`origin` has 106 heads. Every one but `main` is finished: 66 are wholly
contained in `main` (waves 5 to 62, merged before pull requests, and 7
heads named `worktree-agent-*`), and 39 are the heads of squash-merged
pull requests (#1 to #92). No pull request is open. None holds anything the
scans above found. Publishing them is harmless and permanent in forks;
deleting them first is cleaner, and is the owner's (no branch was deleted
here). The repository's `deleteBranchOnMerge` is `false`, which is how
they piled up, and its description and topics are empty -- the first
line a search result shows.

Locally, `git worktree list` shows 88 worktrees under
`.claude/worktrees/`. They are gitignored and never published; they are
housekeeping, not an opening risk. `check_disk_layout.py` notes 17 of them
still share the pre-T83 `user://`.

### 8. The history is small and clean -- no finding

772 commits on all refs (365 on `main`), 8.6 MB packed, 13,497 objects.
The largest blob ever committed is `godot/game/maze/values.json` at
0.94 MB; nothing is a binary someone else made beyond the CC0 pictures
`LICENCES.md` lists. No rewrite is needed.

Author and committer on every commit are one name, with one personal
address, plus GitHub's own identity on the 92 squash merges. That address
becomes public with the history; it is the owner's to keep or to replace
with GitHub's no-reply address for future commits.

### 9. The employer scan reads messages on `main` only -- medium

`scripts/check_no_employer_refs.py:254` reads commit messages and
identities with `git log`, which follows `HEAD`, while the blob scan just
below uses `rev-list --all`. 407 commits exist only on the other remote
branches (finding 7). This review ran the gate's own matcher over
`git log --all` and found nothing, so it does not block today; but the
gate does not hold what its docstring says ("every commit"). Separately,
the untracked list holds a single term; whether internal project or
client names belong in it is the owner's to judge, without writing them
anywhere.

Task: **T145**.

### 10. ADR 0023 is still "proposed" -- low, the owner's

`docs/adr/0023-a-local-llm-is-llama-cpp-pinned-by-tag.md:3`: "proposed ·
2026-10-29 (T93, wave 111; the owner confirms in review)". T93, T94 and
T133 have built on it since, and the README documents its commands. Every
other ADR's status line is `accepted` or `accepted, amended`, with a date
and the task that decided it.

### 11. Small things a stranger notices -- low

- `Makefile:81`: `wave-merge`'s comment says "as desk-panel does", a
  project a reader cannot look up.
- `README.md:93`'s tier 3 cell is one 90-word sentence holding two
  different features (the LLM and the art generator).
- `tasks/STATUS.md` is 3,569 lines and `docs/reviews/` holds 142 records;
  both are honest working history, and nothing on the first page says a
  stranger can ignore them. A line in T142's README pass is enough.

### 12. Third-party sources, re-downloaded -- low

All eleven Bos Wars sheets (`godot/game/rts/art_sources.json`, from
Debian's source archive), both Mustermann 2 sheets
(`godot/game/fighting/sprites.json`, OpenGameArt) and Shade's
`puny-characters.zip` (`godot/assets/LICENCES.md:35-36`, from
OpenGameArt) downloaded and matched their sha256 today. The four
walking sheets committed from that archive match its members byte for
byte. `opengameart.org`'s two pages, `boswars.org` and the
Z-Image-Turbo model card answer.

`kenney.nl` answered 403 to every plain request from this machine -- the
three 3D archives and the racing kit's page in `godot/game3d/assets.json`,
and the five pack pages and `kenney_racing-pack.zip`
(`LICENCES.md:28-30`) alike -- so they could not be re-verified here,
and no way round the refusal was tried. The main
checkout's own downloads of two of the three archives
(`build/assets-3d/`) match the manifest; `kenney-racing-kit` was not on
disk. A person in a browser can confirm the rest; it is in the manual
check.

## Blocks opening, and does not

**Blocks opening** (the review's proposal; the owner decides item by item):

1. **T143** -- a stranger cannot bootstrap: the toolchain defaults to the
   author's disk, two names for one setting, and `make check` refuses a
   machine with Godot on it (finding 1).
2. **T142** -- the first page contradicts itself and the demos (finding 2).
3. **T144 and a code of conduct** -- if the opening invites contributions,
   the contributing guide must be one an outsider can follow (finding 6).
   If it opens read-only first, this moves below the line.

**Does not block:**

- secrets in history: none found;
- invariant 10 over the history: none found by hand; T145 makes the gate
  itself cover it, recommended before opening but not blocking (finding 9);
- third-party art: never committed; every hash this machine could
  download matches, and the four kenney.nl ones are in the manual check
  (finding 12);
- the stale branches (finding 7): harmless, cleaner gone first;
- NOTICE, the catalogue lines, the invariants row: fixed here
  (findings 3 to 5);
- ADR 0023 (finding 10), the small things (finding 11).

## Follow-up tasks

| id | title | size |
|---|---|---|
| T142 | The first page says what is true today | S |
| T143 | A stranger's toolchain goes where they say | M |
| T144 | Contributing, for someone outside the waves | M |
| T145 | The employer scan reads every branch's messages | S |

## Manual check

The owner reads the blocking list and decides, item by item. And in a
browser: the five Kenney pack pages in `godot/assets/LICENCES.md` still
show CC0; `kenney_racing-pack.zip` from the Racing Pack page still has
the sha256 `LICENCES.md:29-30` names; and `make assets-3d` on a machine
without `build/assets-3d/` still downloads the racing kit whose sha256
`godot/game3d/assets.json` names.
