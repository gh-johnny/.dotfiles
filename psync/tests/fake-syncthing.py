"""Tiny stand-in for the Syncthing REST API, so psync can be tested without a real daemon.

usage: fake-syncthing.py PORT SCENARIO
  quiet    idle, nothing to pull, peer connected and has everything
  busy     the first 3 db/status calls report items to pull, then idle
  stuck    always items to pull, and the peer never gets a canary file
  offline  idle, peer disconnected
  paused   folder paused
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port, scenario = int(sys.argv[1]), sys.argv[2]
calls = {}


def count(key):
    calls[key] = calls.get(key, 0) + 1
    return calls[key]


def db_status():
    pending = scenario == "stuck" or (scenario == "busy" and count("db") <= 3)
    return 200, {"state": "syncing" if pending else "idle", "needTotalItems": 7 if pending else 0, "needBytes": 1}


def db_file():
    # A new file is unknown at first (404), then known locally, then available on the peer.
    n = count("file")
    if n == 1:
        return 404, {"error": "no such object"}
    if n == 2 or scenario == "stuck":
        return 200, {"availability": []}
    return 200, {"availability": [{"id": "PEER", "fromTemporary": False}]}


ROUTES = {
    "system/ping": lambda: (200, {"ping": "pong"}),
    "system/version": lambda: (200, {"version": "v0.0.0-fake"}),
    "system/status": lambda: (200, {"myID": "ME", "startTime": "2026-01-01T00:00:00Z"}),
    "config/folders/projects": lambda: (
        200,
        {"paused": scenario == "paused", "devices": [{"deviceID": "ME"}, {"deviceID": "PEER"}]},
    ),
    "db/status": db_status,
    "db/completion": lambda: (200, {"completion": 100}),
    "db/file": db_file,
    "folder/errors": lambda: (200, {"errors": None}),
    "system/connections": lambda: (200, {"connections": {"PEER": {"connected": scenario != "offline"}}}),
    "config/devices": lambda: (
        200,
        [
            {"deviceID": "ME", "name": "me", "addresses": ["dynamic"]},
            {"deviceID": "PEER", "name": "pc", "addresses": ["tcp://100.64.0.1:22000"]},
        ],
    ),
    "config/devices/PEER": lambda: (200, {"name": "pc"}),
    "stats/device": lambda: (200, {"PEER": {"lastSeen": "2026-10-20T09:00:00-03:00"}}),
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = ROUTES.get(self.path.split("?")[0].removeprefix("/rest/"))
        status, payload = route() if route else (404, {"error": "unknown route"})
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
