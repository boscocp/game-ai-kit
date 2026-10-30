"""The local LLM runtime for tier 3: install it, serve it, smoke it, bake it off (T93).

Run only through `scripts/llm`, which points every cache at the toolchain
directory on the large disk (invariant 8) and hands this file that directory.
Standard library only. Nothing in the Python package, the addons or the games
names this file, and `make check` never starts the server: a lesson never
needs it (invariant 5). The recordings are the tier-1 lesson.

What it installs is `tools/llm/runtime.json`: llama.cpp's prebuilt
`llama-server` by build tag, and GGUF models by repository revision, every
file by sha256. A file whose sha256 differs is deleted and refused, never
kept. The port is `HttpRuntime.PORT`, read out of the addon, so the server
listens where the game asks.

    llm.py TOOLCHAIN bootstrap [--model NAME|all] [--flavour NAME|all]
    llm.py TOOLCHAIN serve [--model NAME] [--flavour NAME]
    llm.py TOOLCHAIN smoke [--model NAME] [--flavour NAME]
    llm.py TOOLCHAIN bakeoff [--model NAME|all] [--flavour NAME] [--language en|pt_BR|all] [--rounds N]
    llm.py TOOLCHAIN table
    llm.py TOOLCHAIN --self-test

Exit codes: 0 done; 1 a download, a check or the smoke failed; 2 wrong usage,
or the runtime is not installed (the message says how to install it).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
MANIFEST = HERE / "runtime.json"
LINES = HERE / "bakeoff" / "lines.json"
RESULTS = REPO / "docs" / "local-llm" / "bakeoff"
HTTP_RUNTIME = REPO / "godot" / "addons" / "ai_llm" / "http_runtime.gd"
PROBE = "res://test/ai_llm/live_probe.gd"

# The one place the port is written is the game's runtime; this reads it.
PORT_LINE = re.compile(r"^const PORT: int = (\d+)$", re.M)

# How long a model may take to load before the smoke gives up on it. The
# largest here loads in seconds from a warm disk; a cold one takes longer.
LOAD_SECONDS = 180

# What the server is started with, and why each.
SERVER_FLAGS = (
    "--host", "127.0.0.1",   # this machine only
    "--ctx-size", "4096",    # a conversation of a few turns; the default is the model's own, up to 256K
    "--parallel", "1",       # the game sends one request at a time
    "--reasoning", "off",    # thinking models answer in seconds, not minutes
    "--no-ui",               # nothing to browse; the game is the client
)

DOWNLOAD_CHUNK = 1 << 20


class Refused(Exception):
    """A file that is not the one pinned, or a runtime that is not installed."""


# --- the manifest and the layout ----------------------------------------------


def manifest() -> dict:
    """runtime.json, as written."""
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def port() -> int:
    """The port HttpRuntime asks, read out of the addon: the one place it is written."""
    found = PORT_LINE.search(HTTP_RUNTIME.read_text(encoding="utf-8"))
    if found is None:
        raise Refused(f"{HTTP_RUNTIME} has no `const PORT: int = N` line")
    return int(found.group(1))


def home_of(toolchain: pathlib.Path) -> pathlib.Path:
    """Where everything this file installs lives, under the toolchain."""
    return toolchain / "llm"


def server_dir(toolchain: pathlib.Path, flavour: str) -> pathlib.Path:
    """The unpacked build of one flavour of the pinned tag."""
    return home_of(toolchain) / "bin" / f"{manifest()['runtime']['tag']}-{flavour}"


def model_path(toolchain: pathlib.Path, name: str) -> pathlib.Path:
    """Where one model's GGUF file lives once fetched."""
    return home_of(toolchain) / "models" / models_named(name)[0]["file"]


def models_named(name: str) -> list[dict]:
    """The manifest entries `name` selects: one model, the default, or all."""
    known = manifest()["models"]
    chosen = name or manifest()["default_model"]
    if chosen == "all":
        return [dict(entry, name=key) for key, entry in known.items()]
    if chosen not in known:
        raise Refused(f"no model `{chosen}` in {MANIFEST.name}; known: {', '.join(known)}")
    return [dict(known[chosen], name=chosen)]


def flavours_named(name: str) -> list[str]:
    """The flavours `name` selects: one, the default, or all."""
    known = manifest()["runtime"]["flavours"]
    chosen = name or manifest()["runtime"]["default_flavour"]
    if chosen == "all":
        return list(known)
    if chosen not in known:
        raise Refused(f"no flavour `{chosen}` in {MANIFEST.name}; known: {', '.join(known)}")
    return [chosen]


