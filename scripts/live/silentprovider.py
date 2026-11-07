#!/usr/bin/env python3
"""silentprovider — a model provider that answers, sends one token and goes quiet, for hoosh to stand in front of.

  silentprovider.py PORT

It speaks Ollama's /api/chat and OpenAI's stream, then holds the socket open with nothing on it for HOLD seconds, which is what a
stalled upstream looks like to hoosh. hoosh then sends `: keep-alive` through the stream every 15 s. The recipe is V-8 in
docs/guides/verification-pass.md.
"""
import json
import socketserver
import sys
import time
from http.server import BaseHTTPRequestHandler

HOLD = 400


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _json(self, obj):
        b = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.startswith("/api/tags"):
            return self._json({"models": [{"name": "silent", "model": "silent"}]})
        return self._json({"object": "list", "data": [{"id": "silent", "object": "model"}]})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(n)
        print("POST", self.path, flush=True)
        self.send_response(200)
        if self.path.startswith("/api/chat"):
            self.send_header("Content-Type", "application/x-ndjson")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(json.dumps({"model": "silent", "message": {"role": "assistant", "content": "partial "}, "done": False}).encode() + b"\n")
        else:
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b'data: {"id":"c","object":"chat.completion.chunk","model":"silent","choices":[{"index":0,"delta":{"content":"partial "},"finish_reason":null}]}\n\n')
        self.wfile.flush()
        try:
            time.sleep(HOLD)
        except KeyboardInterrupt:
            pass
        self.close_connection = True


class S(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True


with S(("127.0.0.1", int(sys.argv[1])), H) as s:
    print("silent provider up", flush=True)
    s.serve_forever()
