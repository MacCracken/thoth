#!/usr/bin/env python3
"""stubhoosh — a scripted stand-in for the hoosh gateway, for live runs of the TUI and the window (never a spine fork:
it answers ONLY the prompts below, so a live check exercises thoth's own surfaces with no model and no key).

  stubhoosh.py PORT

OpenAI-shaped /v1/chat/completions — SSE when the request says "stream": true, else one JSON body — plus
GET /v1/models (one model: stub-model) and GET /v1/health. The LAST user message picks the reply:
  run: <cmd>     one `shell` tool call running <cmd>; once a tool result follows it, the reply is "done"
  slowrun: <cmd> the same tool call, sent after a 2 s pause (a turn to resize the terminal in)
  curly          the same tool call with curly quotes and a dash in its command (the kit cannot type them)
  read: <path>   one `read_file` tool call on <path>; once a result follows it, the reply is "done"
  think: <x>     reasoning_content, then content "answer about <x>"
  slow: <x>      60 short content deltas 0.5 s apart (a stream to stop, or to close the window on)
  call: <tool>   one tool call of that name with no arguments, then "done" once its result comes back (the result is logged)
  stall: <n>     one content delta, then only `: keep-alive` comments for n seconds: hoosh with a provider gone quiet
  md             a markdown reply (heading, bold, inline code, a list, a fenced block, a table, a quote)
  cut: <x>       content "partial answer about <x>", then finish_reason "length" (the output ceiling)
  thinkcut: <x>  reasoning_content only, then finish_reason "length" with no content (cut while thinking)
  refuse         no content, finish_reason "content_filter" (a provider's safety refusal, as hoosh 2.8.0 maps it)
  big: <n>       about n bytes of numbered 64-byte lines ending in a line "END-OF-REPLY", in small deltas
  bigchunked: <n> the same, sent with Transfer-Encoding: chunked (what a real gateway does)
  bigthink: <n>  about n bytes of the same lines as reasoning_content, then content "answer after thinking"
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


def bigtext(n):
    lines = ["L%08d %s\n" % (k, "x" * 54) for k in range(max(n, 64) // 64)]
    return "".join(lines) + "END-OF-REPLY\n"


def plan(msgs):
    users = [m for m in msgs if m.get("role") == "user"]
    if not users:
        return "text", None, "done"
    tail = msgs[msgs.index(users[-1]):]
    text = users[-1].get("content") or ""
    if isinstance(text, list):
        text = " ".join(p.get("text", "") for p in text if isinstance(p, dict))
    if any(m.get("role") == "tool" for m in tail):
        for m in tail:
            if m.get("role") == "tool":
                print("TOOLRESULT", str(m.get("content"))[:300], flush=True)
        return "text", None, "done"
    if text.strip() == "curly":  # a command the kit cannot type: the confirm card must draw these bytes, not ASCII
        return "tool", None, "echo \u201cquoted\u201d \u2014 done"
    if "call:" in text:
        return "calltool", None, text.split("call:", 1)[1].strip()
    if "read:" in text:
        return "readtool", None, text.split("read:", 1)[1].strip()
    if "slowrun:" in text:
        return "slowtool", None, text.split("slowrun:", 1)[1].strip()
    if "run:" in text:
        return "tool", None, text.split("run:", 1)[1].strip()
    if "thinkcut:" in text:
        x = text.split("thinkcut:", 1)[1].strip()
        return "cut", "pondering %s at length, and still pondering when the ceiling arrives" % x, ""
    if "cut:" in text:
        return "cut", None, "partial answer about " + text.split("cut:", 1)[1].strip()
    if text.strip() == "refuse":
        return "refuse", None, ""
    if "bigthink:" in text:
        return "bigthink", bigtext(int(text.split("bigthink:", 1)[1].strip())), "answer after thinking"
    if "bigchunked:" in text:
        return "bigchunked", None, bigtext(int(text.split("bigchunked:", 1)[1].strip()))
    if "big:" in text:
        return "big", None, bigtext(int(text.split("big:", 1)[1].strip()))
    if "think:" in text:
        x = text.split("think:", 1)[1].strip()
        return "text", "pondering %s: first consider the premise, then weigh it, then conclude." % x, "answer about " + x
    if "stall:" in text:
        return "stall", None, text.split("stall:", 1)[1].strip()
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
        for t in body.get("tools") or []:
            f = t.get("function", {})
            print("TOOL", f.get("name"), "|", f.get("description"), flush=True)
        if kind == "slowtool":
            time.sleep(2)
            kind = "tool"
        tool_name, tool_args = "shell", {"command": arg}
        if kind == "readtool":
            kind, tool_name, tool_args = "tool", "read_file", {"path": arg}
        if kind == "calltool":
            kind, tool_name, tool_args = "tool", arg, {}
        finish_word = {"cut": "length", "refuse": "content_filter"}.get(kind, "stop")
        if not stream:
            if kind == "tool":
                msg = {"role": "assistant", "content": None, "tool_calls": [{"id": "call_1", "type": "function",
                       "function": {"name": tool_name, "arguments": json.dumps(tool_args)}}]}
                finish = "tool_calls"
            else:
                msg = {"role": "assistant", "content": "slow reply (not streamed)" if kind == "slow" else arg}
                finish = finish_word
                if reasoning:
                    msg["reasoning_content"] = reasoning
            return self._json(200, {"id": "c1", "object": "chat.completion", "model": "stub-model",
                                    "choices": [{"index": 0, "message": msg, "finish_reason": finish}],
                                    "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}})
        chunked = kind == "bigchunked"
        if chunked:
            self.protocol_version = "HTTP/1.1"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        if chunked:
            self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        def send(raw):
            if chunked:
                raw = b"%x\r\n" % len(raw) + raw + b"\r\n"
            self.wfile.write(raw)

        def event(delta, finish=None):
            chunk = {"id": "c1", "object": "chat.completion.chunk", "model": "stub-model",
                     "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}
            send(b"data: " + json.dumps(chunk).encode() + b"\n\n")
            self.wfile.flush()
        try:
            if kind == "tool":
                event({"role": "assistant", "tool_calls": [{"index": 0, "id": "call_1", "type": "function",
                                                            "function": {"name": tool_name, "arguments": ""}}]})
                event({"tool_calls": [{"index": 0, "function": {"arguments": json.dumps(tool_args)}}]})
                event({}, "tool_calls")
            elif kind == "stall":
                event({"role": "assistant", "content": "stalled "})
                for k in range(int(float(arg) * 2)):
                    time.sleep(0.5)
                    send(b": keep-alive\n\n")
                    self.wfile.flush()
                event({}, "stop")
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
                        if not kind.startswith("big"):
                            time.sleep(0.02)
                for k in range(0, len(arg), 16):
                    event({"content": arg[k:k + 16]})
                    if not kind.startswith("big"):
                        time.sleep(0.02)
                event({}, finish_word)
            if (body.get("stream_options") or {}).get("include_usage"):
                send(b"data: " + json.dumps({"id": "c1", "object": "chat.completion.chunk", "model": "stub-model", "choices": [],
                                             "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}}).encode() + b"\n\n")
            send(b"data: [DONE]\n\n")
            if chunked:
                self.wfile.write(b"0\r\n\r\n")
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
