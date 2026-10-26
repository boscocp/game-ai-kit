#!/usr/bin/env python3
"""Fail if the Godot toolchain, or the art generator's model, writes to the small disk.

The rule
--------
Everything this project installs lives on the large disk, under the toolchain
directory. Nothing lands in the user's home.

Why this gate exists
--------------------
On 2026-10-12, during bootstrap, enabling Godot's self-contained mode (an empty
`._sc_` file next to the binary) was assumed to be enough. It is not. Measured
on Godot 4.7.2: `._sc_` redirects editor settings, cache and export templates
-- the part that grows past 1 GB -- but a single `--headless --import` still
recreated `~/.local/share/godot/app_userdata/`, because the project's `user://`
directory is not editor data. The second mechanism, XDG_DATA_HOME, covers it.
On Windows the engine reads APPDATA and LOCALAPPDATA instead (OS_Windows's
get_config_path and get_cache_path), so scripts/godot points those two at the
toolchain, and the leaks looked for include where they would land.

Two mechanisms means two ways to silently regress, so both are asserted here
rather than trusted.

Where the second one points is asserted too (T83, docs/adr/0022). It used to
be one directory under the toolchain for every git worktree, and a suite
ending in one worktree deleted the files of a test running in another. Each
checkout's own scripts/godot is asked where it sends user:// (D6 not under
home, D7 no two checkouts sharing one, D8 inside its own checkout and ignored
by git); a checkout whose wrapper predates the question is a note.

The art generator (T31) has the same trap, larger: tens of GB of model that Hugging
Face, torch and Triton would all cache under ~/.cache by default. scripts/artgen
points every one of them at the toolchain directory, and the paths below say
where they would land if it stopped.

Exit codes
----------
0   clean: nothing on the small disk, toolchain intact
1   violations found (each one printed)
2   wrong usage, or a path that cannot be read

Usage
-----
    check_disk_layout.py [--repo PATH] [--toolchain PATH] [--home PATH]
    check_disk_layout.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import pathlib
import re
import subprocess
import sys
import tempfile
from typing import Callable

# Where Godot writes when neither mechanism is in place. Relative to home.
LEAK_PATHS = (
    ".local/share/godot",
    ".config/godot",
    ".cache/godot",
    # Added after a review pointed out the list was three fixed paths and the
    # engine has more than three places to write.
    ".local/state/godot",
    ".godot",
    # The art generator's model and kernel caches, where they land without
    # scripts/artgen. ~/.cache/pip and ~/.nv are not listed: on the owner's
    # machine other software already keeps caches there, so their presence
    # says nothing about this repository. That pip and the driver honour
    # PIP_CACHE_DIR and CUDA_CACHE_PATH was measured instead, by mtime.
    # The three below are shared with any other machine-learning project, so
    # a developer with one will see this fire: that is the price of catching
    # a 30 GB model landing on the small disk, and the message says where from.
    ".cache/huggingface",
    ".cache/torch",
    ".triton",
    # Windows: %APPDATA%/Godot holds editor data and user://, and
    # %LOCALAPPDATA%/Godot the cache, when scripts/godot is bypassed.
    "AppData/Roaming/Godot",
    "AppData/Local/Godot",
)

WINDOWS = os.name == "nt"
DEFAULT_TOOLCHAIN = "D:/games/gamedev/toolchain" if WINDOWS else "/mnt/games/gamedev/toolchain"


def find_leaks(home: pathlib.Path) -> list[str]:
    """Report any Godot directory, or model cache, that exists under home.

    An empty leftover directory is reported too: it means a mechanism stopped
    working, and the files follow the directory.
    """
    findings = []
    for relative in LEAK_PATHS:
        leaked = home / relative
        if leaked.exists():
            size = sum(f.stat().st_size for f in leaked.rglob("*") if f.is_file())
            findings.append(f"D1 {leaked} exists on the small disk ({size} bytes)")
    return findings


def check_toolchain(toolchain: pathlib.Path, windows: bool = WINDOWS) -> list[str]:
    """Report a toolchain that is missing or has lost self-contained mode.

    On Windows the toolchain is two programs: `godot_console.exe`, which
    scripts/godot calls, and the `godot.exe` it starts. Either one missing is
    a toolchain that cannot run. There is no execute bit to ask about there --
    `os.access(X_OK)` is true of any file -- so being a file is what is asked.
    """
    findings = []
    names = ("godot_console.exe", "godot.exe") if windows else ("godot",)
    marker = toolchain / "godot" / "._sc_"

    for name in names:
        binary = toolchain / "godot" / name
        # `exists()` was true for a *directory* named godot/godot, which then
        # satisfied every other check here.
        if not binary.is_file() or not (windows or os.access(binary, os.X_OK)):
            findings.append(f"D2 no executable Godot at {binary} -- run 'make bootstrap'")
    if findings:
        return findings
    if not marker.exists():
        findings.append(f"D3 self-contained marker missing: {marker}")
    if not (toolchain / "godot" / "editor_data").exists():
        findings.append(f"D4 no editor_data/ beside the binary; is ._sc_ being honoured?")
    return findings


def check_repo_location(repo: pathlib.Path, home: pathlib.Path,
                        on_runner: bool = False) -> list[str]:
    """Report a repository that sits on the small disk.

    Not asked on a CI runner, and the run says so. The two disks are the
    author's machine; a GitHub runner has one, and checks the repository out
    under /home/runner whatever the workflow says. The first CI run of this
    repository (wave 63) failed here and nowhere else. The leaks above are
    still looked for on the runner: a Godot that writes to ~/.local is wrong
    on any machine. The runner is known by GitHub's own `GITHUB_ACTIONS=true`;
    set by hand on a desk, it turns this one rule into a note, and says so.
    """
    try:
        repo.resolve().relative_to(home.resolve())
    except ValueError:
        return []
    if on_runner:
        print(f"D5 note: the repository is under {home}, and this is a CI runner "
              "with one disk; not a finding there")
        return []
    return [f"D5 the repository itself is under {home} -- it belongs on the large disk"]


# --- each checkout its own user:// (T83) ------------------------------------
#
# Until wave 93 scripts/godot pointed every checkout's user:// at one
# directory under the toolchain, and two waves testing at once wrote each
# other's files (wave 78's effects shards failed during wave 80's check). The
# wrapper now points it inside its own checkout, at .user-data/, and prints
# that redirect when asked -- so what is checked here is what Godot is given,
# not a copy of the rule.

PRINT_REDIRECT = "--gak-print-redirect"

# The wrapper's own test of its first argument. A wrapper is run only when it
# has this line in its code: the flag written in a comment, or in an older
# wrapper that never looks at it, would start Godot instead.
HANDLES_FLAG = re.compile(r'^\s*if \[\[ "\$\{1:-\}" == "--gak-print-redirect" \]\]', re.M)

# What one checkout's wrapper redirects user:// to: its NAME=PATH paths, or
# None when the wrapper cannot answer.
Redirects = dict[pathlib.Path, "list[pathlib.Path] | None"]

# Whether git, in a checkout, ignores a path: (checkout, path) -> bool.
Ignored = Callable[[pathlib.Path, pathlib.Path], bool]

# How many of the checkouts that predate T83 a note names before it counts.
NAMED_IN_A_NOTE = 3


def list_checkouts(repo: pathlib.Path) -> list[pathlib.Path]:
    """Every checkout git knows for this repository: the main one and each worktree.

    A copy with no git (a release unpacked somewhere) is one checkout, itself.
    A worktree whose folder is gone is skipped: nothing there can run Godot.
    """
    listed = subprocess.run(["git", "-C", str(repo), "worktree", "list", "--porcelain"],
                            capture_output=True, text=True)
    if listed.returncode != 0:
        return [repo]
    paths = [pathlib.Path(line.split(" ", 1)[1]) for line in listed.stdout.splitlines()
             if line.startswith("worktree ")]
    return [path for path in paths if path.is_dir()] or [repo]


def read_redirect(checkout: pathlib.Path) -> "list[pathlib.Path] | None":
    """Ask one checkout's own scripts/godot where it sends user://.

    None for a wrapper whose code does not test for the question: running it
    with an unknown flag would start Godot, so it is not run at all.
    """
    wrapper = checkout / "scripts" / "godot"
    if not wrapper.is_file() or not HANDLES_FLAG.search(wrapper.read_text(errors="replace")):
        return None
    try:
        printed = subprocess.run(["bash", str(wrapper), PRINT_REDIRECT],
                                 capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired as error:
        raise OSError(f"{wrapper} {PRINT_REDIRECT} did not answer in 60 s") from error
    return [pathlib.Path(line.split("=", 1)[1].strip())
            for line in printed.stdout.splitlines() if "=" in line]


def is_inside(path: pathlib.Path, folder: pathlib.Path) -> bool:
    """Whether path is folder or lies under it, after resolving both."""
    try:
        path.resolve().relative_to(folder.resolve())
    except ValueError:
        return False
    return True


def same_checkout(first: pathlib.Path, second: pathlib.Path) -> bool:
    """Whether two paths name one checkout, however each was spelled."""
    return first.resolve() == second.resolve()


def ignored_by_git(checkout: pathlib.Path, path: pathlib.Path) -> bool:
    """Whether git in that checkout ignores path: user:// holds logs, never commits."""
    asked = subprocess.run(["git", "-C", str(checkout), "check-ignore", "-q", str(path)],
                           capture_output=True)
    return asked.returncode == 0


