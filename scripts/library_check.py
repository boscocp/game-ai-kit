#!/usr/bin/env python3
"""Follow the page on using the library, where a stranger would (T64, T77).

The release's own self-test proves what is *in* each archive. This proves
the archives *work* away from this repository, which is the only place a
library is used, and it does so by doing what
`docs/techniques/using-the-library.md` -- the page a person follows -- says,
in a throwaway folder outside the tree. The folder holds what the page's
reader has: `game-ai-kit/` (a link to this checkout), `my_game/` (a blank
Godot project), and `godot` on the PATH, standing for the pinned engine.

Each step the page marks `<!-- library-step: name -->` is taken in the
page's order. Every ```bash block under it runs **as printed**, from that
folder, and then the check does what the page says the reader does without
a command:

  release  (its block builds `library/dist/`)
  unzip    (its block), then every addon unzipped is in
           `my_game/addons/ai_<name>/` and nothing else is new in `my_game/`
           -- the zips are laid out `addons/ai_<name>/` (T149), so an unzip
           into `my_game/addons/` would nest them, and Godot would still
           find every `class_name` there
  import   (its block)
  route    the page's route example saved in `my_game/`, and
           `scripts/library/stranger.gd -- route` adds it to the tree
  wheel    (its block), then a probe imports a technique and the registry
           from site-packages, with the repository nowhere on the path
  train    the page's Python block saved as `my_game/my_training.py`
           before its block runs it
  infer    (its block), then `ai_learning` is in `my_game/addons/ai_learning/`
           as `unzip` checks, the model example saved in `my_game/`, and
           `stranger.gd -- infer` adds it to the tree
  kit      (its block), the kit zip unzipped into a second blank project,
           `my_kit/`, as the store delivers it; then nothing new in its root,
           its `project.godot` still the reader's, its `addons/` holding
           exactly the addons that have a zip of their own, no `class_name`
           declared twice, and the route example run on the kit's own
           files (T160); then every script in it loaded, as many as its
           `addons/` holds and not 0, with nothing still alive when the
           engine quits (T162)
  licence  every zip and the wheel carry LICENSE and NOTICE

A `stranger.gd` run must exit 0 *and* print its marker: a script error
inside a `-s` script still exits 0 (CLAUDE.md). It is bounded by a timeout,
reported as a finding, should Godot be left running.

The check refuses a page whose steps are not exactly `STEPS` below, in
either language: a step on the page the check does not take is a promise
nobody keeps, and one the check takes that the page does not say is a
test of something no reader does. Inside `godot/` every `class_name` is
already registered, so this is the portability proof the technique pages'
own gdUnit cases cannot be.

Why `--self-test` exists
------------------------
To prove the check refuses, and refuses for the reason planted. It first
follows the untouched page, which must pass: a Godot that does not start,
or a venv with no pip, would otherwise fail every planted case for the
wrong reason and the self-test would go green. Then, each named in what
it prints: `grid_graph.gd` out of `ai_core`'s zip (`GakGridGraph`);
`utility/aim.py` out of the wheel's install (`'aim'`); `NOTICE` out of a
zip; a runner that quits 0 having printed nothing (the marker it lacks);
an unzip command pointing at a zip that is not there, and one unzipping
into `my_game/addons/` as the page said before T149 (the step `unzip`);
`ai_learning` unzipped there too, as the page's `infer` said until T160;
and, in the step `kit`: the kit unzipped into `my_kit/addons/`, a kit
without `ai_core`, one without `grid_graph.gd`, one carrying `docs/`,
one carrying a `project.godot` (unzip refuses to replace the reader's),
the same unzipped with `-o` (the check sees the reader's project gone),
one with an addon no zip of its own has, one
whose `ai_bandit` declares `GakXorshift` again, and one carrying
`check_published.LEAKING`, three scripts that leave one alive at exit;
a kit `addons/` with no script, which the load must refuse rather than
pass on nothing; and a page with a step the check does not
take, or without one it does.

Exit codes
----------
0   the page's steps all ran outside the repository
1   a step failed, or the page and the check disagree (what is printed)
2   wrong usage, or the page has a step with nothing to run

Usage
-----
    library_check.py
    library_check.py --self-test
"""

from __future__ import annotations

import argparse
import dataclasses
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from check_published import LEAKING, load_every_class