# --- fetching, pinned -----------------------------------------------------------


def sha256_of(path: pathlib.Path) -> str:
    """The file's sha256, read in chunks: a model is gigabytes."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(DOWNLOAD_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(path: pathlib.Path, size: int, sha256: str) -> None:
    """Refuse, and delete, a file that is not the pinned one.

    Size first, because it is free and a truncated download is the usual
    case; then the sha256, which is the pin.
    """
    actual_size = path.stat().st_size
    if actual_size != size:
        path.unlink()
        raise Refused(f"{path.name}: {actual_size} bytes, pinned {size}; deleted")
    actual = sha256_of(path)
    if actual != sha256:
        path.unlink()
        raise Refused(f"{path.name}: sha256 {actual}, pinned {sha256}; deleted")


def fetch(url: str, destination: pathlib.Path, size: int, sha256: str) -> None:
    """Download `url` to `destination` and verify it; a verified file is kept as is."""
    if destination.is_file() and destination.stat().st_size == size \
            and sha256_of(destination) == sha256:
        print(f"llm: {destination.name} already here, sha256 matches")
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(destination.name + ".part")
    print(f"llm: downloading {destination.name} ({size / 1e9:.2f} GB) from {url}")
    try:
        with urllib.request.urlopen(url, timeout=60) as answer, partial.open("wb") as stream:
            shutil.copyfileobj(answer, stream, DOWNLOAD_CHUNK)
    except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
        # A 404 here means upstream removed the pinned file: the way out is
        # a new pin in runtime.json (ADR 0023), never an unpinned download.
        partial.unlink(missing_ok=True)
        raise Refused(f"{destination.name}: the download failed ({error}) from {url}") from error
    verify(partial, size, sha256)
    partial.replace(destination)
    print(f"llm: {destination.name} verified")


def install_flavour(toolchain: pathlib.Path, flavour: str) -> None:
    """Fetch and unpack one flavour's archives into its own folder."""
    runtime = manifest()["runtime"]
    base = f"https://github.com/ggml-org/llama.cpp/releases/download/{runtime['tag']}"
    target = server_dir(toolchain, flavour)
    stamp = target / ".pinned-sha256"
    pins = "".join(f"{entry['sha256']}  {entry['file']}\n"
                   for entry in runtime["flavours"][flavour])
    if stamp.is_file() and stamp.read_text() == pins and (target / "llama-server").is_file():
        print(f"llm: llama-server {runtime['tag']} ({flavour}) already installed")
        return
    for entry in runtime["flavours"][flavour]:
        archive = home_of(toolchain) / "dl" / entry["file"]
        fetch(f"{base}/{entry['file']}", archive, entry["size"], entry["sha256"])
        unpack(archive, target)
    stamp.write_text(pins)


def unpack(archive: pathlib.Path, target: pathlib.Path) -> None:
    """Unpack a release archive flat into `target`, its top folder dropped.

    The `data` filter refuses a member that would land outside the target
    or is a device: the archive is checked by sha256, and still unpacked as
    if it were not.
    """
    target.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as bundle:
        members = []
        for member in bundle.getmembers():
            parts = pathlib.PurePosixPath(member.name).parts
            if len(parts) < 2:
                continue
            member.name = str(pathlib.PurePosixPath(*parts[1:]))
            members.append(member)
        bundle.extractall(target, members=members, filter="data")


def install_model(toolchain: pathlib.Path, entry: dict) -> None:
    """Fetch one model's GGUF file at its pinned revision."""
    url = (f"https://huggingface.co/{entry['repository']}/resolve/"
           f"{entry['revision']}/{entry['file']}")
    fetch(url, home_of(toolchain) / "models" / entry["file"], entry["size"], entry["sha256"])


def bootstrap(toolchain: pathlib.Path, model: str, flavour: str) -> int:
    """Install the selected flavours and models; 1 on any refusal."""
    for name in flavours_named(flavour):
        install_flavour(toolchain, name)
    for entry in models_named(model):
        install_model(toolchain, entry)
    print(f"llm: ready under {home_of(toolchain)}")
    return 0


# --- the server -------------------------------------------------------------------


