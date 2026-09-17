#!/usr/bin/env python3
"""wlkit — a raw-wire Wayland driver for verifying thoth's window live (scripts/gui-live.sh drives it).

No bindings and no toolkit: the wire format by hand, like src/gui/gwindow.cyr. It needs a compositor that offers
  zwlr_screencopy_manager_v1   screenshots                     (Hyprland, sway / wlroots)
  zwp_virtual_keyboard_v1      keys (an XKB keymap from `xkbcli compile-keymap`)
  zwlr_virtual_pointer_v1      motion, buttons, scroll

  wlkit.py globals                          the compositor's globals
  wlkit.py outputs                          each wl_output: name and current mode
  wlkit.py shot OUT.png [X Y W H]           screenshot the output (THOTH_LIVE_OUTPUT, else the last one) or a region
  wlkit.py serve SOCKET                     hold a virtual keyboard + pointer; take commands on a unix socket
  wlkit.py send SOCKET COMMAND [ARGS...]    one command to a serving kit; prints its reply, exits 1 on an error

Commands (serve / send):
  type TEXT              type the text (US layout; Shift where a character needs it)
  key NAME               one key, with modifiers: esc ret tab bksp space up down left right home end pgup pgdn del
                         ins f1..f12, or one character; `ctrl+k`, `shift+tab`, `alt+x`, `ctrl+shift+t`
  hold NAME SECS         press a key (with modifiers, as `key`), keep it down SECS seconds, release — key repeat
  move X Y               pointer to output pixel (X, Y)
  click X Y [BUTTON]     move there and press + release left | right | middle
  scroll DY              one touchpad step of DY px (finger source; negative moves toward older content)
  wheel N                N wheel notches (negative = up)
  size                   the output size the pointer maps onto
  ping                   ok

Traps this encodes (each paid for, 0.52.1): a virtual keyboard/pointer must exist BEFORE the client binds its seat
or the client may never get the device; Hyprland applies a virtual pointer's `axis_source` only to an axis value
already in the frame, so the value is sent first; a restarted kit is a new pointer, so move it before clicking.
"""
import array
import os
import select
import socket
import struct
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngtool import write_png  # noqa: E402


def _pad(n):
    return (n + 3) & ~3


class Conn:
    def __init__(self, display=None):
        rt = os.environ["XDG_RUNTIME_DIR"]
        d = display or os.environ.get("WAYLAND_DISPLAY", "wayland-0")
        path = d if d.startswith("/") else os.path.join(rt, d)
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(path)
        self.next_id = 2                       # 1 is wl_display
        self.buf = b""
        self.fds = []
        self.handlers = {1: self._display_ev}

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    def _display_ev(self, op, p):
        if op == 0:                            # error(object, code, message)
            oid, code = struct.unpack_from("<II", p, 0)
            raise RuntimeError("wl_display.error object %d code %d: %s" % (oid, code, self.str_at(p, 8)[0]))

    @staticmethod
    def str_at(p, off):
        n = struct.unpack_from("<I", p, off)[0]
        s = p[off + 4:off + 4 + n - 1].decode("utf-8", "replace") if n else ""
        return s, off + 4 + _pad(n)

    @staticmethod
    def u(v):
        return struct.pack("<I", v & 0xFFFFFFFF)

    @staticmethod
    def i(v):
        return struct.pack("<i", int(v))

    @staticmethod
    def fixed(v):
        return struct.pack("<i", int(round(v * 256)))

    @staticmethod
    def string(s):
        b = s.encode() + b"\0"
        return struct.pack("<I", len(b)) + b + b"\0" * (_pad(len(b)) - len(b))

    def send(self, oid, op, args=b"", fds=()):
        msg = struct.pack("<II", oid, ((8 + len(args)) << 16) | op) + args
        if fds:
            self.s.sendmsg([msg], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))])
        else:
            self.s.sendall(msg)

    def fileno(self):
        return self.s.fileno()

    def read_some(self, timeout=None):
        r, _, _ = select.select([self.s], [], [], timeout)
        if not r:
            return False
        data, anc, _, _ = self.s.recvmsg(65536, socket.CMSG_LEN(64 * 4))
        if not data:
            raise RuntimeError("the compositor closed the connection")
        for level, typ, payload in anc:
            if level == socket.SOL_SOCKET and typ == socket.SCM_RIGHTS:
                for fd in array.array("i", payload):
                    os.close(fd)               # nothing here keeps a received fd (a keymap we do not read)
        self.buf += data
        while len(self.buf) >= 8:
            oid, w = struct.unpack_from("<II", self.buf, 0)
            size, op = w >> 16, w & 0xFFFF
            if size < 8 or len(self.buf) < size:
                break
            payload, self.buf = self.buf[8:size], self.buf[size:]
            h = self.handlers.get(oid)
            if h:
                h(op, payload)
        return True

    def roundtrip(self, timeout=5.0):
        done = [False]
        cb = self.new_id()
        self.handlers[cb] = lambda op, p: done.__setitem__(0, True)
        self.send(1, 0, self.u(cb))            # wl_display.sync
        end = time.time() + timeout
        while not done[0]:
            if time.time() > end:
                raise TimeoutError("no reply from the compositor")
            self.read_some(0.1)