REPO = pathlib.Path(__file__).resolve().parent.parent
GODOT = REPO / "scripts" / "godot"
STRANGER = REPO / "scripts" / "library" / "stranger.gd"
PAGES = (REPO / "docs" / "techniques" / "using-the-library.md",
         REPO / "docs" / "techniques" / "using-the-library.pt-BR.md")
#: What `stranger.gd` prints when an example decided as the page says.
MARKERS = {"route": "LIBRARY-CHECK: the route goes round the wall",
           "infer": "LIBRARY-CHECK: the model Python wrote decides in Godot"}
#: The steps this check takes, in the page's order. The page must name
#: these and no others.
STEPS = ("release", "unzip", "import", "route", "wheel", "train", "infer", "kit", "licence")
#: The kit's zip, every addon in one, as the store delivers it (T149).
KIT_ZIP = "game-ai-kit-addons-*.zip"
#: What the reader's blank projects hold before anything is unzipped.
BLANK_PROJECT = "config_version=5\n\n[application]\n\nconfig/name=\"A stranger's game\"\n"
CLASS_NAME_RE = re.compile(r"^class_name\s+(\w+)", re.M)
#: Long enough for an import on a loaded machine; short enough that a
#: Godot left running by a script error is a finding, not a stalled gate.
BLOCK_SECONDS = 240
RUN_SECONDS = 60
STEP_RE = re.compile(r"^<!--\s*library-step:\s*([a-z-]+)\s*-->$", re.M)
EXAMPLE_RE = re.compile(r"^<!--\s*example:\s*(\S+)\s*-->$", re.M)
BASH_BLOCK_RE = re.compile(r"^```bash\n(.*?)^```$", re.M | re.S)
PYTHON_BLOCK_RE = re.compile(r"^```python\n(.*?)^```$", re.M | re.S)
PROBE = (
    "from gameaikit import techniques\n"
    "from gameaikit.utility import aim\n"
    "import gameaikit, pathlib\n"
    "assert 'aim-choice' in techniques.available(), 'the registry lists the kit'\n"
    "assert 'site-packages' in pathlib.Path(gameaikit.__file__).parts, gameaikit.__file__\n"
    "head = aim.Zone('head', 2.0, (0.0, 1.65), [(-0.12, 1.5, 0.12, 1.8)], 1.0)\n"
    "torso = aim.Zone('torso', 1.0, (0.0, 1.175), [(-0.2, 0.85, 0.2, 1.5)], 1.0)\n"
    "assert aim.choose([head, torso], 0.5).aimed == 1, 'far away, the torso'\n"
    "print('LIBRARY-CHECK: the wheel answers from site-packages')\n"
)


class Unfollowable(Exception):
    """The page has a step with nothing to run: exit 2, not a finding."""


# --- the page ---------------------------------------------------------------


def page_steps(text: str) -> dict[str, str]:
    """Each marked step's name and its text, up to the next step's marker."""
    marks = list(STEP_RE.finditer(text))
    ends = [mark.start() for mark in marks[1:]] + [len(text)]
    return {mark.group(1): text[mark.end():end] for mark, end in zip(marks, ends)}


def step_findings(label: str, text: str) -> list[str]:
    """The page's steps against the ones this check takes, both ways."""
    named = list(STEP_RE.findall(text))
    findings = [f"{label}: the page has a step {name!r} this check does not take"
                for name in named if name not in STEPS]
    findings += [f"{label}: this check takes the step {name!r} and the page does not say it"
                 for name in STEPS if name not in named]
    if not findings and named != list(STEPS):
        findings.append(f"{label}: the page's steps are {named}, and the check takes {list(STEPS)}")
    return findings


def example_of(step: str, text: str) -> pathlib.Path:
    """The file the step's `<!-- example: … -->` block names."""
    found = EXAMPLE_RE.search(text)
    if found is None:
        raise Unfollowable(f"the step {step!r} has no example block")
    return REPO / found.group(1)


# --- the folder the reader works in ---------------------------------------------


@dataclasses.dataclass(frozen=True)
class Planted:
    """One fault the self-test plants; the empty one is the untouched page."""

    zip_member: str = ""
    kit_folder: str = ""
    kit_extra: tuple[tuple[str, bytes], ...] = ()
    installed_file: str = ""
    silent_runner: bool = False


@dataclasses.dataclass(frozen=True)
class Place:
    """The reader's folder: the clone, two projects, and a PATH holding `godot`."""

    root: pathlib.Path
    environment: dict[str, str]

    @property
    def project(self) -> pathlib.Path:
        return self.root / "my_game"

    @property
    def kit_project(self) -> pathlib.Path:
        return self.root / "my_kit"

    @property
    def dist(self) -> pathlib.Path:
        return self.root / "library" / "dist"


