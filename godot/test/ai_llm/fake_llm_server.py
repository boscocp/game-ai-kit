#!/usr/bin/env python3
"""A stand-in for llama.cpp's server, for LlmLocalServer's tests (T130): no model.

It answers `/health` as the pinned server does (tools/server/README.md at
b11960): 503 with "Loading model" for LOADING seconds after it starts, then
200 with {"status": "ok"}, never asking for a key. `/v1/chat/completions`
answers one fixed reply -- or, when started with a key (`--api-key`, or
LLAMA_API_KEY in its environment, as `LlmLocalServer` hands it down), 401
to a request without `Authorization: Bearer KEY`, in the shape the pinned server was
measured to answer (docs/godot/talk.md). Anything else is a 404. It
listens on this machine only, as `scripts/llm serve` does, and stops by
itself after LIFETIME seconds (or `--lifetime S`), so a test that failed
before stopping it leaves nothing running for long. Given `--parent-pid`, it dies with that
parent through the same `die_with` `scripts/llm serve` uses
(tools/llm/llm.py), so a test of how the game ends tests that function;
`--no-die` skips it, for the planted case that must be seen to survive.
Two ways to be a bad server: `--silent` listens and never says a word (a
connection is accepted by the system and nothing is ever read or sent);
`--deaf-after S` serves, then closes its port after S seconds and keeps
running -- a server hung, as far as anyone asking can tell.

Usage:
    fake_llm_server.py PORT LOADING [--no-die] [--silent] [--deaf-after S]
                       [--api-key KEY] [--parent-pid PID] [--lifetime S]
    fake_llm_server.py PORT exit [...]   exit 2 at once, as `scripts/llm`
                                         does when nothing is installed
"""

from __future__ import annotations

import argparse
import http.server
import json
import os
import pathlib
import socket
import sys
import threading
import time

LIFETIME = 60.0
# tools/llm/, where `die_with` is: this file is godot/test/ai_llm/.
TOOLS_LLM = pathlib.Path(__file__).resolve().parents[3] / "tools" / "llm"
# The reply a model would give, as the validator in the tests expects it.
REPLY = {"speech": "Evening.", "intent": "greet", "argument": ""}


class Server(http.server.BaseHTTPRequestHandler):
    """`/health`, loading until the server's clock says otherwise, and chat."""

    ready_at: float = 0.0
    api_key: str = ""

    def do_GET(self) -> None:  # noqa: N802 -- the name http.server calls
        """503 while loading, 200 once ready, 404 off `/health`."""
        if self.path != "/health":
            self.answer(404, {"error": {"code": 404, "message": "File Not Found"}})
        elif time.monotonic() < self.ready_at:
            self.answer(503, {"error": {"code": 503, "message": "Loading model",
                                        "type": "unavailable_error"}})
        else:
            self.answer(200, {"status": "ok"})

    def do_POST(self) -> None:  # noqa: N802 -- the name http.server calls
        """The fixed reply, or 401 without the key the server was started with."""
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path != "/v1/chat/completions":
            self.answer(404, {"error": {"code": 404, "message": "File Not Found"}})
        elif self.api_key and self.headers.get("Authorization") != f"Bearer {self.api_key}":
            self.answer(401, {"error": {"code": 401, "message": "Invalid API Key",
                                        "type": "authentication_error"}})
        else:
            self.answer(200, {"choices": [{"message": {"role": "assistant",
                                                       "content": json.dumps(REPLY)}}]})

    def answer(self, status: int, body: dict) -> None:
        """One JSON answer, closed after it."""
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_: object) -> None:
        """Quiet: a test reads states, not a log."""


def main(argv: list[str]) -> int:
    """Serve until LIFETIME runs out, or exit 2 when asked to."""
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("port", type=int)
    parser.add_argument("loading")
    parser.add_argument("--api-key", default="")
    parser.add_argument("--parent-pid", type=int, default=0)
    parser.add_argument("--no-die", action="store_true")
    parser.add_argument("--silent", action="store_true")
    parser.add_argument("--deaf-after", type=float, default=0.0)
    parser.add_argument("--lifetime", type=float, default=LIFETIME)
    args = parser.parse_args(argv[1:])
    if args.loading == "exit":
        return 2
    if args.parent_pid and not args.no_die:
        sys.path.insert(0, str(TOOLS_LLM))
        import llm  # noqa: PLC0415 -- only when asked, and from the toolchain's folder
        llm.die_with(args.parent_pid)
    if args.silent:
        return say_nothing(args.port, args.lifetime)
    Server.ready_at = time.monotonic() + float(args.loading)
    Server.api_key = args.api_key or os.environ.get("LLAMA_API_KEY", "")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), Server)
    threading.Timer(args.lifetime, server.shutdown).start()
    if args.deaf_after:
        threading.Timer(args.deaf_after, go_deaf, [server]).start()
    server.serve_forever()
    time.sleep(args.lifetime if args.deaf_after else 0.0)
    return 0


def go_deaf(server: http.server.ThreadingHTTPServer) -> None:
    """Close the port and stop serving; the process stays, as a hung one would."""
    server.shutdown()
    server.server_close()


def say_nothing(port: int, lifetime: float) -> int:
    """Listen on `port` for `lifetime` seconds, accepting nothing, answering nothing."""
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", port))
    listener.listen(64)
    time.sleep(lifetime)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
