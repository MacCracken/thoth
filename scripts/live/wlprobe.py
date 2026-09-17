#!/usr/bin/env python3
"""wlprobe — a minimal xdg_toplevel that logs what the compositor sends it (the CONTROL client for an A/B).

  wlprobe.py SECONDS [APP_ID]

Binds what thoth's window binds (wl_compositor v4, wl_shm v1, xdg_wm_base v1, wl_seat v5), maps an opaque window,
re-attaches a buffer at every configured size, and prints each toplevel configure, keyboard enter/leave/key and
pointer enter/axis/frame with a timestamp. When thoth misbehaves under some compositor event sequence and this
client does not, the fault is thoth's (0.52.1: a window mapped during an output rescale froze thoth and not this).
"""
import os
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wlkit import Conn  # noqa: E402


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 2
    secs = float(argv[1])
    app_id = argv[2] if len(argv) > 2 else "wlprobe"
    c = Conn()
    g = {}
    reg = c.new_id()

    def global_ev(op, p):
        if op == 0:
            name = struct.unpack_from("<I", p, 0)[0]
            iface, off = Conn.str_at(p, 4)
            g.setdefault(iface, (name, struct.unpack_from("<I", p, off)[0]))
    c.handlers[reg] = global_ev
    c.send(1, 1, Conn.u(reg))
    c.roundtrip()

    def bind(iface, v):
        oid = c.new_id()
        name, ver = g[iface]
        c.send(reg, 0, Conn.u(name) + Conn.string(iface) + Conn.u(min(v, ver)) + Conn.u(oid))
        return oid
    comp, shm, xdg, seat = bind("wl_compositor", 4), bind("wl_shm", 1), bind("xdg_wm_base", 1), bind("wl_seat", 5)
    t0 = time.time()

    def log(*a):
        print("%7.3f" % (time.time() - t0), *a, flush=True)
    c.handlers[shm] = lambda op, p: None
    c.handlers[xdg] = lambda op, p: c.send(xdg, 3, p[:4]) if op == 0 else None      # ping -> pong
    kbd, ptr = [0], [0]
    kbd_names = {0: "keymap", 1: "enter", 2: "leave", 3: "key", 4: "modifiers", 5: "repeat_info"}
    ptr_names = {0: "enter", 1: "leave", 2: "motion", 3: "button", 4: "axis", 5: "frame", 6: "axis_source",
                 7: "axis_stop", 8: "axis_discrete"}

    def seat_ev(op, p):
        if op != 0:
            return
        caps = struct.unpack_from("<I", p, 0)[0]
        log("seat capabilities", caps)
        if caps & 2 and not kbd[0]:
            kbd[0] = c.new_id()
            c.send(seat, 1, Conn.u(kbd[0]))
            c.handlers[kbd[0]] = lambda op, p: log("keyboard", kbd_names.get(op, op),
                                                   struct.unpack_from("<I", p, 8)[0] if op == 3 else "")
        if caps & 1 and not ptr[0]:
            ptr[0] = c.new_id()
            c.send(seat, 0, Conn.u(ptr[0]))
            c.handlers[ptr[0]] = lambda op, p: log("pointer", ptr_names.get(op, op)) if op != 2 else None
    c.handlers[seat] = seat_ev
    surf = c.new_id()
    c.send(comp, 0, Conn.u(surf))
    xs = c.new_id()
    c.send(xdg, 2, Conn.u(xs) + Conn.u(surf))
    top = c.new_id()
    c.send(xs, 1, Conn.u(top))
    c.send(top, 3, Conn.string(app_id))
    c.send(surf, 6)                                     # commit without a buffer: ask for the first configure
    size, pending, state = [0, 0], [640, 480], {"pool": None, "cap": 0}

    def top_ev(op, p):
        if op == 0:
            w, h = struct.unpack_from("<ii", p, 0)
            log("toplevel configure", w, h)
            if w > 0:
                pending[0] = w
            if h > 0:
                pending[1] = h
        elif op == 1:
            log("toplevel close")
    c.handlers[top] = top_ev

    def attach(w, h):
        need = w * h * 4
        if state["cap"] < need:
            fd = os.memfd_create("wlprobe", 0)
            os.ftruncate(fd, need)
            os.pwrite(fd, b"\x40\x30\x20\x00" * (w * h), 0)
            state["pool"] = c.new_id()
            c.send(shm, 0, Conn.u(state["pool"]) + Conn.i(need), fds=[fd])
            os.close(fd)
            state["cap"] = need
        buf = c.new_id()
        c.handlers[buf] = lambda op, p: None
        c.send(state["pool"], 0, Conn.u(buf) + Conn.i(0) + Conn.i(w) + Conn.i(h) + Conn.i(w * 4) + Conn.u(1))
        c.send(surf, 1, Conn.u(buf) + Conn.i(0) + Conn.i(0))
        c.send(surf, 9, Conn.i(0) + Conn.i(0) + Conn.i(w) + Conn.i(h))
        c.send(surf, 6)

    def xs_ev(op, p):
        if op == 0:
            c.send(xs, 4, p[:4])                        # ack_configure(serial)
            if tuple(pending) != tuple(size):
                size[0], size[1] = pending
                log("attach", size[0], size[1])
                attach(size[0], size[1])
    c.handlers[xs] = xs_ev
    end = time.time() + secs
    while time.time() < end:
        c.read_some(0.1)
    log("done")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