def server_command(toolchain: pathlib.Path, model: str, flavour: str) -> list[str]:
    """llama-server's command line, or Refused saying how to install what is missing."""
    binary = server_dir(toolchain, flavours_named(flavour)[0]) / "llama-server"
    weights = model_path(toolchain, model)
    hint = (f"run 'make llm-bootstrap'{' MODEL=' + model if model else ''}"
            f"{' FLAVOUR=' + flavour if flavour else ''}")
    if not binary.is_file():
        raise Refused(f"no llama-server at {binary} -- {hint}")
    if not weights.is_file():
        raise Refused(f"no model at {weights} -- {hint}")
    return [str(binary), "--model", str(weights), "--port", str(port()), *SERVER_FLAGS]


def ask(path: str, body: dict | None = None, timeout: float = 5.0) -> tuple[int, dict]:
    """One request to the local server: (HTTP status, parsed answer)."""
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"http://127.0.0.1:{port()}{path}", data=data,
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as answer:
            return answer.status, parsed(answer.read())
    except urllib.error.HTTPError as error:
        return error.code, parsed(error.read())


def parsed(body: bytes) -> dict:
    """The server's answer as an object; {} when it is empty or not JSON."""
    try:
        data = json.loads(body or b"{}")
    except ValueError:
        return {}
    return data if isinstance(data, dict) else {}


def wait_until_ready(server: subprocess.Popen) -> float:
    """Seconds until /health says ok; Refused if the server dies or takes too long."""
    started = time.monotonic()
    while time.monotonic() - started < LOAD_SECONDS:
        if server.poll() is not None:
            raise Refused(f"llama-server exited with {server.returncode} while loading")
        try:
            status, _ = ask("/health", timeout=1.0)
            if status == 200:
                return time.monotonic() - started
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            pass
        time.sleep(0.25)
    raise Refused(f"llama-server did not answer /health within {LOAD_SECONDS} s")


def start(toolchain: pathlib.Path, model: str, flavour: str,
          log: pathlib.Path) -> subprocess.Popen:
    """Start the server in its own process group, its log to `log`."""
    command = server_command(toolchain, model, flavour)
    log.parent.mkdir(parents=True, exist_ok=True)
    print(f"llm: starting {' '.join(command)}")
    with log.open("w") as stream:
        return subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                start_new_session=True)


def stop(server: subprocess.Popen) -> None:
    """Stop the server, whatever state it is in: the smoke never leaves one behind."""
    if server.poll() is None:
        os.killpg(server.pid, signal.SIGTERM)
        try:
            server.wait(timeout=20)
        except subprocess.TimeoutExpired:
            os.killpg(server.pid, signal.SIGKILL)
            server.wait()


def serve(toolchain: pathlib.Path, model: str, flavour: str) -> int:
    """Run the server in the foreground until interrupted."""
    command = server_command(toolchain, model, flavour)
    print(f"llm: serving on http://127.0.0.1:{port()} -- Ctrl+C stops it")
    os.execv(command[0], command)


# --- through the game's own runtime ------------------------------------------------


def run_probe(toolchain: pathlib.Path, language: str, count: int,
              output: pathlib.Path) -> int:
    """Godot, headless, sending lines through HttpRuntime and LlmConversation."""
    command = [str(REPO / "scripts" / "godot"), "--headless", "--path", str(REPO / "godot"),
               "-s", PROBE, "--", str(LINES), language, str(count), str(output)]
    done = subprocess.run(command, env=dict(os.environ, GAK_TOOLCHAIN=str(toolchain)))
    return done.returncode


def smoke(toolchain: pathlib.Path, model: str, flavour: str, work: pathlib.Path) -> int:
    """Start the server, send one line through the game's path, check it, stop it."""
    server = start(toolchain, model, flavour, work / "server.log")
    try:
        print(f"llm: ready after {wait_until_ready(server):.1f} s")
        output = work / "smoke.json"
        if run_probe(toolchain, "en", 1, output) != 0:
            print("llm smoke: the probe failed; the server log is "
                  f"{work / 'server.log'}", file=sys.stderr)
            return 1
        turn = json.loads(output.read_text())["turns"][0]
    finally:
        stop(server)
    if turn["refusal_code"]:
        print(f"llm smoke: the reply was refused: {turn['refusal']}", file=sys.stderr)
        return 1
    print(f"llm smoke: ok -- `{turn['intent']}` in {turn['seconds']:.2f} s: {turn['speech']}")
    return 0