# ---- keys: evdev codes on a US layout ----------------------------------------------------------------------------
EV = {}
for _i, _ch in enumerate("1234567890"):
    EV[_ch] = (2 + _i, False)
for _row, _start in (("qwertyuiop", 16), ("asdfghjkl", 30), ("zxcvbnm", 44)):
    for _i, _ch in enumerate(_row):
        EV[_ch] = (_start + _i, False)
        EV[_ch.upper()] = (_start + _i, True)
for _ch, _code in (("-", 12), ("=", 13), ("[", 26), ("]", 27), (";", 39), ("'", 40), ("`", 41), ("\\", 43),
                   (",", 51), (".", 52), ("/", 53), (" ", 57)):
    EV[_ch] = (_code, False)
for _ch, _base in (("!", "1"), ("@", "2"), ("#", "3"), ("$", "4"), ("%", "5"), ("^", "6"), ("&", "7"), ("*", "8"),
                   ("(", "9"), (")", "0"), ("_", "-"), ("+", "="), ("{", "["), ("}", "]"), (":", ";"), ('"', "'"),
                   ("~", "`"), ("|", "\\"), ("<", ","), (">", "."), ("?", "/")):
    EV[_ch] = (EV[_base][0], True)
NAMED = {"esc": 1, "bksp": 14, "backspace": 14, "tab": 15, "ret": 28, "enter": 28, "space": 57, "home": 102,
         "up": 103, "pgup": 104, "left": 105, "right": 106, "end": 107, "down": 108, "pgdn": 109, "ins": 110,
         "del": 111}
for _n in range(1, 11):
    NAMED["f%d" % _n] = 58 + _n
NAMED["f11"], NAMED["f12"] = 87, 88
MOD_SHIFT, MOD_CTRL, MOD_ALT = 1, 4, 8
MODS = {"shift": MOD_SHIFT, "ctrl": MOD_CTRL, "alt": MOD_ALT}
BUTTONS = {"left": 0x110, "right": 0x111, "middle": 0x112}


