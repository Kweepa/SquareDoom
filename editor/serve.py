#!/usr/bin/env python3
"""Static file server with PUT support for episode1.json autosave."""

from __future__ import annotations

import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
AUTOSAVE_NAME = "episode1.json"
MAX_BODY = 32 * 1024 * 1024


class EditorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_PUT(self):
        path = self.path.split("?", 1)[0]
        if path not in ("/" + AUTOSAVE_NAME, AUTOSAVE_NAME):
            self.send_error(403, "Only episode1.json can be written")
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BODY:
            self.send_error(400, "Invalid Content-Length")
            return
        body = self.rfile.read(length)
        target = ROOT / AUTOSAVE_NAME
        try:
            target.write_bytes(body)
        except OSError as exc:
            self.send_error(500, str(exc))
            return
        self.send_response(204)
        self.end_headers()
        print(f"Saved {target} ({length} bytes)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), EditorHandler)
    print(f"Serving {ROOT} at http://127.0.0.1:{args.port}/")
    print(f"PUT /{AUTOSAVE_NAME} writes the episode file.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
