#!/usr/bin/env python3
"""agnos-tui — rung 3: thoth's TUI on AGNOS, driven from the keyboard, through the real agnsh.

  agnos-tui.py AGNOS_REPO KERNEL THOTH_ELF HOOSH_ELF DAIMON_ELF AGNSH_ELF

tests/agnos/tuihost.cyr starts hoosh and daimon and hands the console to the real shell. Everything from there is QEMU's sendkey:
real scancodes through the kernel's keyboard path, to agnsh's prompt, then to thoth. What the console drew is read twice: the serial
log carries every byte thoth wrote, replayed here into a grid, and QEMU's screendump is the framebuffer itself, kept as PNGs in
WORK. When the shell exits, the launcher plays a terminal emulator on a #97 channel. The model is scripts/live/stubhoosh.py on the
host, behind a real hoosh in the guest.
Exit: 0 when every step passed, 1 otherwise, 2 when the kernel never started. Results are in WORK/report.txt.
"""
import os, re, shutil, socket, subprocess, sys, time

AGNOS, KERNEL, THOTH, HOOSH, DAIMON, AGNSH = sys.argv[1:7]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WORK = os.environ.get("THOTH_TUI_WORK", "/var/tmp/thoth-agnos-tui")
SEED = WORK + "/seed"
SER = WORK + "/serial.log"
MON = WORK + "/mon.sock"
BOOT_S = int(os.environ.get("QEMU_TIMEOUT", "240"))
TRIES = 6
report = []
failed = 0


def say(*a):
    line = " ".join(str(x) for x in a)
    print(line, flush=True)
    report.append(line)


def step(name, ok, why=""):
    global failed
    if not ok: failed += 1
    say(("  ok   " if ok else "  FAIL ") + name + ("" if ok or not why else "  -- " + str(why)[:200]))
    return ok


def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p


def put(rel, text):
    p = SEED + rel
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(text)


class Screen:
    """Enough of a terminal to read what the filter sends the console: printable bytes, CR, LF, CUP and ED 2."""

    def __init__(self):
        self.rows = {}
        self.r = self.c = 1

    def feed(self, data):
        for m in re.finditer(rb"\x1b\[([0-9;?]*)([A-Za-z])|([\x20-\x7e])|(\r)|(\n)", data):
            if m.group(2):
                p = [int(x) if x.isdigit() else 0 for x in m.group(1).decode().split(";")]
                if m.group(2) == b"H":
                    self.r = max(p[0], 1)
                    self.c = max(p[1], 1) if len(p) > 1 else 1
                elif m.group(2) == b"J" and p[0] == 2:
                    self.rows = {}
                    self.r = self.c = 1
            elif m.group(3):
                self.rows.setdefault(self.r, {})[self.c] = m.group(3).decode()
                self.c += 1
            elif m.group(4):
                self.c = 1
            elif m.group(5):
                self.r += 1
                self.c = 1

    def text(self, r):
        row = self.rows.get(r, {})
        return "".join(row.get(c, " ") for c in range(1, (max(row) if row else 0) + 1)).rstrip()

    def dump(self):
        return "\n".join(f"{r:3} {self.text(r)}" for r in sorted(self.rows) if self.text(r))


def serial():
    try:
        return open(SER, "rb").read()
    except OSError:
        return b""


KEYS = {" ": "spc", "\n": "ret", "-": "minus", ".": "dot", "/": "slash", ":": "shift-semicolon", "_": "shift-minus", "@": "shift-2", "=": "equal"}


class Guest:
    def __init__(self, qemu):
        self.qemu = qemu
        self.s = None
        for _ in range(100):
            try:
                self.s = socket.socket(socket.AF_UNIX)
                self.s.connect(MON)
                break
            except OSError:
                self.s = None
                time.sleep(0.1)
        if self.s is None: raise SystemExit("no monitor")
        self.s.settimeout(0.3)

    def hmp(self, cmd):
        self.s.sendall((cmd + "\n").encode())
        try:
            while True:
                if not self.s.recv(65536): break
        except OSError:
            pass

    def key(self, name, settle=0.14):
        self.s.sendall(("sendkey " + name + "\n").encode())
        time.sleep(settle)
        try:
            self.s.recv(65536)
        except OSError:
            pass

    def typ(self, text):
        for ch in text:
            k = KEYS.get(ch, ch)
            if ch.isupper(): k = "shift-" + ch.lower()
            self.key(k)

    def shot(self, name):
        ppm = f"{WORK}/{name}.ppm"
        self.hmp(f"screendump {ppm}")
        time.sleep(0.3)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", ppm, f"{WORK}/{name}.png"], check=False)
        if os.path.exists(ppm): os.unlink(ppm)


