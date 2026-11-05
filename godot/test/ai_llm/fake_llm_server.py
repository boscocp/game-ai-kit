#!/usr/bin/env python3
"""A stand-in for llama.cpp's server, for LlmLocalServer's tests (T130): no model.

It answers `/health` as the pinned server does (tools/server/README.md at
b11960): 503 with "Loading model" for LOADING seconds after it starts, then
200 with {"status": "ok"}. Anything else is a 404. It listens on this
machine only, as `scripts/llm serve` does, and stops by itself after
LIFETIME seconds, so a test that failed before stopping it leaves nothing
running for long.

Usage:
    fake_llm_server.py PORT LOADING      serve, ready after LOADING seconds
    fake_llm_server.py PORT exit         exit 2 at once, as `scripts/llm`
                                         does when nothing is installed
"""

from __future__ import annotations

import http.server
import json
import sys
import threading
import time

LIFETIME = 60.0


class Health(http.server.BaseHTTPRequestHandler):
    """`/health`, loading until the server's clock says otherwise."""

    ready_at: float = 0.0

    def do_GET(self) -> None:  # noqa: N802 -- the name http.server calls
        """503 while loading, 200 once ready, 404 off `/health`."""
        if self.path != "/health":
            self.answer(404, {"error": {"code": 404, "message": "File Not Found"}})
        elif time.monotonic() < self.ready_at:
            self.answer(503, {"error": {"code": 503, "message": "Loading model",
                                        "type": "unavailable_error"}})
        else:
            self.answer(200, {"status": "ok"})

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
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    if argv[2] == "exit":
        return 2
    Health.ready_at = time.monotonic() + float(argv[2])
    server = http.server.ThreadingHTTPServer(("127.0.0.1", int(argv[1])), Health)
    threading.Timer(LIFETIME, server.shutdown).start()
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