class Kit:
    def __init__(self, display=None):
        self.c = Conn(display)
        self.g = {}
        self.outputs = []                      # [(global name, version)]
        self.reg = self.c.new_id()
        self.c.handlers[self.reg] = self._global
        self.c.send(1, 1, Conn.u(self.reg))    # get_registry
        self.c.roundtrip()
        self.vk = self.vp = self.seat = self.shm = None
        self.out = None                        # the bound wl_output (object id) the pointer and shots use
        self.out_w, self.out_h, self.out_name = 0, 0, ""

    def _global(self, op, p):
        if op == 0:
            name = struct.unpack_from("<I", p, 0)[0]
            iface, off = Conn.str_at(p, 4)
            ver = struct.unpack_from("<I", p, off)[0]
            if iface == "wl_output":
                self.outputs.append((name, ver))
            self.g.setdefault(iface, (name, ver))

    def bind(self, iface, want, name=None):
        if name is None and iface not in self.g:
            raise RuntimeError("the compositor offers no " + iface)
        gname, ver = self.g[iface] if name is None else (name, want)
        oid = self.c.new_id()
        v = min(ver, want)
        self.c.send(self.reg, 0, Conn.u(gname) + Conn.string(iface) + Conn.u(v) + Conn.u(oid))
        return oid

    def describe_outputs(self):
        """[(object id, name, w, h)] for every output; binds each once."""
        res = []
        for gname, ver in self.outputs:
            st = {"name": "", "w": 0, "h": 0}
            oid = self.bind("wl_output", min(ver, 4), name=gname)

            def ev(op, p, st=st):
                if op == 1:                    # mode(flags, width, height, refresh)
                    flags, w, h = struct.unpack_from("<Iii", p, 0)
                    if flags & 1:
                        st["w"], st["h"] = w, h
                elif op == 4:                  # name (v4)
                    st["name"] = Conn.str_at(p, 0)[0]
            self.c.handlers[oid] = ev
            res.append((oid, st))
        self.c.roundtrip()
        return [(oid, st["name"], st["w"], st["h"]) for oid, st in res]

    def pick_output(self):
        if self.out is not None:
            return
        outs = self.describe_outputs()
        if not outs:
            raise RuntimeError("the compositor advertises no wl_output")
        want = os.environ.get("THOTH_LIVE_OUTPUT", "")
        pick = [o for o in outs if o[1] == want] if want else []
        self.out, self.out_name, self.out_w, self.out_h = (pick or outs)[-1]

    # ---- input ---------------------------------------------------------------------------------------------------
    def ensure_input(self):
        if self.vk:
            return
        self.pick_output()
        self.seat = self.bind("wl_seat", 5)
        self.c.handlers[self.seat] = lambda op, p: None
        vkm = self.bind("zwp_virtual_keyboard_manager_v1", 1)
        vpm = self.bind("zwlr_virtual_pointer_manager_v1", 2)
        keymap = subprocess.run(["xkbcli", "compile-keymap", "--layout", "us"], capture_output=True,
                                check=True).stdout + b"\0"
        self.vk = self.c.new_id()
        self.c.send(vkm, 0, Conn.u(self.seat) + Conn.u(self.vk))
        fd = os.memfd_create("wlkit-keymap", 0)
        os.write(fd, keymap)
        self.c.send(self.vk, 0, Conn.u(1) + Conn.u(len(keymap)), fds=[fd])     # keymap(XKB_V1, fd, size)
        os.close(fd)
        self.vp = self.c.new_id()
        if self.g["zwlr_virtual_pointer_manager_v1"][1] >= 2:                   # mapped onto OUR output
            self.c.send(vpm, 2, Conn.u(self.seat) + Conn.u(self.out) + Conn.u(self.vp))   # opcode 2 (1 is destroy)
        else:
            self.c.send(vpm, 0, Conn.u(self.seat) + Conn.u(self.vp))
        self.c.roundtrip()

    def _t(self):
        return int(time.monotonic() * 1000) & 0xFFFFFFFF

    def _mods(self, depressed):
        self.c.send(self.vk, 2, Conn.u(depressed) + Conn.u(0) + Conn.u(0) + Conn.u(0))

    def keycode(self, code, mods=0):
        self.ensure_input()
        if mods:
            self._mods(mods)
        self.c.send(self.vk, 1, Conn.u(self._t()) + Conn.u(code) + Conn.u(1))
        self.c.send(self.vk, 1, Conn.u(self._t()) + Conn.u(code) + Conn.u(0))
        if mods:
            self._mods(0)
        self.c.roundtrip()

    def _resolve(self, spec):
        parts = spec.split("+") if len(spec) > 1 else [spec]
        mods = 0
        for m in parts[:-1]:
            if m.lower() not in MODS:
                raise ValueError("unknown modifier " + m)
            mods |= MODS[m.lower()]
        name = parts[-1]
        if name.lower() in NAMED:
            return NAMED[name.lower()], mods
        if name not in EV:
            raise ValueError("no key for %r" % name)
        code, shift = EV[name]
        return code, mods | (MOD_SHIFT if shift else 0)

    def hold(self, spec, secs):
        """press, keep the key down `secs` (the CLIENT must repeat it — Wayland compositors send no repeats), release."""
        self.ensure_input()
        code, mods = self._resolve(spec)
        if mods:
            self._mods(mods)
        self.c.send(self.vk, 1, Conn.u(self._t()) + Conn.u(code) + Conn.u(1))
        self.c.roundtrip()
        end = time.time() + secs
        while time.time() < end:
            self.c.read_some(0.05)
        self.c.send(self.vk, 1, Conn.u(self._t()) + Conn.u(code) + Conn.u(0))
        if mods:
            self._mods(0)
        self.c.roundtrip()

    def key(self, spec):
        parts = spec.split("+") if len(spec) > 1 else [spec]
        mods = 0
        for m in parts[:-1]:
            if m.lower() not in MODS:
                raise ValueError("unknown modifier " + m)
            mods |= MODS[m.lower()]
        name = parts[-1]
        if name.lower() in NAMED:
            return self.keycode(NAMED[name.lower()], mods)
        if name not in EV:
            raise ValueError("no key for %r" % name)
        code, shift = EV[name]
        return self.keycode(code, mods | (MOD_SHIFT if shift else 0))

    def type_text(self, text):
        for ch in text:
            if ch not in EV:
                raise ValueError("no key for %r" % ch)
            code, shift = EV[ch]
            self.keycode(code, MOD_SHIFT if shift else 0)

    def move(self, x, y):
        self.ensure_input()
        self.c.send(self.vp, 1, Conn.u(self._t()) + Conn.u(int(x)) + Conn.u(int(y))
                    + Conn.u(self.out_w) + Conn.u(self.out_h))                    # motion_absolute
        self.c.send(self.vp, 4)                                                   # frame
        self.c.roundtrip()

    def click(self, x, y, button="left"):
        self.move(x, y)
        b = BUTTONS[button]
        for state in (1, 0):
            self.c.send(self.vp, 2, Conn.u(self._t()) + Conn.u(b) + Conn.u(state))
            self.c.send(self.vp, 4)
            self.c.roundtrip()

    def scroll(self, dy):
        """one touchpad step: axis FIRST, then its source (Hyprland drops a source that precedes the value)."""
        self.ensure_input()
        self.c.send(self.vp, 3, Conn.u(self._t()) + Conn.u(0) + Conn.fixed(dy))   # axis(vertical)
        self.c.send(self.vp, 5, Conn.u(1))                                          # axis_source(finger)
        self.c.send(self.vp, 4)
        self.c.roundtrip()
        self.c.send(self.vp, 6, Conn.u(self._t()) + Conn.u(0))                      # axis_stop
        self.c.send(self.vp, 5, Conn.u(1))
        self.c.send(self.vp, 4)
        self.c.roundtrip()

    def wheel(self, notches):
        self.ensure_input()
        step = 1 if notches > 0 else -1
        for _ in range(abs(int(notches))):
            self.c.send(self.vp, 7, Conn.u(self._t()) + Conn.u(0) + Conn.fixed(15 * step) + Conn.i(step))
            self.c.send(self.vp, 5, Conn.u(0))                                      # axis_source(wheel)
            self.c.send(self.vp, 4)
            self.c.roundtrip()

    # ---- screenshots ---------------------------------------------------------------------------------------------
    def shot(self, path, region=None):
        self.pick_output()
        if not self.shm:
            self.shm = self.bind("wl_shm", 1)
            self.c.handlers[self.shm] = lambda op, p: None
        mgr = self.bind("zwlr_screencopy_manager_v1", 3)
        mver = min(self.g["zwlr_screencopy_manager_v1"][1], 3)
        st = {"buf": None, "done": False, "ready": False, "failed": False, "flags": 0}
        frame = self.c.new_id()

        def fev(op, p):
            if op == 0:
                st["buf"] = struct.unpack_from("<IIII", p, 0)                       # format, w, h, stride
            elif op == 1:
                st["flags"] = struct.unpack_from("<I", p, 0)[0]
            elif op == 2:
                st["ready"] = True
            elif op == 3:
                st["failed"] = True
            elif op == 6:
                st["done"] = True
        self.c.handlers[frame] = fev
        if region:
            x, y, w, h = region
            self.c.send(mgr, 1, Conn.u(frame) + Conn.i(0) + Conn.u(self.out) + Conn.i(x) + Conn.i(y)
                        + Conn.i(w) + Conn.i(h))
        else:
            self.c.send(mgr, 0, Conn.u(frame) + Conn.i(0) + Conn.u(self.out))
        end = time.time() + 5
        while not (st["done"] or st["failed"] or (mver < 3 and st["buf"])):
            if time.time() > end:
                raise TimeoutError("screencopy offered no buffer")
            self.c.read_some(0.1)
        if st["failed"] or not st["buf"]:
            raise RuntimeError("screencopy failed")
        fmt, w, h, stride = st["buf"]
        size = stride * h
        fd = os.memfd_create("wlkit-shot", 0)
        os.ftruncate(fd, size)
        pool = self.c.new_id()
        self.c.send(self.shm, 0, Conn.u(pool) + Conn.i(size), fds=[fd])
        buf = self.c.new_id()
        self.c.handlers[buf] = lambda op, p: None
        self.c.send(pool, 0, Conn.u(buf) + Conn.i(0) + Conn.i(w) + Conn.i(h) + Conn.i(stride) + Conn.u(fmt))
        self.c.send(frame, 0, Conn.u(buf))                                          # copy
        end = time.time() + 5
        while not (st["ready"] or st["failed"]):
            if time.time() > end:
                raise TimeoutError("screencopy never finished")
            self.c.read_some(0.1)
        data = os.pread(fd, size, 0)
        os.close(fd)
        self.c.send(buf, 0)
        self.c.send(pool, 1)
        self.c.send(frame, 1)
        self.c.send(mgr, 2)
        if st["failed"]:
            raise RuntimeError("screencopy copy failed")
        rows = []
        for yy in range(h):
            row = data[yy * stride:yy * stride + w * 4]
            rgb = bytearray(w * 3)
            if fmt in (0, 1):                  # wl_shm ARGB/XRGB8888, little-endian B G R A
                rgb[0::3], rgb[1::3], rgb[2::3] = row[2::4], row[1::4], row[0::4]
            else:                              # XBGR/ABGR8888: R G B A
                rgb[0::3], rgb[1::3], rgb[2::3] = row[0::4], row[1::4], row[2::4]
            rows.append(bytes(rgb))
        if st["flags"] & 1:                    # Y_INVERT
            rows.reverse()
        write_png(path, w, h, rows)
        return w, h