def reader_folder(root: pathlib.Path) -> Place:
    """A folder as the page assumes it: a clone beside two blank Godot projects."""
    (root / "my_game" / "addons").mkdir(parents=True)
    (root / "my_game" / "project.godot").write_text(BLANK_PROJECT)
    (root / "my_kit").mkdir()
    (root / "my_kit" / "project.godot").write_text(BLANK_PROJECT)
    (root / "game-ai-kit").symlink_to(REPO, target_is_directory=True)
    tools = root / "bin"
    tools.mkdir()
    (tools / "godot").write_text(f"#!/bin/sh\nexec '{GODOT}' \"$@\"\n")
    (tools / "godot").chmod(0o755)
    environment = dict(os.environ, PATH=f"{tools}{os.pathsep}{os.environ.get('PATH', '')}")
    return Place(root, environment)


def run_blocks(step: str, text: str, place: Place) -> list[str]:
    """Every ```bash block of the step, as printed, from the reader's folder."""
    for block in BASH_BLOCK_RE.findall(text):
        try:
            # No stdin: an unzip asking whether to replace a file reads
            # end-of-file, answers no, and the check sees what stayed.
            ran = subprocess.run(["bash", "-e", "-c", block], cwd=place.root, env=place.environment,
                                 stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                 timeout=BLOCK_SECONDS)
        except subprocess.TimeoutExpired:
            return [f"step {step!r}: its commands did not finish in {BLOCK_SECONDS} s"]
        if ran.returncode != 0:
            said = (ran.stderr or ran.stdout).strip().splitlines()[-3:]
            return [f"step {step!r}: its commands, as printed, fail (exit {ran.returncode}): {said}"]
    return []


# --- what the reader does without a command ----------------------------------------


def without_member(archive: pathlib.Path, member: str) -> None:
    """Rewrite `archive` with `member` taken out -- a folder's, when it ends in `/`: a planted fault."""
    def kept(name: str) -> bool:
        return not name.startswith(member) if member.endswith("/") else name != member
    with zipfile.ZipFile(archive) as source:
        entries = [(entry, source.read(entry)) for entry in source.infolist() if kept(entry.filename)]
    with zipfile.ZipFile(archive, "w") as copy:
        for entry, data in entries:
            copy.writestr(entry, data)


def plant_in_release(place: Place, planted: Planted) -> list[str]:
    """After `release`: the planted zip fault, if any. Nothing to report."""
    if planted.zip_member:
        owner = planted.zip_member.split("/")[1]
        for archive in place.dist.glob(f"{owner}-*.zip"):
            without_member(archive, planted.zip_member)
    for archive in place.dist.glob(KIT_ZIP):
        if planted.kit_folder:
            without_member(archive, planted.kit_folder)
        with zipfile.ZipFile(archive, "a") as bundle:
            for name, data in planted.kit_extra:
                bundle.writestr(name, data)
    return []


def unzipped_findings(place: Place) -> list[str]:
    """After `unzip`: each addon in `my_game/addons/ai_<name>/`, and nothing else new.

    Godot registers a `class_name` wherever in the project its script sits,
    so a zip unzipped one folder too deep -- `my_game/addons/addons/ai_core/`
    -- would still pass every later step. The place is checked here instead.
    """
    findings = root_findings("unzip", place.project, {"addons", "project.godot"})
    findings += addon_folder_findings("unzip", place.project)
    if not findings and not any((place.project / "addons").iterdir()):
        findings.append("step 'unzip': nothing landed in my_game/addons/")
    return findings


def root_findings(step: str, project: pathlib.Path, allowed: set[str]) -> list[str]:
    """Nothing in the project's root but what the reader put there: a zip writes only `addons/`."""
    return [f"step {step!r}: {project.name}/{entry.name} is not where an addon goes"
            for entry in sorted(project.iterdir()) if entry.name not in allowed]


def addon_folders(project: pathlib.Path) -> list[pathlib.Path]:
    """The folders in the project's `addons/`, none when there is no such folder."""
    addons = project / "addons"
    return sorted(entry for entry in addons.iterdir()) if addons.is_dir() else []


