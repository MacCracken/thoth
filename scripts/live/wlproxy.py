#!/usr/bin/env python3
"""wlproxy — a logging Wayland relay: see exactly what thoth sends and what it is sent.

  wlproxy.py LISTEN_NAME LOG

Listens on $XDG_RUNTIME_DIR/LISTEN_NAME and relays each client to $WAYLAND_DISPLAY — bytes AND the fds passed with
SCM_RIGHTS — logging every message header per direction:

    t  C->S|S->C  obj=ID  op=N  size=N  the first argument words (hex u32)

Run the client with WAYLAND_DISPLAY=LISTEN_NAME. Object ids are the client's allocation order; read the log beside
the protocol XML. 0.52.1: this is what showed a wl_buffer.release arriving for a buffer the resize had already
destroyed (the window froze), and that Hyprland sends wl_pointer.axis BEFORE axis_source.
"""
import array
import os
import select
import socket
import struct
import sys
import time


def headers(tag, buf, t0):
    out = []
    while len(buf) >= 8:
        oid, w = struct.unpack_from("<II", buf, 0)
        size, op = w >> 16, w & 0xFFFF
        if size < 8 or len(buf) < size:
            break
        args = buf[8:size]
        words = " ".join("%08x" % struct.unpack_from("<I", args, k)[0] for k in range(0, min(len(args) // 4, 6) * 4, 4))
        out.append("%8.3f %s obj=%-4d op=%-2d size=%-4d %s" % (time.time() - t0, tag, oid, op, size, words))
        buf = buf[size:]
    return out, buf


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip())
        return 2
    rt = os.environ["XDG_RUNTIME_DIR"]
    upstream = os.path.join(rt, os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
    path = os.path.join(rt, argv[1])
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    ls = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    ls.bind(path)
    ls.listen(1)
    log = open(argv[2], "w", buffering=1)
    t0 = time.time()
    print("wlproxy: %s -> %s, logging to %s" % (path, upstream, argv[2]), flush=True)
    while True:
        cs, _ = ls.accept()
        ss = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        ss.connect(upstream)
        pending = {cs: b"", ss: b""}
        log.write("%8.3f client connected\n" % (time.time() - t0))
        alive = True
        while alive:
            r, _, _ = select.select([cs, ss], [], [])
            for s in r:
                try:
                    data, anc, _, _ = s.recvmsg(65536, socket.CMSG_LEN(28 * 4))
                except OSError:
                    data, anc = b"", []
                if not data:
                    alive = False
                    break
                fds = []
                for level, typ, payload in anc:
                    if level == socket.SOL_SOCKET and typ == socket.SCM_RIGHTS:
                        fds.extend(array.array("i", payload))
                dst = ss if s is cs else cs
                if fds:
                    dst.sendmsg([data], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))])
                    for fd in fds:
                        os.close(fd)
                else:
                    dst.sendall(data)
                tag = "C->S" if s is cs else "S->C"
                if fds:
                    log.write("%8.3f %s (%d fd)\n" % (time.time() - t0, tag, len(fds)))
                lines, pending[s] = headers(tag, pending[s] + data, t0)
                for line in lines:
                    log.write(line + "\n")
        log.write("%8.3f client gone\n" % (time.time() - t0))
        cs.close()
        ss.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
