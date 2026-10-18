# Review: wave/53-shooters-and-3d

One fresh context reviewed it, in the main worktree, at the wave's first
commit (one commit on `main`). It wrote nothing in the repository.

**Verdict: merge after fixes.** There were three must-fix findings, all
small text edits:
- two factual errors in the survey, one of them copied into T52's
  acceptance;
- a claim in ADR 0018 that a gate holds invariant 5 when it does not.

The survey's sourcing is otherwise careful. Every number and quote the
reviewer was asked to check is in its source. The ADR is coherent, but it
needed four gaps closed before the owner can decide it:
- where the downloaded assets are loaded from;
- the tier's name;
- the gate's scope;
- how far the assets rule reaches.

All of it is answered in the second commit. The table at the end says how.

## What was reviewed

- `CLAUDE.md`.
- `tasks/STATUS.md`: the wave 53 and wave 52 resuming sections, and the new
  rows.
- ADR 0001 and ADR 0015.
- T36, and the head of `docs/concepts/fighting-game-ai.md`, for the
  pattern.
- The whole diff.
- The scripts `check_renderer.py`, `check_tiers.py`, `check_status.py`,
  `next_wave.py`, and the head of `check_demos.py`.
- The README's tier table, `.gitignore`, the `fighter-sheets` target, and
  `godot/project.godot`.

## What was run

- `make check`: exit 0. The six `SCRIPT ERROR` backtraces are
  `demo_overlays.gd`'s documented planted crash.
- `check_status.py`: 0. `check_acceptance.py`: 0, on 55 task files.
- `check_commit_msg.py` on the commit's message: 0.
- The author and committer is the owner alone. There is no byline, and no
  mention of a tool.
- `next_wave.py`'s own functions, simulated read-only: T50 counted as
  ready. That is finding S1.
- **24 of the survey's 48 references opened** and extracted:
  - Beij & Straatman, McIntosh, Ocio Barriales, both Welsh chapters,
    Couvidou, Walsh, both Rabin chapters, Karlsson, Jack, Straatman 2013,
    Miles;
  - Jaderberg (arXiv), Xu & Verbrugge, van Waveren, Orkin 2006;
  - Butcher & Griesemer, Booth, Isla's Halo 3 slides;
  - Schrum, Polceanu, Wydmuch, Wetzel & Anderson.
- The Godot 4.7 documentation: the renderers page, system requirements,
  Jolt, `VehicleBody3D` and `ProjectSettings`. `./scripts/godot --headless
  --help` for the command-line flags.
- The asset pages: Kenney Blaster and Racing, Quaternius Toon Shooter, and
  KayKit Prototype Bits and Character Animations. All say CC0.
- `https://www.gameaipro.com/`: answers with 200 over https.

## Checked and true

- **Killzone's weights**: 20, "40 if partial cover, 20 otherwise", 20 and
  10. The A\* cost for crossing a friend's line of fire is there too.
- **The Last of Us**:
  - 20 covers with 4 rays each;
  - the 5 m cheat and its quote;
  - two minutes cut to thirty seconds;
  - the 1-2 s timer;
  - the chest point;
  - the angle inversely proportional to distance;
  - the bleeding search map;
  - the coordinator and its roles.
- **The rest**:
  - Ocio Barriales's token quote, verbatim;
  - Welsh's 2-3 s, "peel targets away", the cap of 2-3 investigators and
    "filter back";
  - Crytek's thresholds of 0.25, 0.625 and 1;
  - Jaderberg's 258 and 559 ms, 80% and 48%, 375 ms, and 450K games;
  - Xu & Verbrugge's 0.80, 0.56 and 0.12;
  - Couvidou's quote on breadcrumbs, and the step limit as the difficulty
    setting;
  - Walsh's hearing, his coffin shapes, eight bones, 10 s and 5 s;
  - Rabin's 0.2-0.4 s, and his 10 m against 10.001 m;
  - the quotes from Karlsson, Jack, Orkin, Butcher (20% and 43%), Booth
    (3-5 s and 30-45 s), Isla, Schrum, Polceanu (52.2%), Wydmuch, van
    Waveren, Miles and Wetzel.
