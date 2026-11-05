#!/usr/bin/env python3
"""A server the game started stops however the game ends (T130).

The owner, 2026-11-05: "Lembre de colocar mecanismo de quando fechar o
jogo tbm fechar o servidor llm pra não ficar gastando vram" -- when the
game closes, close the LLM server too, so it does not keep spending VRAM.

Each run starts Godot headless on `server_ends_game.gd`, on a port the
system has just said is free. The game starts `fake_llm_server.py`
through `LlmLocalServer` and says the server's pid. Then the game ends:
- by `quit()`;
- by the window's close request;
- by Ctrl+C (SIGINT with the default disposition, as a terminal sends it);
- by SIGTERM;
- by SIGKILL, which no code in the game survives to see.

The server must be gone within a second. The first two endings are the
game's own `_exit_tree`. The others are the parent-death signal that
`die_with` sets (tools/llm/llm.py, Linux).

Nothing is signalled that this run cannot tie to itself. A pid is used
only if it is above zero and its parent, read from /proc, is the Godot
this run started -- else the run stops, exit 2. The second review found
that a server already on a fixed port made the game say "READY -1", and
`os.kill(-1, ...)` reaches every process the user owns.

Planted:
- the same SIGKILL, with a server told not to die with its parent, must
  be seen to survive (or this could pass on a server never there); the
  survivor, tied to this run, is then stopped;
- a server already listening on the chosen port must stop the run with
  "not this run's", and nothing is signalled.

Usage: python3 godot/test/ai_llm/server_ends.py   (from the repository root)
Exit codes: 0 every ending stopped the server; 1 one did not; 2 a server
could not be tied to this run, the game never said it was ready, or not
Linux.
"""

from __future__ import annotations

import http.server
import os
import pathlib
import signal
import socket
import subprocess
import sys
import threading
import time

REPO = pathlib.Path(__file__).resolve().parents[3]
GAME = "res://test/ai_llm/server_ends_game.gd"
# Seconds the game may take to say its server is ready, and the server to go.
READY_SECONDS = 30.0
GONE_SECONDS = 1.0

ENDINGS = [("quit", None), ("close", None), ("wait", signal.SIGINT),
           ("wait", signal.SIGTERM), ("wait", signal.SIGKILL)]


class Quiet(http.server.BaseHTTPRequestHandler):
    """The planted squatter's handler: any answer will do, logged nowhere."""

    def log_message(self, *_: object) -> None:
        """Quiet: the run reports what matters."""


class NotThisRun(RuntimeError):
    """A server this run cannot tie to the game it started: never signalled."""


def free_port() -> int:
    """A port the system says nobody holds now; another run picks its own."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def parent_of(pid: int) -> int:
    """The parent pid of `pid`, from /proc; 0 when it is not running."""
    try:
        stat = pathlib.Path(f"/proc/{pid}/stat").read_text()
    except OSError:
        return 0
    return int(stat.rsplit(")", 1)[1].split()[1])


def start_game(ending: str, port: int, planted: bool) -> tuple[subprocess.Popen, int]:
    """Godot on the game script, and the pid of the server it started, tied to it."""
    command = [str(REPO / "scripts" / "godot"), "--headless", "--path", "godot", "-s", GAME,
               "--", ending, str(port)] + (["--no-die"] if planted else [])
    game = subprocess.Popen(command, cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
    deadline = time.monotonic() + READY_SECONDS
    while time.monotonic() < deadline:
        line = game.stdout.readline()
        if line.startswith("READY "):
            server = int(line.split()[1])
            if server <= 0 or parent_of(server) != game.pid:
                stop_game(game)
                raise NotThisRun(f"pid {server} is not a server this run's game started")
            return game, server
        if line.startswith("FOUND "):
            stop_game(game)
            raise NotThisRun(line.strip())
        if not line and game.poll() is not None:
            break
    stop_game(game)
    raise NotThisRun(f"the game ({ending}) never said its server was ready")


def stop_game(game: subprocess.Popen) -> None:
    """End the game this run started, if it still runs, and read it out."""
    if game.poll() is None:
        game.kill()
    game.wait()
    game.stdout.close()


def gone_within(pid: int, seconds: float) -> bool:
    """Whether `pid` ends within `seconds`."""
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return True
        time.sleep(0.02)
    return False


def server_outlives(ending: str, sent: signal.Signals | None, planted: bool = False) -> bool:
    """End the game one way; whether its server is still running a second after."""
    game, server = start_game(ending, free_port(), planted)
    if sent is not None:
        game.send_signal(sent)
    try:
        game.wait(timeout=10)
    finally:
        stop_game(game)
    if gone_within(server, GONE_SECONDS):
        return False
    # Still running, so still the process tied to this run at READY: a pid
    # is not handed to another process while its owner lives.
    os.kill(server, signal.SIGKILL)
    return True


def found_server_refused() -> bool:
    """Planted: a server already on the port stops the run, and nothing is signalled."""
    port = free_port()
    squatter = http.server.ThreadingHTTPServer(("127.0.0.1", port), Quiet)
    threading.Thread(target=squatter.serve_forever, daemon=True).start()
    try:
        start_game("wait", port, planted=False)
    except NotThisRun as refusal:
        return "FOUND" in str(refusal)
    finally:
        squatter.shutdown()
        squatter.server_close()
    return False


def main() -> int:
    """Every ending, then the two planted cases."""
    if not sys.platform.startswith("linux"):
        print("server_ends: the parent-death signal is Linux's; nothing checked here")
        return 2
    failures = []
    try:
        for ending, sent in ENDINGS:
            name = ending if sent is None else sent.name
            outlived = server_outlives(ending, sent)
            print(f"  {name:8} server {'STILL RUNNING' if outlived else 'gone'}")
            if outlived:
                failures.append(name)
        survived = server_outlives("wait", signal.SIGKILL, planted=True)
    except NotThisRun as refusal:
        print(f"server_ends: {refusal}; nothing signalled")
        return 2
    print(f"  planted: SIGKILL, a server not told to die with the game: {'survived' if survived else 'gone'}")
    if not survived:
        failures.append("planted survivor did not survive: the check sees nothing")
    refused = found_server_refused()
    print(f"  planted: a server already on the port: {'refused, nothing signalled' if refused else 'NOT refused'}")
    if not refused:
        failures.append("a server already on the port was not refused")
    print(f"server_ends: {len(failures)} failure(s)" + (f": {', '.join(failures)}" if failures else ""))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
