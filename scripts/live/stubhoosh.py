#!/usr/bin/env python3
"""stubhoosh — a scripted stand-in for the hoosh gateway, for live runs of the TUI and the window (never a spine fork:
it answers ONLY the prompts below, so a live check exercises thoth's own surfaces with no model and no key).

  stubhoosh.py PORT

OpenAI-shaped /v1/chat/completions — SSE when the request says "stream": true, else one JSON body — plus
GET /v1/models (one model: stub-model) and GET /v1/health. The LAST user message picks the reply:
  run: <cmd>     one `shell` tool call running <cmd>; once a tool result follows it, the reply is "done"
  think: <x>     reasoning_content, then content "answer about <x>"
  slow: <x>      60 short content deltas 0.5 s apart (a stream to stop, or to close the window on)
  md             a markdown reply (heading, bold, inline code, a list, a fenced block, a table, a quote)
  anything else  "hello from stub"
Each request is logged to stdout: path, stream, message count, the chosen reply.
"""
import http.server
import json
import socketserver
import sys
import time

MD = ("# Heading one\n\nSome **bold** text, some `inline code`, and a [link](http://x).\n\n"
      "- item one\n- item two\n\n```python\ndef f(x):\n    return x + 1  # comment\n```\n\n"
      "| col a | col b |\n|---|---|\n| 1 | two |\n\n> a quote\n\nerror: something failed\n")


def plan(msgs):
    users = [m for m in msgs if m.get("role") == "user"]
    if not users:
        return "text", None, "done"
    tail = msgs[msgs.index(users[-1]):]
    text = users[-1].get("content") or ""
    if isinstance(text, list):
        text = " ".join(p.get("text", "") for p in text if isinstance(p, dict))
    if any(m.get("role") == "tool" for m in tail):
        return "text", None, "done"
    if "run:" in text:
        return "tool", None, text.split("run:", 1)[1].strip()
    if "think:" in text:
        x = text.split("think:", 1)[1].strip()
        return "text", "pondering %s: first consider the premise, then weigh it, then conclude." % x, "answer about " + x
    if "slow:" in text:
        return "slow", None, None
    if text.strip() == "md":
        return "text", None, MD
    return "text", None, "hello from stub"


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/v1/models"):
            return self._json(200, {"object": "list", "data": [{"id": "stub-model", "object": "model", "owned_by": "stub"}]})
        if self.path.startswith("/v1/health"):
            return self._json(200, {"providers": []})
        return self._json(404, {"error": {"message": "not in the stub"}})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(n) or b"{}")
        msgs = body.get("messages", [])
        stream = bool(body.get("stream"))
        kind, reasoning, arg = plan(msgs)
        print("POST", self.path, "stream", stream, "msgs", len(msgs), "reply", kind, flush=True)
        if not stream:
            if kind == "tool":
                msg = {"role": "assistant", "content": None, "tool_calls": [{"id": "call_1", "type": "function",
                       "function": {"name": "shell", "arguments": json.dumps({"command": arg})}}]}
                finish = "tool_calls"
            else:
                msg = {"role": "assistant", "content": "slow reply (not streamed)" if kind == "slow" else arg}
                finish = "stop"
                if reasoning:
                    msg["reasoning_content"] = reasoning
            return self._json(200, {"id": "c1", "object": "chat.completion", "model": "stub-model",
                                    "choices": [{"index": 0, "message": msg, "finish_reason": finish}],
                                    "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}})
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()

        def event(delta, finish=None):
            chunk = {"id": "c1", "object": "chat.completion.chunk", "model": "stub-model",
                     "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}
            self.wfile.write(b"data: " + json.dumps(chunk).encode() + b"\n\n")
            self.wfile.flush()
        try:
            if kind == "tool":
                event({"role": "assistant", "tool_calls": [{"index": 0, "id": "call_1", "type": "function",
                                                            "function": {"name": "shell", "arguments": ""}}]})
                event({"tool_calls": [{"index": 0, "function": {"arguments": json.dumps({"command": arg})}}]})
                event({}, "tool_calls")
            elif kind == "slow":
                event({"role": "assistant", "content": ""})
                for k in range(60):
                    event({"content": "word%d " % k})
                    time.sleep(0.5)
                event({}, "stop")
            else:
                event({"role": "assistant", "content": ""})
                if reasoning:
                    for k in range(0, len(reasoning), 12):
                        event({"reasoning_content": reasoning[k:k + 12]})
                        time.sleep(0.02)
                for k in range(0, len(arg), 16):
                    event({"content": arg[k:k + 16]})
                    time.sleep(0.02)
                event({}, "stop")
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            print("the client went away mid-stream", flush=True)
        self.close_connection = True


class Server(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip())
        return 2
    with Server(("127.0.0.1", int(argv[1])), Handler) as s:
        print("stubhoosh: http://127.0.0.1:%s" % argv[1], flush=True)
        s.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