def redirect_problems(checkout: pathlib.Path, folders: "list[pathlib.Path] | None",
                      home: pathlib.Path, on_runner: bool, ignored: Ignored) -> list[str]:
    """D6 and D8 for one checkout: off home, inside itself, outside godot/, ignored.

    Under home on a CI runner is a note, as D5 is: there the checkout itself
    is under home, and so is everything inside it.
    """
    if not folders:
        return [f"D8 {checkout}/scripts/godot gives no user:// redirect ({PRINT_REDIRECT})"]
    problems = []
    for folder in folders:
        if is_inside(folder, home) and on_runner:
            print(f"D6 note: user:// at {folder} is under {home}, on a one-disk CI runner")
        elif is_inside(folder, home):
            problems.append(f"D6 user:// for {checkout} is {folder}, under {home} -- the small disk")
        if not is_inside(folder, checkout):
            problems.append(f"D8 user:// for {checkout} is {folder}, outside the checkout "
                            "-- shared by every checkout that resolves there (docs/adr/0022)")
        elif is_inside(folder, checkout / "godot"):
            problems.append(f"D8 user:// for {checkout} is {folder}, inside godot/, "
                            "where the engine would import it")
        elif not ignored(checkout, folder):
            problems.append(f"D8 user:// for {checkout} is {folder}, which git does not ignore")
    return problems