def addon_folder_findings(step: str, project: pathlib.Path) -> list[str]:
    """Every folder in `addons/` is an unzipped addon: `ai_<name>`, holding its VERSION."""
    return [f"step {step!r}: {project.name}/addons/{entry.name} is not an unzipped addon"
            for entry in addon_folders(project)
            if not (entry.name.startswith("ai_") and (entry / "VERSION").is_file())]


def class_name_clashes(project: pathlib.Path) -> list[str]:
    """Two scripts under `addons/` declaring one `class_name`.

    Measured on 4.7.2 by wave 172's review: the import prints nothing, the
    class cache keeps one of the two, and every script still runs -- so the
    clash is looked for here, in the files, since no engine output shows it.
    """
    owners: dict[str, list[str]] = {}
    for script in sorted((project / "addons").rglob("*.gd")):
        for name in CLASS_NAME_RE.findall(script.read_text(encoding="utf-8")):
            owners.setdefault(name, []).append(str(script.relative_to(project)))
    return [f"step 'kit': class_name {name} is declared by {', '.join(paths)}"
            for name, paths in sorted(owners.items()) if len(paths) > 1]


def kit_findings(place: Place, planted: Planted) -> list[str]:
    """After `kit`: the kit alone, in a blank project, holds the release's addons and nothing else.

    The per-addon zips say which addons the release holds; the kit's
    folders must be the same ones, both ways. Unzipped into a project of
    its own, nothing the per-addon zips installed can stand in for a file
    the kit lacks: the route example, saved by the step `route`, then runs
    on the kit's own `ai_core` and `ai_search`. Last, every script in the
    kit is loaded, as `check_published.py` loads the store's download, and
    the engine must not say at exit that one is still alive (T162).
    """
    project = place.kit_project
    findings = root_findings("kit", project, {"addons", "project.godot", ".godot"})
    if BLANK_PROJECT not in (project / "project.godot").read_text(encoding="utf-8"):
        findings.append("step 'kit': my_kit/project.godot is not the reader's any more")
    findings += addon_folder_findings("kit", project)
    expected = {archive.name.rsplit("-", 1)[0] for archive in place.dist.glob("ai_*-*.zip")}
    present = {entry.name for entry in addon_folders(project)}
    findings += [f"step 'kit': {addon} is not in my_kit/addons/{addon}/ after the kit"
                 for addon in sorted(expected - present)]
    findings += [f"step 'kit': my_kit/addons/{addon} has no zip of its own"
                 for addon in sorted(present - expected)]
    findings += class_name_clashes(project)
    if findings:
        return findings
    shutil.copy(place.project / "route_example.gd", project / "route_example.gd")
    return run_runner("kit", "route", project, planted) or kit_load_findings(project)


def kit_load_findings(project: pathlib.Path) -> list[str]:
    """Every script of the kit loaded, as many as its `addons/` holds, and nothing alive at exit.

    Why the count: a loader that walked nothing would load nothing, leak
    nothing and pass (invariant 4's empty scene). So the loaded count must
    be the number of `.gd` files there, and that number must not be 0.
    """
    findings, loaded = load_every_class(project, "step 'kit'")
    if findings:
        return findings
    scripts = len(list((project / "addons").rglob("*.gd")))
    if scripts == 0 or loaded is None or loaded[0] != scripts:
        return [f"step 'kit': the loader loaded {loaded[0] if loaded else 0} script(s), "
                f"and my_kit/addons/ holds {scripts}: a kit with no script loaded is no check"]
    return []


def run_example(step: str, text: str, place: Place, planted: Planted) -> list[str]:
    """`route` and `infer`: the example in the project, added to the tree by the runner."""
    example = example_of(step, text)
    shutil.copy(example, place.project / example.name)
    return run_runner(step, step, place.project, planted)


def run_runner(step: str, example: str, project: pathlib.Path, planted: Planted) -> list[str]:
    """`stranger.gd -- <example>` in `project`: it must exit 0 and print its marker."""
    runner = project / STRANGER.name
    if planted.silent_runner:
        runner.write_text("extends SceneTree\n\n\nfunc _initialize() -> void:\n\tquit(0)\n")
    else:
        shutil.copy(STRANGER, runner)
    command = [str(GODOT), "--headless", "--path", str(project), "-s", runner.name, "--", example]
    try:
        ran = subprocess.run(command, capture_output=True, text=True, timeout=RUN_SECONDS)
    except subprocess.TimeoutExpired:
        return [f"step {step!r}: Godot was still running after {RUN_SECONDS} s -- "
                "a script error after the frame wait leaves it running"]
    output = ran.stdout + ran.stderr
    if ran.returncode != 0 or MARKERS[example] not in output:
        errors = [line for line in output.splitlines() if "ERROR" in line][:5]
        return [f"step {step!r}: the example did not decide (exit {ran.returncode}, "
                f"missing {MARKERS[example]!r}): {errors}"]
    return []