# --- the bake-off ------------------------------------------------------------------


def bakeoff(toolchain: pathlib.Path, model: str, flavour: str, language: str,
            rounds: int, work: pathlib.Path) -> int:
    """Every selected model on the 30 lines, `rounds` times; results in docs/.

    One server per model. Rounds, because the server samples (the game
    sends no temperature, and gets the server's default): one run of 30 is
    one draw, and two rounds of one model were measured 6 valid replies apart.
    """
    languages = ["en", "pt_BR"] if language in ("", "all") else [language]
    chosen_flavour = flavours_named(flavour)[0]
    RESULTS.mkdir(parents=True, exist_ok=True)
    for entry in models_named(model or "all"):
        server = start(toolchain, entry["name"], chosen_flavour, work / f"{entry['name']}.log")
        try:
            timings = {"load_seconds": round(wait_until_ready(server), 1),
                       "first_seconds": round(warm_up(), 2)}
            for spoken in languages:
                for round_number in range(1, rounds + 1):
                    name = f"{entry['name']}-{chosen_flavour}-{spoken}-r{round_number}.json"
                    if run_probe(toolchain, spoken, 0, RESULTS / name) != 0:
                        return 1
                    stamp(RESULTS / name, entry, chosen_flavour, timings)
        finally:
            stop(server)
    return 0


def warm_up() -> float:
    """Seconds for the first request after loading, which is not one of the 30.

    The first answer pays for work done once -- measured, several seconds
    more than the rest -- and a player meets it once, while the guard is
    still saying hello. Timed apart, so the median and the worst are a turn's.
    """
    started = time.monotonic()
    ask("/v1/chat/completions", {"messages": [{"role": "user", "content": "Hello."}],
                                 "max_tokens": 8}, timeout=LOAD_SECONDS)
    return time.monotonic() - started


def stamp(output: pathlib.Path, entry: dict, flavour: str, timings: dict) -> None:
    """Write which model, file and build answered beside the probe's turns."""
    result = json.loads(output.read_text())
    result["model"] = {key: entry[key] for key in
                       ("name", "repository", "revision", "file", "sha256", "licence")}
    result["runtime"] = {"tag": manifest()["runtime"]["tag"], "flavour": flavour,
                         "flags": list(SERVER_FLAGS)}
    result.update(timings)
    output.write_text(json.dumps(result, indent=1, ensure_ascii=False) + "\n")


def summary(result: dict) -> dict:
    """The table's numbers for one model, one language.

    The act and argument count only replies the validator accepted. A
    refused reply becomes the game's fallback, `unclear` with no argument,
    and two of the 30 lines are labelled exactly that: counted, a refusal
    scored as right (T93's review). Those are `fallback`, apart.
    """
    turns = result["turns"]
    expected = json.loads(LINES.read_text())["lines"]
    accepted = [(turn, line) for turn, line in zip(turns, expected) if not turn["refusal_code"]]
    return {
        "valid": len(accepted),
        "intent": sum(1 for turn, line in accepted if turn["intent"] == line["intent"]),
        "both": sum(1 for turn, line in accepted
                    if (turn["intent"], turn["argument"]) == (line["intent"], line["argument"])),
        "fallback": sum(1 for turn, line in zip(turns, expected) if turn["refusal_code"]
                        and (turn["intent"], turn["argument"]) == (line["intent"], line["argument"])),
        "slow": sum(1 for turn in turns if turn["seconds"] >= 1.0),
        "frame": max(turn["worst_frame_ms"] for turn in turns),
        "count": len(turns),
    }