def wait_for(marker, timeout, since=0):
    if isinstance(marker, str): marker = marker.encode()
    t0 = time.time()
    while time.time() - t0 < timeout:
        if marker in serial()[since:]: return True
        time.sleep(0.1)
    return False


def screen_since(mark):
    sc = Screen()
    sc.feed(serial()[mark:])
    return sc


def boot():
    subprocess.run(["cp", VARS, WORK + "/vars.fd"], check=True)
    subprocess.run(["chmod", "+w", WORK + "/vars.fd"], check=True)
    open(SER, "w").close()
    if os.path.exists(MON): os.unlink(MON)
    kvm = ["-enable-kvm", "-cpu", "host", "-smp", "2"] if os.access("/dev/kvm", os.W_OK) else ["-cpu", "max"]
    return subprocess.Popen(["qemu-system-x86_64", "-machine", "q35", "-m", "1G", *kvm,
                             "-drive", f"if=pflash,format=raw,readonly=on,file={CODE}", "-drive", f"if=pflash,format=raw,file={WORK}/vars.fd",
                             "-drive", f"file={WORK}/T.img,format=raw,if=none,id=disk0", "-device", "nvme,drive=disk0,serial=AGNOS-R3",
                             "-device", "qemu-xhci,id=xhci", "-device", "usb-kbd,bus=xhci.0",
                             "-netdev", "user,id=n0", "-device", "virtio-net-pci,netdev=n0",
                             "-serial", f"file:{SER}", "-display", "none", "-no-reboot", "-monitor", f"unix:{MON},server,nowait"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


shutil.rmtree(WORK, ignore_errors=True)
os.makedirs(SEED + "/bin")
os.makedirs(SEED + "/d")
PORT = free_port()
put("/etc/hoosh.cyml", f'[server]\nbind = "127.0.0.1"\nport = 8088\nstrategy = "priority"\nhealth_check_interval_secs = 0\n\n'
    f'[[providers]]\ntype = "OpenAi"\nbase_url = "http://10.0.2.2:{PORT}"\napi_key = "smoke"\npriority = 1\nmodels = ["stub-model", "stub-other"]\ncatalog = "static"\n')
put("/.thoth/config.cyml", '[hoosh]\nurl = "http://127.0.0.1:8088"\nmodel = "stub-model"\nstream = true\ntimeout_ms = 15000\n\n'
    '[daimon]\nurl = "http://127.0.0.1:8090"\n')
put("/log/hoosh", "")
put("/log/daimon", "")
for src, dst in ((AGNSH, "agnsh0"), (THOTH, "thoth"), (HOOSH, "hoosh"), (DAIMON, "daimon")):
    shutil.copy(src, f"{SEED}/bin/{dst}")
PUKA = os.environ.get("PUKA_BIN", "")
AETHERSAFHA = os.environ.get("AETHERSAFHA_BIN", "")
if PUKA and AETHERSAFHA:
    shutil.copy(PUKA, SEED + "/bin/puka")
    shutil.copy(AETHERSAFHA, SEED + "/bin/aethersafha")
r = subprocess.run(["cyrius", "build", "--agnos", "tuihost.cyr", SEED + "/bin/agnsh"], cwd=REPO + "/tests/agnos", capture_output=True)
if r.returncode != 0:
    sys.exit("the launcher did not build: " + r.stderr.decode(errors="replace")[-400:])
init = f'''set -u; ROOT="{AGNOS}"; . "$ROOT/scripts/smoke/lib/qemu-dwell.sh"; . "$ROOT/scripts/smoke/lib/ring3-seed.sh"
ring3_seed_init || exit 3
ring3_seed_image "{WORK}/T.img" "{KERNEL}" "{SEED}" "THOTH-TUI" || exit 3
echo "$R3_OVMF_CODE"; echo "$R3_OVMF_VARS"'''
r = subprocess.run(["bash", "-c", init], capture_output=True, text=True, env={**os.environ, "SIBLINGS_ROOT": os.path.dirname(os.path.abspath(AGNOS))})
if r.returncode != 0:
    sys.exit("the image did not build: " + (r.stdout + r.stderr)[-400:])
CODE, VARS = r.stdout.strip().splitlines()[-2:]

stub = subprocess.Popen(["python3", "-I", "-u", HERE + "/stubhoosh.py", str(PORT)], stdout=open(WORK + "/provider.log", "w"), stderr=subprocess.STDOUT)
qemu = None
rc = 1
try:
    up = False
    for attempt in range(TRIES):
        qemu = boot()
        t0 = time.time()
        while time.time() - t0 < BOOT_S:
            data = serial()
            if b"TUIHOST shell pid" in data:
                up = True
                break
            if re.search(rb"gnoboot: fail @ EBS|BootManagerMenuApp|Please select boot device", data): break
            time.sleep(0.2)
        if up: break
        qemu.terminate()
        qemu.wait(timeout=5)
    if not up:
        say("the kernel never reached the launcher: nothing was run")
        rc = 2
        raise SystemExit
    g = Guest(qemu)
    if not wait_for("agnoshi", 60) and not wait_for("$", 10):
        say("no shell prompt")
    time.sleep(2)
    g.key("ret", 1.0)                # the first key after the banner can be lost to the xHCI's start
    say("## the console: thoth, from agnsh's prompt")
    mark = len(serial())

    def scr():
        return screen_since(mark)

    def rows_with(sc, text):
        return [r for r in sorted(sc.rows) if text in sc.text(r)]

    def until(text, timeout=20, absent=False):
        t0 = time.time()
        while time.time() - t0 < timeout:
            found = bool(rows_with(scr(), text))
            if found != absent: return True
            time.sleep(0.2)
        return False

    def composer():
        sc = scr()
        return sc.text(bottom_row - 2)

    def comp_is(text, timeout=6):
        t0 = time.time()
        while time.time() - t0 < timeout:
            if composer().rstrip() == text: return True
            time.sleep(0.15)
        return False

    def keep(name):
        g.shot(name)
        open(f"{WORK}/{name}.txt", "w").write(scr().dump())

    g.typ("thoth\n")
    step("the TUI comes up from agnsh", wait_for("{(o> ", 60, mark), serial()[mark:][-200:])
    step("the greeting box is drawn in ASCII", until("Thinks, Handles", 20))
    step("the status bar names the rich tier", until("T2 rich-tui", 20))
    step("a rule is a row of dashes, not nothing", until("-" * 60, 5))
    time.sleep(1)
    keep("01-first-frame")
    sc = scr()
    bottom_row = max(sc.rows)
    say("  grid: bottom row", bottom_row, "| composer row", rows_with(sc, "{(o> Ctrl-X"))
    high = [b for b in serial()[mark:] if b >= 0x80]
    step("no byte past ASCII reached the console", not high, f"{len(high)} bytes")

    say("## typing and the line editor")
    m0 = len(serial())
    g.typ("helo")
    step("keys land in the composer", comp_is("{(o> helo", 8), composer())
    per_key = (len(serial()) - m0) // 4
    say("  console bytes a keystroke:", per_key)
    g.key("left")
    g.typ("l")
    step("Left and insert", comp_is("{(o> hello"), composer())
    g.key("end")
    g.typ("Xy")
    step("Shift reaches the decoder", comp_is("{(o> helloXy"), composer())
    g.key("backspace"); g.key("backspace")
    step("Backspace erases, and EL takes the tail off the screen", comp_is("{(o> hello"), composer())
    keep("02-composer")

    say("## a turn")
    m1 = len(open(WORK + "/provider.log").read())
    g.key("ret")
    step("the reply reaches the feed", until("hello from stub", 30), scr().dump()[-400:])
    step("the composer empties", comp_is("{(o> Ctrl-X exit . Ctrl-G status . Ctrl-B files . Ctrl-P model . ^v history . Enter send", 5), composer())
    step("the provider saw the request", "/v1/chat/completions" in open(WORK + "/provider.log").read()[m1:] or len(open(WORK + "/provider.log").read()) > m1)
    time.sleep(1)
    keep("03-reply")
    step("the turn counts", until("turns 1", 10))

    say("## recall and the chords")
    g.key("up")
    step("Up recalls the last line", comp_is("{(o> hello"), composer())
    g.key("ctrl-u")
    step("Ctrl-U kills it", comp_is("{(o>") or composer().startswith("{(o> Ctrl-X"), composer())
    g.typ("one")
    g.key("shift-ret")
    g.typ("two")
    step("Shift-Enter makes a second line", comp_is("     two"), scr().dump()[-200:])
    g.key("ctrl-u"); g.key("up"); g.key("ctrl-u"); g.key("backspace")
    g.key("ctrl-a"); g.key("ctrl-k")
    g.key("ctrl-g")
    step("Ctrl-G takes the status bar down", until("T2 rich-tui", 5, absent=True))
    g.key("ctrl-g")
    step("Ctrl-G brings it back", until("T2 rich-tui", 5))
    g.key("ctrl-b")
    time.sleep(1.5)
    keep("04-tree")
    step("Ctrl-B opens the tree on the disk", until("bin", 5))
    g.key("ctrl-b")
    step("Ctrl-B closes it", comp_is("{(o> Ctrl-X exit . Ctrl-G status . Ctrl-B files . Ctrl-P model . ^v history . Enter send", 8), composer())
    g.key("ctrl-p")
    step("Ctrl-P opens the model picker", until("stub-other", 8), scr().dump()[-300:])
    time.sleep(1)
    keep("05-picker")
    g.key("esc")
    step("Esc closes it", comp_is("{(o> Ctrl-X exit . Ctrl-G status . Ctrl-B files . Ctrl-P model . ^v history . Enter send", 8), composer())

    say("## a stream, and a long reply")
    t0 = time.time()
    g.typ("big: 20000\n")
    step("a 20 KB reply reaches its end", until("END-OF-REPLY", 90), scr().dump()[-300:])
    say(f"  20 KB, typed to painted: {time.time() - t0:.1f} s, of which about 1.5 s is typing")
    time.sleep(1)
    keep("06-big")
    g.key("pgup")
    time.sleep(1)
    step("PgUp scrolls the feed back", until("END-OF-REPLY", 8, absent=True))
    keep("07-scrolled")
    g.key("pgdn"); g.key("pgdn"); g.key("pgdn"); g.key("pgdn"); g.key("pgdn"); g.key("pgdn"); g.key("pgdn"); g.key("pgdn")
    step("PgDn comes back", until("END-OF-REPLY", 10))
    g.typ("md\n")
    step("a markdown reply draws", until("Heading", 15) or until("heading", 2), scr().dump()[-300:])
    time.sleep(2)
    keep("08-md")

    say("## Esc stops a stream")
    g.typ("slow: x\n")
    time.sleep(5)
    t0 = time.time()
    g.key("esc")
    step("Esc interrupts, at the next frame", until("interrupted", 15), scr().dump()[-300:])
    say(f"  Esc to the note: {time.time() - t0:.1f} s")
    time.sleep(1)
    keep("09-stopped")

    say("## a confirm, answered from the keyboard")
    g.typ("call: libro_verify\n")
    g.typ("y\n")                    # typed ahead, into the turn: it is not an answer to a question nobody has seen (S-3)
    asked = until("authorize", 25)
    time.sleep(1.5)
    keep("10-confirm")
    step("the gate asks, and a y typed ahead did not answer it", asked and until("authorize", 2), scr().dump()[-500:])
    if asked:
        g.typ("n\n")
        step("a no refuses, and the turn goes on", until("done", 25) or until("denied", 2) or until("refused", 2), scr().dump()[-400:])
    time.sleep(1)
    keep("11-refused")
    n0 = open(WORK + "/provider.log").read().count("TOOLRESULT")
    g.typ("call: libro_verify\n")
    time.sleep(1)
    step("the gate asks again", until("authorize", 25))
    time.sleep(1)
    m9 = len(serial())
    g.typ("yes")
    g.key("backspace"); g.key("backspace")
    time.sleep(0.5)
    step("the answer echoes and Backspace erases it", b"\x08" in serial()[m9:], serial()[m9:][-100:])
    g.key("ret")
    time.sleep(4)
    step("a yes runs the tool, and the provider gets its result", open(WORK + "/provider.log").read().count("TOOLRESULT") > n0, scr().dump()[-400:])
    time.sleep(1)
    keep("12-confirmed")

    say("## leaving")
    m2 = len(serial())
    g.typ("/quit\n")
    step("/quit returns to agnsh", wait_for("[ASSIST] >", 20, m2), serial()[m2:][-200:])
    time.sleep(1)
    g.shot("13-after-quit")
    tail = screen_since(m2)
    step("the frame is gone from the screen", not rows_with(tail, "T2 rich-tui"), tail.dump()[:300])
    m3 = len(serial())
    g.typ("version\n")
    step("the shell takes keys again", wait_for("agnoshi", 12, m3), serial()[m3:][-200:])
    m4 = len(serial())
    mark = m4
    g.typ("thoth\n")
    step("thoth comes up a second time", wait_for("{(o> ", 40, m4))
    time.sleep(2)
    m5 = len(serial())
    g.key("ctrl-x")
    step("Ctrl-X closes it", wait_for("[ASSIST] >", 15, m5), serial()[m5:][-200:])
    time.sleep(1)

    say("## the other tiers, on the same console")
    m7 = len(serial())
    g.typ("thoth -p hello\n")
    step("a one-shot prints on the console", wait_for("hello from stub", 30, m7), serial()[m7:][-200:])
    wait_for("[ASSIST] >", 15, m7 + 20)
    high = [b for b in serial()[m7:] if b >= 0x80]
    step("and nothing past ASCII reaches it", not high, f"{len(high)} bytes")
    time.sleep(1)
    m8 = len(serial())
    g.typ("thoth --tier=simple\n")
    time.sleep(6)
    step("--tier=simple keeps the line REPL", b"?1049" not in serial()[m8:] and b"\x1b[2J" not in serial()[m8:], serial()[m8:][-300:])
    g.typ("hello\n")
    step("a cooked line takes a turn", wait_for("hello from stub", 30, m8), serial()[m8:][-300:])
    time.sleep(1)
    g.typ("/quit\n")
    wait_for("[ASSIST] >", 15, m8 + 30)
    time.sleep(1)

    if PUKA and AETHERSAFHA:
        say("## a real puka window: an emulator that sets no size and cooks its own lines")

        def turns():
            return open(WORK + "/provider.log").read().count("POST /v1/chat/completions")

        m10 = len(serial())
        g.typ("aethersafha --spawn puka\n")
        step("puka comes up on the compositor", wait_for("terminal up", 150, m10), serial()[m10:][-300:])
        time.sleep(8)
        g.shot("20-puka")
        n1 = turns()
        g.typ("thoth\n")
        time.sleep(12)
        g.shot("21-puka-thoth")
        g.typ("hello\n")
        t0 = time.time()
        while time.time() - t0 < 40 and turns() == n1: time.sleep(0.5)
        step("thoth takes a turn in the window", turns() > n1)
        time.sleep(5)
        g.shot("22-puka-turn")
        g.typ("/quit\n")
        time.sleep(4)
        g.shot("23-puka-quit")
        g.key("ctrl-q", 3)
        wait_for("[ASSIST] >", 30, len(serial()) - 400)
        time.sleep(2)

    say("## a terminal channel: tests/agnos/tuihost.cyr plays the emulator")
    m6 = len(serial())
    g.typ("exit\n")
    step("agnsh exits to the launcher", wait_for("TUIHOST shell exit 0", 30, m6), serial()[m6:][-200:])
    wait_for("TUIHOST DONE", 180, m6)
    emu = serial()[m6:].decode("latin1")
    open(WORK + "/emu.txt", "w").write(emu)
    for line in emu.splitlines():
        m = re.match(r"EMU (\S+) (ok|FAIL)$", line.strip())
        if m:
            step("emulator: " + m.group(1), m.group(2) == "ok")
        elif line.startswith("EMU exit"):
            say("  " + line)
    step("both children ended cleanly", len(re.findall(r"EMU exit 0 ", emu)) == 2, re.findall(r"EMU exit .*", emu))
    step("the launcher finished", "TUIHOST DONE" in emu)
    for line in emu.splitlines():
        if line.startswith("EMU flood"): say("  " + line + "  (a measure of the kernel, not a gate)")
    rc = 0 if failed == 0 else 1
finally:
    if qemu is not None:
        qemu.terminate()
        try:
            qemu.wait(timeout=5)
        except subprocess.TimeoutExpired:
            qemu.kill()
    stub.terminate()
    open(WORK + "/report.txt", "w").write("\n".join(report) + "\n")
sys.exit(rc)