def probe_wheel(place: Place, planted: Planted) -> list[str]:
    """After `wheel`: the installed package answers from site-packages."""
    environment = place.root / ".venv"
    for found in environment.rglob(planted.installed_file) if planted.installed_file else []:
        found.unlink()
    python = environment / "bin" / "python"
    probe = subprocess.run([str(python), "-I", "-c", PROBE], capture_output=True, text=True, cwd=place.root)
    if probe.returncode != 0 or "LIBRARY-CHECK" not in probe.stdout:
        return [f"step 'wheel': the installed wheel does not answer: {probe.stderr.strip().splitlines()[-3:]}"]
    return []


def save_training(text: str, place: Place) -> list[str]:
    """Before `train`'s command: the page's Python block, saved where it says."""
    training = PYTHON_BLOCK_RE.search(text)
    if training is None:
        raise Unfollowable("the step 'train' has no python block")
    (place.project / "my_training.py").write_text(training.group(1))
    return []


def licence_findings(place: Place) -> list[str]:
    """`licence`: every archive carries LICENSE and NOTICE."""
    findings = []
    for archive in sorted([*place.dist.glob("*.zip"), *place.dist.glob("*.whl")]):
        with zipfile.ZipFile(archive) as bundle:
            names = {pathlib.PurePosixPath(name).name for name in bundle.namelist()}
        findings += [f"step 'licence': {archive.name} carries no {needed}"
                     for needed in ("LICENSE", "NOTICE") if needed not in names]
    return findings


# --- the whole page -------------------------------------------------------------


def take(step: str, text: str, place: Place, planted: Planted) -> list[str]:
    """One step: what the reader does before its commands, the commands, then after."""
    before = save_training(text, place) if step == "train" else []
    failures = before or run_blocks(step, text, place)
    if failures:
        return failures
    if step == "release":
        return plant_in_release(place, planted)
    if step == "unzip":
        return unzipped_findings(place)
    if step == "infer":
        return addon_folder_findings(step, place.project) or run_example(step, text, place, planted)
    if step == "kit":
        return kit_findings(place, planted)
    if step in MARKERS:
        return run_example(step, text, place, planted)
    if step == "wheel":
        return probe_wheel(place, planted)
    if step == "licence":
        return licence_findings(place)
    return []


def follow(text: str, root: pathlib.Path, planted: Planted = Planted()) -> list[str]:
    """Every step of the page, in its order, in `root`; the first failure, if any."""
    place = reader_folder(root)
    for step, step_text in page_steps(text).items():
        failures = take(step, step_text, place, planted)
        if failures:
            return failures
    return []


def pages_findings(texts: dict[str, str]) -> list[str]:
    """Each page's steps against the check's, by label."""
    return [finding for label, text in texts.items() for finding in step_findings(label, text)]


def check() -> int:
    """The page's steps, outside the repository."""
    texts = {path.name: path.read_text(encoding="utf-8") for path in PAGES}
    failures = pages_findings(texts)
    if not failures:
        with tempfile.TemporaryDirectory(prefix="gak-library-") as workspace:
            failures = follow(texts[PAGES[0].name], pathlib.Path(workspace))
    for failure in failures:
        print(f"library-check: {failure}")
    if not failures:
        print(f"library-check: the {len(STEPS)} steps of {PAGES[0].name} ran outside the repository")
    return 1 if failures else 0


# --- self-test --------------------------------------------------------------------


def page_cases(english: str) -> list[str]:
    """The planted pages: each must be refused, naming the step it plants."""
    extra = english + "\n<!-- library-step: teleport -->\n"
    short = english.replace("<!-- library-step: licence -->\n", "")
    failures = []
    for planted, named in ((extra, "teleport"), (short, "licence")):
        found = step_findings("planted", planted)
        if not any(named in line for line in found):
            failures.append(f"a page whose steps differ from the check's is refused, naming {named} ({found})")
    return failures