- **"48 references, a third only in part"** is correct.
- **ADR 0018's Godot claims match the 4.7 documentation**:
  - the Compatibility renderer's feature table;
  - the hardware floors;
  - Jolt from 4.4, written into new projects from 4.6, and `DEFAULT` being
    GodotPhysics3D;
  - the `VehicleBody3D` note;
  - both command-line flags.
- **The tasks**: T49-T54 each have commands and a `## Manual check`. The
  wave 52 request is covered.

## Findings

Each row is the finding, then what was done about it.

| # | finding | done |
|---|---|---|
| M1 | The Last of Us guarantees **at least one** shooter. It does not cap shooters at one: Ocio Barriales's tokens do that, and he calls a hard cap of one "potentially unbelievable". This was wrong in three places in the survey, in T52's toggle and property, and in T49's line. | Rewritten in all of them. T52's property is now "at most one flanker, and at least one shooting whenever any enemy can see the player". |
| M2 | "258 ms was faster than any of those" is false, because simple reaction is 0.19-0.22 s. | Now: slower than simple reaction, faster than go/no-go, far faster than the humans' 559 ms. |
| M3 | ADR 0018 said `check_tiers.py` holds invariant 5 for 3D examples. It reads only `docs/`. | The ADR now says this half is prose. The Python twin, through `make test-vectors`, is what is gated. T50 names a check if the owner wants it. |
| S1 | Nothing kept T50 blocked, because `next_wave.py` ignores ADR prerequisites. | T50, T51, T52 and T54 are `blocked` in STATUS, and the resume section says so. |
| S2 | The ADR did not say how Godot reads the downloaded assets. | Two routes are written down: inside the project (proposed), or loaded at run time from `build/`. T50 measures the import. |
| S3 | `check_renderer.py`'s scope was misdescribed: `addons/` and `test/` are exempt. | The rule is unchanged, plus a path rule against loading from `game3d/`. The missing 3D types are listed for T50. |
| S4 | A tier named "2-3D" would fail `check_tiers.py`. | The name is left to the owner, and the ADR states the constraint. |
| S5 | An extension test cannot catch a pack's `.png`. | The gate also refuses any tracked file whose sha256 is in the manifest. |
| S6 | It was undecided whether the assets rule reaches the committed 2D art. | This is now listed in the ADR as a question for the owner, and not decided. |
| S7 | itch.io's download links expire. | A manual download with the sha256 still checked. T50 confirms a URL first. |
| S8 | T50 did not measure `demo_overlays.gd` loading a `game3d/` scene. | Added to T50 step 1. |
| S9 | T53 waited for T23, which runs against survey-first. | T53 now needs nothing and rewrites T23 as well as T54. T54 needs T23. |
| S10 | "The position score is in every shipped source" was overstated. | Now limited to the sources on where a bot stands in a fight. |
| notes | Wording fixes, and the Isla 2005 label. | Done: "combat cycle"; Xu & Verbrugge's grid environment; Dishonored 1's breadcrumbs against Dishonored 2's dead-reckoning prototype; Walsh's "for certain events"; "40 if partial cover"; the Isla 2005 entry labelled; https throughout; the ProjectSettings URL added; Direct3D 11 and the shadow passes mentioned. |

## What was done about them

Every finding is answered in the wave's second commit. No finding was
declined. All are text edits; nothing in this wave is code.

- The survey, T49 and T52 now say what The Last of Us does: at least one
  shooter, and a single chosen flanker. T52's property can now be held.
- ADR 0018 no longer claims a gate it does not have. It names:
  - where the assets are read from;
  - a gate that compares sha256s, not extensions;
  - the open question about the 2D art.
- The four 3D tasks that wait on the ADR are `blocked`, so `make wave`
  cannot pick one.
- `make check` was run again after the fixes: exit 0. So was
  `check_links.py`.

Left as they were:
- Laird's venue. The page already says it is not printed on the paper.
- The Metal Gear Wikipedia line, which the reviewer could not re-read. It
  is labelled as an overview and not a developer source.
