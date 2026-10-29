"""A stand-in for a local LLM server, for measuring a request and nothing else.

It answers every POST, after a stated delay, with the shape an
OpenAI-compatible `/v1/chat/completions` endpoint answers (llama.cpp's server
is one): one choice whose message content is a fixed reply. There is no model
behind it. It exists so `godot/test/ai_llm/http_frame_probe.gd` can time a
frame while a request is in flight, with threads on and off, on a machine with
no LLM installed -- tier 1 and 2, as invariant 5 asks.

    PYTHONPATH=python python3 -m gameaikit.llm.stub_server --port 8765 --delay 0.5

It prints `listening on PORT` once it can be reached, and serves until killed.
"""

from __future__ import annotations

import argparse
import http.server
import json
import sys
import time

# What the stub says. A valid reply for a game that declares `greet`, so a
# runtime that gets this far has something its validator accepts.
REPLY = {"speech": "Evening. Papers, please.", "intent": "greet", "argument": ""}


def completion_body() -> bytes:
    """The body an OpenAI-compatible server returns, with `REPLY` as content."""
    answer = {"choices": [{"message": {"role": "assistant",
                                       "content": json.dumps(REPLY)}}]}
    return json.dumps(answer).encode("utf-8")


def handler_waiting(delay: float) -> type[http.server.BaseHTTPRequestHandler]:
    """A request handler that sleeps `delay` seconds before every answer."""

    class Handler(http.server.BaseHTTPRequestHandler):

        def do_POST(self) -> None:  # noqa: N802 -- the name http.server calls
            length = int(self.headers.get("Content-Length", "0"))
            self.rfile.read(length)
            time.sleep(delay)
            body = completion_body()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *ignored: object) -> None:
            """Quiet: the probe's output is the measurement, not a log of requests."""

    return Handler


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--delay", type=float, default=0.5)
    args = parser.parse_args(argv)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port),
                                             handler_waiting(args.delay))
    print(f"listening on {args.port}", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