def run_command(kit, line):
    parts = line.rstrip("\n").split(" ", 1)
    cmd, arg = parts[0], (parts[1] if len(parts) > 1 else "")
    a = arg.split()
    if cmd == "ping":
        return "ok"
    if cmd == "type":
        kit.type_text(arg)
    elif cmd == "key":
        kit.key(arg.strip())
    elif cmd == "hold":
        kit.hold(a[0], float(a[1]))
    elif cmd == "move":
        kit.move(int(a[0]), int(a[1]))
    elif cmd == "click":
        kit.click(int(a[0]), int(a[1]), a[2] if len(a) > 2 else "left")
    elif cmd == "scroll":
        kit.scroll(float(a[0]))
    elif cmd == "wheel":
        kit.wheel(int(a[0]))
    elif cmd == "size":
        kit.ensure_input()
        return "ok %dx%d %s" % (kit.out_w, kit.out_h, kit.out_name)
    else:
        raise ValueError("unknown command " + cmd)
    return "ok"


def serve(path):
    kit = Kit()
    kit.ensure_input()                         # the devices exist before any client binds its seat
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    ls = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    ls.bind(path)
    ls.listen(4)
    print("wlkit: serving on %s (output %s %dx%d)" % (path, kit.out_name or "?", kit.out_w, kit.out_h), flush=True)
    while True:
        r, _, _ = select.select([ls, kit.c], [], [])
        if kit.c in r:
            kit.c.read_some(0)                 # keep the compositor's events drained
        if ls in r:
            cs, _ = ls.accept()
            with cs:
                data = b""
                while not data.endswith(b"\n"):
                    chunk = cs.recv(4096)
                    if not chunk:
                        break
                    data += chunk
                line = data.decode("utf-8", "replace")
                if line.strip() == "quit":
                    cs.sendall(b"ok\n")
                    return 0
                try:
                    reply = run_command(kit, line)
                except Exception as e:         # a bad command must not kill the devices the window holds
                    reply = "ERR %s" % e
                print(line.strip()[:120], "->", reply, flush=True)
                cs.sendall(reply.encode() + b"\n")


def send(path, words):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(path)
    s.sendall((" ".join(words) + "\n").encode())
    reply = b""
    while not reply.endswith(b"\n"):
        chunk = s.recv(4096)
        if not chunk:
            break
        reply += chunk
    text = reply.decode().strip()
    print(text)
    return 0 if text.startswith("ok") else 1


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 2
    cmd = argv[1]
    if cmd == "globals":
        for iface, (_, v) in sorted(Kit().g.items()):
            print("%s v%d" % (iface, v))
        return 0
    if cmd == "outputs":
        for _, name, w, h in Kit().describe_outputs():
            print("%s %dx%d" % (name or "?", w, h))
        return 0
    if cmd == "shot" and len(argv) in (3, 7):
        region = tuple(map(int, argv[3:7])) if len(argv) == 7 else None
        w, h = Kit().shot(argv[2], region)
        print("%s %dx%d" % (argv[2], w, h))
        return 0
    if cmd == "serve" and len(argv) == 3:
        return serve(argv[2])
    if cmd == "send" and len(argv) >= 4:
        return send(argv[2], argv[3:])
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