def shared_pairs(redirects: Redirects) -> list[tuple[pathlib.Path, pathlib.Path, str]]:
    """D7: every two checkouts writing one user://, or one inside the other's."""
    pairs = []
    known = [(checkout, folder) for checkout, folders in redirects.items()
             for folder in folders or []]
    for index, (first, first_folder) in enumerate(known):
        for second, second_folder in known[index + 1:]:
            if first != second and (is_inside(first_folder, second_folder)
                                    or is_inside(second_folder, first_folder)):
                pairs.append((first, second, f"D7 {first} and {second} share user:// "
                                             f"({first_folder} and {second_folder})"))
    return pairs


def note_older(redirects: Redirects, repo: pathlib.Path) -> None:
    """One line for the other checkouts whose wrapper predates T83: a count, a few named."""
    older = sorted(str(checkout) for checkout, folders in redirects.items()
                   if folders is None and not same_checkout(checkout, repo))
    if older:
        named = ", ".join(older[:NAMED_IN_A_NOTE])
        more = f" and {len(older) - NAMED_IN_A_NOTE} more" if len(older) > NAMED_IN_A_NOTE else ""
        print(f"D7 note: {len(older)} other checkout(s) predate T83 and still share the "
              f"old user:// -- {named}{more}")


def check_user_dirs(repo: pathlib.Path, redirects: Redirects, home: pathlib.Path,
                    on_runner: bool = False, ignored: Ignored = ignored_by_git) -> list[str]:
    """D6-D8 as findings for this checkout; the same wrong in another one is a note.

    Another worktree is another branch's state, often mid-wave: failing this
    checkout for it would fail work it does not hold (the review, wave 93). So
    D6 and D8 are findings only for the repository itself, and D7 only for a
    pair it is part of. Its own wrapper not answering is a finding: this
    checkout is the one the gate is about.
    """
    findings, notes = [], []
    for checkout, folders in redirects.items():
        mine = same_checkout(checkout, repo)
        if folders is None and not mine:
            continue
        (findings if mine else notes).extend(
            redirect_problems(checkout, folders, home, on_runner, ignored))
    for first, second, text in shared_pairs(redirects):
        mine = same_checkout(first, repo) or same_checkout(second, repo)
        (findings if mine else notes).append(text)
    for note in notes:
        code, rest = note.split(" ", 1)
        print(f"{code} note, another checkout: {rest}")
    note_older(redirects, repo)
    return findings


