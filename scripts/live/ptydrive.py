#!/usr/bin/env python3
"""ptydrive — drive thoth's TUI (or any terminal program) in a real pty from a small step script.

  ptydrive.py [--home DIR] [--cwd DIR] [--size 140x40] [--env K=V ...] [--script FILE] [--log FILE] -- PROGRAM [ARGS]

The child gets a clean environment (HOME, TERM=xterm-256color, PATH=/usr/bin:/bin, LANG=C.UTF-8, plus --env) and
the window size; its output is pumped the whole time, so a step never blocks the child. Steps (stdin, or --script):

  send TEXT          type TEXT, then Enter (\\r)
  keys TEXT          raw bytes; Python escapes: \\x1b is Esc, \\x18 is Ctrl-X, \\r is Enter
  wait TEXT [SECS]   until TEXT appears in the output since the last `mark` (escapes stripped); default 10 s
  sleep SECS
  proc NAME [SECS]   until a process named exactly NAME exists (pgrep -x — never -f, which matches this shell)
  gone NAME [SECS]   until none does; reports how long it took (time an Esc: `keys \\x1b` then `gone sleep`)
  mark               start a new window for `wait` / `dump`
  dump               print the plain text since the mark
  # comment

Each step prints one JSON line. Exit 1 when a wait / proc / gone timed out, 2 on a usage error. The child is killed
at the end unless it already exited. ⚠ One-shot `thoth -p` reads an open stdin — give it </dev/null, not this.
"""
import ast
import fcntl
import json
import os
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time

ANSI = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[@-_]")


def main(argv):
    args = argv[1:]
    if "--" not in args:
        print(__doc__.strip())
        return 2
    sep = args.index("--")
    opts, prog = args[:sep], args[sep + 1:]
    if not prog:
        print(__doc__.strip())
        return 2
    home, cwd, size, script, logp, extra = os.environ.get("HOME", "/"), ".", "140x40", None, None, {}
    k = 0
    while k < len(opts):
        o = opts[k]
        v = opts[k + 1] if k + 1 < len(opts) else None
        if v is None:
            print("ptydrive: %s needs a value" % o)
            return 2
        if o == "--home":
            home = v
        elif o == "--cwd":
            cwd = v
        elif o == "--size":
            size = v
        elif o == "--script":
            script = v
        elif o == "--log":
            logp = v
        elif o == "--env":
            key, _, val = v.partition("=")
            extra[key] = val
        else:
            print("ptydrive: unknown option " + o)
            return 2
        k += 2
    cols, rows = (int(x) for x in size.split("x"))
    steps = (open(script).read() if script else sys.stdin.read()).splitlines()
    env = {"HOME": home, "TERM": "xterm-256color", "PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"}
    env.update(extra)
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(cwd)
        os.execve(prog[0], prog, env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    buf = bytearray()
    mark = [0]
    exited = [None]

    def pump(t):
        end = time.time() + t
        while True:
            rem = end - time.time()
            if rem <= 0:
                return
            r, _, _ = select.select([fd], [], [], rem)
            if r:
                try:
                    d = os.read(fd, 65536)
                except OSError:
                    d = b""
                if not d:
                    time.sleep(min(rem, 0.05))
                    return
                buf.extend(d)

    def plain():
        return ANSI.sub(b"", bytes(buf[mark[0]:])).decode("utf-8", "replace")

    def procs(name):
        return subprocess.run(["pgrep", "-x", name], capture_output=True, text=True).stdout.split()

    def until(pred, secs):
        end = time.time() + secs
        while time.time() < end:
            if pred():
                return True
            pump(0.05)
        return pred()

    failed = False
    pump(0.5)
    for raw in steps:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        cmd, _, rest = line.partition(" ")
        res = {"step": line}
        t0 = time.time()
        if cmd == "send":
            os.write(fd, rest.encode() + b"\r")
            pump(0.1)
        elif cmd == "keys":
            os.write(fd, ast.literal_eval('"' + rest.replace('"', '\\"') + '"').encode("latin-1"))
            pump(0.1)
        elif cmd == "sleep":
            pump(float(rest))
        elif cmd in ("wait", "proc", "gone"):
            parts = rest.rsplit(" ", 1)
            secs = 10.0
            if len(parts) == 2:
                try:
                    secs = float(parts[1])
                    rest = parts[0]
                except ValueError:
                    pass
            if cmd == "wait":
                ok = until(lambda: rest in plain(), secs)
            elif cmd == "proc":
                ok = until(lambda: bool(procs(rest)), secs)
            else:
                ok = until(lambda: not procs(rest), secs)
            res["ok"] = ok
            res["seconds"] = round(time.time() - t0, 2)
            failed = failed or not ok
        elif cmd == "mark":
            mark[0] = len(buf)
        elif cmd == "dump":
            res["text"] = plain()
        else:
            res["error"] = "unknown step"
            failed = True
        print(json.dumps(res), flush=True)
    pump(0.3)
    try:
        wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid == pid:
            exited[0] = os.waitstatus_to_exitcode(status)
    except ChildProcessError:
        exited[0] = "reaped"
    if exited[0] is None:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
    if logp:
        open(logp, "wb").write(bytes(buf))
    print(json.dumps({"child_exited": exited[0] is not None, "exit": exited[0], "failed": failed}), flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