def planted_faults(english: str) -> tuple[tuple[str, Planted, str], ...]:
    """Each planted case: the page to follow, the fault, and what the finding must name."""
    misplaced = english.replace("unzip -q library/dist/ai_core-0.1.0.zip", "unzip -q ai_core-0.1.0.zip", 1)
    # The page's command before T149: the zips' `addons/` nests one deeper.
    nested = english.replace("-d my_game/\n", "-d my_game/addons/\n", 1)
    # The page's `infer` before T160, and the kit unzipped the same wrong way.
    learning = english.replace("ai_learning-0.1.0.zip -d my_game/\n",
                               "ai_learning-0.1.0.zip -d my_game/addons/\n")
    kit_nested = english.replace("addons-0.1.0.zip -d my_kit/\n", "addons-0.1.0.zip -d my_kit/addons/\n")
    # A page that told the reader to overwrite, and a kit that would.
    kit_over = english.replace("unzip -q library/dist/game-ai-kit", "unzip -q -o library/dist/game-ai-kit")
    project = (("project.godot", b"config_version=5\n"),)
    clash = (("addons/ai_bandit/clash.gd", b"class_name GakXorshift\nextends RefCounted\n"),)
    return (
        (english, Planted(zip_member="addons/ai_core/grid_graph.gd"), "GakGridGraph"),
        (english, Planted(installed_file="aim.py"), "cannot import name 'aim'"),
        (english, Planted(zip_member="addons/ai_core/NOTICE"), "carries no NOTICE"),
        (english, Planted(silent_runner=True), f"missing {MARKERS['route']!r}"),
        (misplaced, Planted(), "step 'unzip'"),
        (nested, Planted(), "my_game/addons/addons is not an unzipped addon"),
        (learning, Planted(), "step 'infer': my_game/addons/addons is not an unzipped addon"),
        (kit_nested, Planted(), "step 'kit': my_kit/addons/addons is not an unzipped addon"),
        (english, Planted(kit_folder="addons/ai_core/"), "ai_core is not in my_kit/addons/ai_core/"),
        (english, Planted(kit_folder="addons/ai_core/grid_graph.gd"),
         "step 'kit': the example did not decide"),
        (english, Planted(kit_extra=(("docs/README.md", b"# a stray\n"),)),
         "my_kit/docs is not where an addon goes"),
        (english, Planted(kit_extra=project), "replace my_kit/project.godot"),
        (kit_over, Planted(kit_extra=project), "my_kit/project.godot is not the reader's"),
        (english, Planted(kit_extra=(("addons/ai_zzz/VERSION", b"0.1.0\n"),)), "ai_zzz has no zip of its own"),
        (english, Planted(kit_extra=clash), "class_name GakXorshift is declared by"),
        (english, Planted(kit_extra=tuple(LEAKING.items())), "step 'kit': loading every script leaves"),
    )


def run_cases(english: str, place: pathlib.Path) -> list[str]:
    """The untouched page passes, and each planted fault is named."""
    failures = []
    untouched = follow(english, place / "untouched")
    if untouched:
        failures.append(f"the untouched page passes every step ({untouched})")
    for number, (text, planted, named) in enumerate(planted_faults(english)):
        # A folder named for the fault would put the name in every path the
        # failure prints, and the case would pass on the path alone.
        found = follow(text, place / f"case-{number}", planted)
        if not any(named in line for line in found):
            failures.append(f"{planted} fails, naming {named} ({found})")
    return failures + empty_kit_case(place / "case-empty")


def empty_kit_case(project: pathlib.Path) -> list[str]:
    """A kit whose `addons/` holds a folder and no script: the load must not pass.

    Planted here and not through the page: the `kit` step's earlier checks
    already refuse a kit that lacks an addon, so only the load itself can
    show that a loader walking nothing is refused (review of wave 176).
    """
    (project / "addons" / "ai_core").mkdir(parents=True)
    (project / "project.godot").write_text(BLANK_PROJECT)
    found = kit_load_findings(project)
    if not any("a kit with no script loaded is no check" in line for line in found):
        return [f"a kit with no script is refused, naming its count ({found})"]
    return []


def self_test() -> int:
    """The untouched page must pass; every planted fault must be reported."""
    english = PAGES[0].read_text(encoding="utf-8")
    failures = page_cases(english)
    with tempfile.TemporaryDirectory(prefix="gak-library-selftest-") as workspace:
        failures += run_cases(english, pathlib.Path(workspace))
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    try:
        return self_test() if args.self_test else check()
    except Unfollowable as refusal:
        print(f"library-check: cannot follow the page: {refusal}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