def read_all_redirects(repo: pathlib.Path) -> Redirects:
    """Each checkout's answer, this one's always among them."""
    checkouts = list_checkouts(repo)
    if not any(same_checkout(checkout, repo) for checkout in checkouts):
        checkouts.append(repo)
    return {checkout: read_redirect(checkout) for checkout in checkouts}


def all_findings(repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
                 on_runner: bool = False, windows: bool = WINDOWS,
                 redirects: "Redirects | None" = None,
                 ignored: Ignored = ignored_by_git) -> list[str]:
    """Every check; the redirects are read from the checkouts unless given."""
    if redirects is None:
        redirects = read_all_redirects(repo)
    return (find_leaks(home) + check_toolchain(toolchain, windows)
            + check_repo_location(repo, home, on_runner)
            + check_user_dirs(repo, redirects, home, on_runner, ignored))


def run(repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
        on_runner: bool = False, windows: bool = WINDOWS,
        redirects: "Redirects | None" = None, ignored: Ignored = ignored_by_git) -> int:
    """Print every finding; 1 if there is one."""
    findings = all_findings(repo, toolchain, home, on_runner, windows, redirects, ignored)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------
#
# Every gate in this repo is born with a case it must reject. A gate that only
# knows how to go green is worse than no gate, because nobody investigates a
# green.


def wrapper_copy(root: pathlib.Path, name: str) -> pathlib.Path:
    """A git checkout holding this repository's real scripts/godot, ignoring .user-data/.

    The wrapper's own answer is what the case holds, and git's own ignore
    rules: a wrapper changed back to one directory for everyone, or an
    `ignored_by_git` that says yes to anything, fails the self-test.
    """
    checkout = root / name
    (checkout / "scripts").mkdir(parents=True)
    source = pathlib.Path(__file__).resolve().parent / "godot"
    (checkout / "scripts" / "godot").write_text(source.read_text())
    subprocess.run(["git", "init", "-q", str(checkout)], check=True, capture_output=True)
    (checkout / ".gitignore").write_text("/.user-data/\n")
    return checkout


def git_cases(root: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path, expect) -> None:
    """The real wrapper and the real `ignored_by_git`, in two real git checkouts."""
    first, second = wrapper_copy(root, "copy-one"), wrapper_copy(root, "copy-two")
    expect("git ignores .user-data/xdg", int(ignored_by_git(first, first / ".user-data" / "xdg")), 1)
    expect("git does not ignore scripts/", int(ignored_by_git(first, first / "scripts")), 0)
    real = {first: read_redirect(first), second: read_redirect(second)}
    with contextlib.redirect_stdout(io.StringIO()):
        expect("the real wrapper in two checkouts", run(first, toolchain, home, False, False, real), 0)
    # Planted: a wrapper naming the flag only in a comment. Run, it would
    # leave a file behind; it must not be run at all.
    commented = root / "commented"
    (commented / "scripts").mkdir(parents=True)
    ran = commented / "it-ran"
    (commented / "scripts" / "godot").write_text(
        f"#!/usr/bin/env bash\n# answers {PRINT_REDIRECT}, says this comment\n"
        f"touch '{ran}'\necho XDG_DATA_HOME=/somewhere\n")
    expect("a wrapper without the flag is not run", int(read_redirect(commented) is None), 1)
    expect("... and left nothing behind", int(ran.exists()), 0)


def user_dir_cases(root: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
                   repo: pathlib.Path, expect, said) -> None:
    """The planted user:// layouts (T83): D6, D7 and D8, each asked for by code."""
    other, third = root / "other-checkout", root / "third-checkout"
    shared = toolchain / "xdg"
    own = [repo / ".user-data" / "xdg"]
    # Planted: the layout before T83 -- two checkouts, one directory.
    expect("two checkouts, one user:// (D7)", int(said("D7", repo, toolchain, home,
                                                       {repo: [shared], other: [shared]})), 1)
    # Planted, D7 alone: a checkout inside this one's user://, so each is
    # inside itself and only the overlap is wrong.
    inner = repo / ".user-data" / "xdg" / "inner"
    expect("one user:// inside another's (D7 alone)", int(said(
        "D7", repo, toolchain, home, {repo: own, inner: [inner / ".user-data"]})), 1)
    # Planted: one checkout back on the toolchain; with one checkout (CI)
    # there is nothing to collide with, and D8 is what catches it.
    expect("user:// outside its checkout (D8)", int(said("D8", repo, toolchain, home, {repo: [shared]})), 1)
    expect("user:// inside godot/ (D8)",
           int(said("D8", repo, toolchain, home, {repo: [repo / "godot" / ".user-data"]})), 1)
    expect("user:// git does not ignore (D8)", int(said(
        "D8", repo, toolchain, home, {repo: own}, ignored=lambda *_: False)), 1)
    expect("a wrapper that prints nothing (D8)", int(said("D8", repo, toolchain, home, {repo: []})), 1)
    expect("this checkout's wrapper cannot answer (D8)",
           int(said("D8", repo, toolchain, home, {repo: None})), 1)
    # Planted, D6 alone: home is the checkout's parent's folder, so the
    # directory is inside the checkout, ignored, and still on the small disk.
    expect("user:// under home (D6)", int(said("D6", repo, toolchain, repo.parent, {repo: own})), 1)
    other_cases(root, toolchain, home, repo, expect, other, third)