def table() -> int:
    """Print the bake-off's table from the committed results, as docs/ shows it.

    One row per model, build and language; each count is the mean of the
    rounds with their range, the times are over every turn of every round.
    """
    groups: dict[tuple[str, str, str], list[dict]] = {}
    for path in sorted(RESULTS.glob("*.json")):
        result = json.loads(path.read_text())
        key = (result["model"]["name"], result["runtime"]["flavour"], result["language"])
        groups.setdefault(key, []).append(result)
    print("| model | build | language | rounds | valid | intent | intent and argument "
          "| a refusal on an `unclear` line | median s | worst s | 1 s or more | worst frame ms |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for (name, flavour, language), results in sorted(groups.items()):
        rows = [summary(result) for result in results]
        times = [turn["seconds"] for result in results for turn in result["turns"]]
        counts = " | ".join(spread([row[column] for row in rows], rows[0]["count"])
                            for column in ("valid", "intent", "both", "fallback"))
        print(f"| {name} | {flavour} | {language} | {len(rows)} | {counts} "
              f"| {statistics.median(times):.2f} | {max(times):.2f} "
              f"| {sum(row['slow'] for row in rows)} of {len(times)} "
              f"| {max(row['frame'] for row in rows):.1f} |")
    return 0


def spread(values: list[int], out_of: int) -> str:
    """A count over rounds: its mean, and its range when the rounds differ."""
    mean = f"{statistics.mean(values):.1f}/{out_of}"
    return mean if min(values) == max(values) else f"{mean} ({min(values)}-{max(values)})"


# --- self-test ---------------------------------------------------------------------


def self_test() -> int:
    """The pin refuses a planted file; the manifest and the port read as expected."""
    failures = []
    with tempfile.TemporaryDirectory() as folder:
        planted = pathlib.Path(folder) / "model.gguf"
        planted.write_bytes(b"not the pinned bytes")
        pinned = hashlib.sha256(b"the pinned bytes!!!!").hexdigest()
        try:
            verify(planted, planted.stat().st_size, pinned)
            failures.append("a file with the wrong sha256 was accepted")
        except Refused:
            if planted.exists():
                failures.append("a refused file was kept")
        good = pathlib.Path(folder) / "good.gguf"
        good.write_bytes(b"the pinned bytes!!!!")
        try:
            verify(good, good.stat().st_size, pinned)
        except Refused as refusal:
            failures.append(f"the pinned file was refused: {refusal}")
        short = pathlib.Path(folder) / "short.gguf"
        short.write_bytes(b"the pinned")
        try:
            verify(short, 20, pinned)
            failures.append("a truncated file was accepted")
        except Refused:
            pass
    failures += manifest_problems()
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def manifest_problems() -> list[str]:
    """What is wrong with runtime.json and the port, as the self-test sees it."""
    problems = []
    data = manifest()
    if data["default_model"] not in data["models"]:
        problems.append(f"default_model `{data['default_model']}` is not a model")
    if data["runtime"]["default_flavour"] not in data["runtime"]["flavours"]:
        problems.append("default_flavour is not a flavour")
    hexadecimal = re.compile(r"^[0-9a-f]{64}$")
    pinned = [entry for entries in data["runtime"]["flavours"].values() for entry in entries]
    pinned += list(data["models"].values())
    for entry in pinned:
        if not hexadecimal.match(entry["sha256"]) or entry["size"] <= 0:
            problems.append(f"{entry['file']} is not pinned by sha256 and size")
    for name, entry in data["models"].items():
        if not entry.get("licence") or not entry.get("licence_source"):
            problems.append(f"model `{name}` has no licence, or no word on where it was read")
    try:
        port()
    except Refused as refusal:
        problems.append(str(refusal))
    return problems


def main(argv: list[str]) -> int:
    """Parse the command line and run one command; the exit codes are the module's."""
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("toolchain", type=pathlib.Path)
    parser.add_argument("command", nargs="?", default="",
                        choices=["", "bootstrap", "serve", "smoke", "bakeoff", "table"])
    parser.add_argument("--model", default="")
    parser.add_argument("--flavour", default="")
    parser.add_argument("--language", default="")
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        return 0 if exit_request.code == 0 else 2
    if args.self_test:
        return self_test()
    try:
        return dispatch(args)
    except Refused as refusal:
        print(f"llm: {refusal}", file=sys.stderr)
        return 2 if "make llm-bootstrap" in str(refusal) or "no model `" in str(refusal) \
            or "no flavour `" in str(refusal) else 1


def dispatch(args: argparse.Namespace) -> int:
    """Run the one command asked for."""
    work = home_of(args.toolchain) / "run"
    if args.command == "bootstrap":
        return bootstrap(args.toolchain, args.model, args.flavour)
    if args.command == "serve":
        return serve(args.toolchain, args.model, args.flavour)
    if args.command == "smoke":
        return smoke(args.toolchain, args.model, args.flavour, work)
    if args.command == "bakeoff":
        return bakeoff(args.toolchain, args.model, args.flavour, args.language,
                       args.rounds, work)
    if args.command == "table":
        return table()
    print("llm: a command is needed: bootstrap, serve, smoke, bakeoff or table", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
