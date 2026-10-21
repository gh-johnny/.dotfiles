"""Tiny stand-in for the Syncthing REST API, so psync can be tested without a real daemon.

usage: fake-syncthing.py PORT SCENARIO [HOME]
  quiet    idle, nothing to pull, peer connected and has everything
  busy     the first 3 db/status calls report items to pull, then idle
  stuck    always items to pull, and the peer never gets a canary file
  offline  idle, peer disconnected
  paused   folder paused
  staggered     idle, but projects keeps its old versions with staggered versioning
  firstsetup    idle, and the listen address is still Syncthing's default (setup was never run)
Two folders (projects and claude) instead of one:
  multi              both idle, peer has everything
  multi-busy         claude has items to pull for its first 3 db/status calls, then idle
  multi-notshared    the peer has not added claude
  multi-paused       claude is paused, projects is not
Writes (PUT, POST, PATCH, DELETE) are accepted and, when FAKE_LOG is set, appended to that file as
"METHOD path body".
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

port, scenario = int(sys.argv[1]), sys.argv[2]
home = sys.argv[3] if len(sys.argv) > 3 else "/home/fake"
calls = {}

MULTI = scenario.startswith("multi")
FOLDERS = ["projects", "claude"] if MULTI else ["projects"]
PATHS = {"projects": f"{home}/projects", "claude": f"{home}/.claude/projects"}
PAUSED = {"projects"} if scenario == "paused" else {"claude"} if scenario == "multi-paused" else set()
BUSY_FOLDER = "claude" if scenario == "multi-busy" else "projects"


def count(key):
    calls[key] = calls.get(key, 0) + 1
    return calls[key]


def db_status(q):
    folder = q.get("folder", ["projects"])[0]
    busy = scenario in ("busy", "multi-busy") and folder == BUSY_FOLDER and count("db:" + folder) <= 3
    pending = scenario == "stuck" or busy
    return 200, {"state": "syncing" if pending else "idle", "needTotalItems": 7 if pending else 0, "needBytes": 1}


def db_completion(q):
    folder = q.get("folder", ["projects"])[0]
    if scenario == "multi-notshared" and folder == "claude":
        return 200, {"completion": 0, "remoteState": "unknown"}  # what Syncthing 2.1 reports (see mesh.sh)
    return 200, {"completion": 100, "remoteState": "valid"}


def db_file(q):
    # A new file is unknown at first (404), then known locally, then available on the peer.
    n = count("file:" + q.get("folder", ["projects"])[0])
    if n == 1:
        return 404, {"error": "no such object"}
    if n == 2 or scenario == "stuck":
        return 200, {"availability": []}
    return 200, {"availability": [{"id": "PEER", "fromTemporary": False}]}


def folder_config(folder):
    return {
        "id": folder,
        "path": PATHS[folder],
        "paused": folder in PAUSED,
        "devices": [{"deviceID": "ME"}, {"deviceID": "PEER"}],
        "versioning": {"type": "staggered" if scenario == "staggered" else "trashcan"},
    }


def one_folder(path):
    folder = path.removeprefix("config/folders/")
    return (200, folder_config(folder)) if folder in FOLDERS else (404, {"error": "no such folder"})


ROUTES = {
    "system/ping": lambda q: (200, {"ping": "pong"}),
    "system/version": lambda q: (200, {"version": "v0.0.0-fake"}),
    "system/status": lambda q: (200, {"myID": "ME", "startTime": "2026-01-01T00:00:00Z"}),
    "config/folders": lambda q: (200, [folder_config(f) for f in FOLDERS]),
    "config/options": lambda q: (
        200,
        {"listenAddresses": ["default"] if scenario == "firstsetup" else ["tcp://127.0.0.1:22000"]},
    ),
    "config/defaults/folder": lambda q: (
        200,
        {"versioning": {"type": "", "params": {}, "cleanupIntervalS": 3600, "fsPath": "", "fsType": "basic"}},
    ),
    "db/status": db_status,
    "db/completion": db_completion,
    "db/file": db_file,
    "folder/errors": lambda q: (200, {"errors": None}),
    "system/connections": lambda q: (200, {"connections": {"PEER": {"connected": scenario != "offline"}}}),
    "config/devices": lambda q: (
        200,
        [
            {"deviceID": "ME", "name": "me", "addresses": ["dynamic"]},
            {"deviceID": "PEER", "name": "pc", "addresses": ["tcp://100.64.0.1:22000"]},
        ],
    ),
    "config/devices/PEER": lambda q: (200, {"name": "pc"}),
    "stats/device": lambda q: (200, {"PEER": {"lastSeen": "2026-10-20T09:00:00-03:00"}}),
}


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        path = url.path.removeprefix("/rest/")
        route = ROUTES.get(path)
        if route is None and path.startswith("config/folders/"):
            route = lambda q: one_folder(path)  # noqa: E731
        status, payload = route(parse_qs(url.query)) if route else (404, {"error": "unknown route"})
        self.reply(status, payload)

    def write(self):
        size = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(size).decode() if size else ""
        try:
            body = json.dumps(json.loads(body), separators=(",", ":"), sort_keys=True)
        except ValueError:
            pass
        if os.environ.get("FAKE_LOG"):
            with open(os.environ["FAKE_LOG"], "a") as log:
                log.write(f"{self.command} {self.path.removeprefix('/rest/')} {body}\n")
        self.reply(200, {})

    do_PUT = do_POST = do_PATCH = do_DELETE = write

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