def other_cases(root: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
                repo: pathlib.Path, expect, other: pathlib.Path, third: pathlib.Path) -> None:
    """What is wrong in another checkout is a note here, never this one's finding."""
    own = [repo / ".user-data" / "xdg"]
    shared = toolchain / "xdg"
    layouts = {
        "two other checkouts sharing one user://": {repo: own, other: [shared], third: [shared]},
        "another checkout's user:// under home": {repo: own, other: [home / ".user-data"]},
        "another checkout's user:// not ignored": {repo: own, other: [other / ".user-data"]},
        "another checkout that predates T83": {repo: own, other: None},
    }
    for label, layout in layouts.items():
        not_ignored = (lambda checkout, _: checkout != other)
        with contextlib.redirect_stdout(io.StringIO()):
            expect(f"{label} is a note", run(repo, toolchain, home, False, False, layout, not_ignored), 0)
    runner_repo = home / "runner-repo"
    with contextlib.redirect_stdout(io.StringIO()):
        expect("user:// under home on a runner is a note", run(
            runner_repo, toolchain, home, True, False,
            {runner_repo: [runner_repo / ".user-data"]}, lambda *_: True), 0)
    git_cases(root, toolchain, home, expect)


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
              on_runner: bool = False, windows: bool = False) -> int:
        """Run the check without printing: a planted finding is not a failure.

        The Linux layout unless told otherwise, whatever the host: a planted
        missing `._sc_` must be refused for that, not because a Windows host
        went looking for `godot.exe` beside it. The checkout's user:// is the
        decided one, inside it, so these cases plant one thing each.
        """
        own = {repo: [repo / ".user-data" / "xdg"]}
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, toolchain, home, on_runner, windows, own, lambda *_: True)

    def said(code: str, repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path,
             redirects: Redirects, on_runner: bool = False,
             ignored: Ignored = lambda *_: True) -> bool:
        """Whether a planted user:// layout has a finding with that code.

        The findings are asked, not the printed lines and not only the exit:
        the cases overlap (a shared directory is also outside its checkout),
        and a check turned from a finding into a note still prints its code.
        """
        with contextlib.redirect_stdout(io.StringIO()):
            findings = all_findings(repo, toolchain, home, on_runner, False, redirects, ignored)
        return any(finding.startswith(code + " ") for finding in findings)

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        clean_home = root / "clean-home"
        clean_home.mkdir()
        good_toolchain = root / "toolchain"
        (good_toolchain / "godot" / "editor_data").mkdir(parents=True)
        binary = good_toolchain / "godot" / "godot"
        binary.write_text("#!/bin/sh\n")
        binary.chmod(0o755)
        (good_toolchain / "godot" / "._sc_").touch()
        # Both layouts are held on every host: the cases pass `windows`
        # explicitly where it matters, so neither depends on the desk.
        for name in ("godot_console.exe", "godot.exe"):
            (good_toolchain / "godot" / name).write_text("MZ")
        repo_off_home = root / "repo"
        repo_off_home.mkdir()

        expect("clean layout", quiet(repo_off_home, good_toolchain, clean_home, False, False), 0)
        expect("clean Windows layout",
               quiet(repo_off_home, good_toolchain, clean_home, False, True), 0)

        # Planted: Godot run on Windows without scripts/godot, so user://
        # landed under %APPDATA%.
        roaming_home = root / "roaming-home"
        (roaming_home / "AppData/Roaming/Godot/app_userdata/game-ai-kit").mkdir(parents=True)
        expect("leaked %APPDATA% user:// dir",
               quiet(repo_off_home, good_toolchain, roaming_home, False, True), 1)

        # Planted: a Windows toolchain with the console twin and no editor
        # for it to start -- and its mirror image.
        for missing in ("godot.exe", "godot_console.exe"):
            half = root / ("half-" + missing)
            (half / "godot" / "editor_data").mkdir(parents=True)
            (half / "godot" / "._sc_").touch()
            for name in {"godot.exe", "godot_console.exe"} - {missing}:
                (half / "godot" / name).write_text("MZ")
            expect(f"Windows toolchain without {missing}",
                   quiet(repo_off_home, half, clean_home, False, True), 1)

        # Planted: the exact leak measured during bootstrap.
        dirty_home = root / "dirty-home"
        (dirty_home / ".local/share/godot/app_userdata/game-ai-kit").mkdir(parents=True)
        expect("leaked user:// dir", quiet(repo_off_home, good_toolchain, dirty_home), 1)

        # Planted: the generator run without its wrapper, fetching a model
        # into Hugging Face's default cache.
        model_home = root / "model-home"
        (model_home / ".cache/huggingface/hub/models--some--model").mkdir(parents=True)
        expect("a model cache under home", quiet(repo_off_home, good_toolchain, model_home), 1)
        # Planted: torch's and Triton's caches, each on its own -- with only
        # the Hugging Face case, deleting either path from the list stayed green.
        for leak in (".cache/torch/hub", ".triton/cache"):
            leaked_home = root / ("leak-" + leak.replace("/", "-"))
            (leaked_home / leak).mkdir(parents=True)
            expect(f"{leak} under home", quiet(repo_off_home, good_toolchain, leaked_home), 1)

        # Planted: someone removed the self-contained marker.
        no_marker = root / "no-marker"
        (no_marker / "godot" / "editor_data").mkdir(parents=True)
        (no_marker / "godot" / "godot").write_text("#!/bin/sh\n")
        (no_marker / "godot" / "godot").chmod(0o755)
        expect("missing ._sc_", quiet(repo_off_home, no_marker, clean_home), 1)

        # Planted: a directory where the binary should be. exists() said yes.
        a_directory = root / "adirectory"
        (a_directory / "godot" / "godot").mkdir(parents=True)
        (a_directory / "godot" / "editor_data").mkdir()
        (a_directory / "godot" / "._sc_").touch()
        expect("a directory named godot/godot", quiet(repo_off_home, a_directory, clean_home), 1)

        # Planted: a non-executable file where the binary should be.
        not_executable = root / "notexec"
        (not_executable / "godot" / "editor_data").mkdir(parents=True)
        (not_executable / "godot" / "godot").write_text("#!/bin/sh\n")
        (not_executable / "godot" / "godot").chmod(0o644)
        (not_executable / "godot" / "._sc_").touch()
        # Windows has no execute bit to take away: chmod leaves os.access
        # saying yes, so this case is held only where it can be planted.
        if not WINDOWS:
            expect("binary without the execute bit",
                   quiet(repo_off_home, not_executable, clean_home), 1)
        else:
            print("self-test note: the execute-bit case needs a POSIX host; skipped here")

        # Planted: no toolchain at all.
        expect("absent toolchain", quiet(repo_off_home, root / "nowhere", clean_home), 1)

        # Planted: the repository living on the small disk.
        repo_on_home = clean_home / "projects" / "game-ai-kit"
        repo_on_home.mkdir(parents=True)
        expect("repo under home", quiet(repo_on_home, good_toolchain, clean_home), 1)
        # On a CI runner the repository is always under home, and that alone
        # is not a finding -- but a leak there still is.
        expect("repo under home on a runner", quiet(repo_on_home, good_toolchain, clean_home, True), 0)
        expect("a leak on a runner", quiet(repo_on_home, good_toolchain, dirty_home, True), 1)

        user_dir_cases(root, good_toolchain, clean_home, repo_off_home, expect, said)

        # Usage errors must be exit 2, never confused with a finding.
        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"],
            capture_output=True,
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--toolchain", default=None)
    parser.add_argument("--home", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        # argparse raises SystemExit for `--help` too, with code 0. Catching it
        # blindly turned a successful --help into exit 2 in every gate here.
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    toolchain = pathlib.Path(
        args.toolchain or os.environ.get("GAK_TOOLCHAIN", DEFAULT_TOOLCHAIN)
    )
    home = pathlib.Path(args.home or pathlib.Path.home())

    try:
        return run(repo, toolchain, home, on_runner=os.environ.get("GITHUB_ACTIONS") == "true")
    except OSError as error:
        print(f"check_disk_layout: cannot read a path: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
