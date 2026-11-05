#!/usr/bin/env python3
"""A server the game started stops however the game ends (T130).

The owner, 2026-11-05: "Lembre de colocar mecanismo de quando fechar o
jogo tbm fechar o servidor llm pra não ficar gastando vram" -- when the
game closes, close the LLM server too, so it does not keep spending VRAM.

Each run starts Godot headless on `server_ends_game.gd`. The game starts
`fake_llm_server.py` through `LlmLocalServer` and says the server's pid.
Then the game ends:
- by `quit()`;
- by the window's close request;
- by Ctrl+C (SIGINT with the default disposition, as a terminal sends it);
- by SIGTERM;
- by SIGKILL, which no code in the game survives to see.

The server must be gone within a second. The first two endings are the
game's own `_exit_tree`. The others are the parent-death signal that
`die_with` sets (tools/llm/llm.py, Linux).

Planted: the same SIGKILL with a server told not to die with its parent
must be seen to survive, or this check could pass on a server that was
never there. The survivor is then stopped.

Usage: python3 godot/test/ai_llm/server_ends.py   (from the repository root)
Exit codes: 0 every ending stopped the server; 1 one did not; 2 the game
never said its server was ready, or not on Linux for the signals.
"""

from __future__ import annotations

import os
import pathlib
import signal
import subprocess
import sys
import time

REPO = pathlib.Path(__file__).resolve().parents[3]
GAME = "res://test/ai_llm/server_ends_game.gd"
# One port per run, away from HttpRuntime.PORT and the gdUnit suites'.
FIRST_PORT = 39960
# Seconds the game may take to say its server is ready, and the server to go.
READY_SECONDS = 30.0
GONE_SECONDS = 1.0

ENDINGS = [("quit", None), ("close", None), ("wait", signal.SIGINT),
           ("wait", signal.SIGTERM), ("wait", signal.SIGKILL)]


def start_game(ending: str, port: int, planted: bool) -> tuple[subprocess.Popen, int]:
    """Godot on the game script, and the pid of the server it said is ready."""
    command = [str(REPO / "scripts" / "godot"), "--headless", "--path", "godot", "-s", GAME,
               "--", ending, str(port)] + (["--no-die"] if planted else [])
    game = subprocess.Popen(command, cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
    deadline = time.monotonic() + READY_SECONDS
    while time.monotonic() < deadline:
        line = game.stdout.readline()
        if line.startswith("READY "):
            return game, int(line.split()[1])
        if not line and game.poll() is not None:
            break
    game.kill()
    raise RuntimeError(f"the game ({ending}) never said its server was ready")


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


def server_outlives(ending: str, sent: signal.Signals | None, port: int, planted: bool = False) -> bool:
    """End the game one way; whether its server is still running a second after."""
    game, server = start_game(ending, port, planted)
    if sent is not None:
        game.send_signal(sent)
    try:
        game.wait(timeout=10)
    except subprocess.TimeoutExpired:
        game.kill()
        game.wait()
        os.kill(server, signal.SIGKILL)
        raise RuntimeError(f"the game ({ending}) did not end")
    game.stdout.close()
    if gone_within(server, GONE_SECONDS):
        return False
    os.kill(server, signal.SIGKILL)
    return True


def main() -> int:
    """Every ending, then the planted survivor."""
    if not sys.platform.startswith("linux"):
        print("server_ends: the parent-death signal is Linux's; nothing checked here")
        return 2
    failures = []
    for number, (ending, sent) in enumerate(ENDINGS):
        name = ending if sent is None else sent.name
        try:
            outlived = server_outlives(ending, sent, FIRST_PORT + number)
        except RuntimeError as error:
            print(f"server_ends: {error}")
            return 2
        print(f"  {name:8} server {'STILL RUNNING' if outlived else 'gone'}")
        if outlived:
            failures.append(name)
    try:
        survived = server_outlives("wait", signal.SIGKILL, FIRST_PORT + len(ENDINGS), planted=True)
    except RuntimeError as error:
        print(f"server_ends: {error}")
        return 2
    print(f"  planted: SIGKILL, a server not told to die with the game: {'survived' if survived else 'gone'}")
    if not survived:
        failures.append("planted survivor did not survive: the check sees nothing")
    print(f"server_ends: {len(failures)} failure(s)" + (f": {', '.join(failures)}" if failures else ""))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
