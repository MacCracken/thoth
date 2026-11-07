#!/usr/bin/env python3
"""agnos-hostile — the 2026-11-05 audit's attacks, on a thoth running in ring 3 on AGNOS.

  agnos-hostile.py AGNOS_REPO KERNEL THOTH_ELF DAIMON_ELF

The attacks are the Linux audit's, moved to where they have never run. One boot works through every scenario:
  wire     the 151 hostile SSE, raw HTTP and blocking scenarios of hostile-wire.py, served from the host, with thoth talking to
           them directly over QEMU's network
  time     a gateway that goes silent at each stage, and what the deadline does about it
  jail     read_file, list_dir, search and the write tools, pointed out of the project
  capture  a model naming `shell`, and [hooks] and [verify], which all need a shell AGNOS does not have
  store    the pin and session stores and the logs, as links, garbage, directories and oversized files
  repo     real repositories read through sit: found at $PWD, a .git link out of the project, a HEAD that names nothing
tests/agnos/hostile.cyr runs the list in the guest, each scenario with its own HOME and PWD. Verdicts come from the exit status,
the host's log of the wire, and the image read back after the run, so a store is checked by what is on the disk.
Exit: 0 when nothing was flagged, 1 otherwise, 2 when the kernel never started. Results are in WORK/report.txt.
"""
import json, os, re, shutil, socket, subprocess, sys, time

AGNOS, KERNEL, THOTH, DAIMON = sys.argv[1:5]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WORK = os.environ.get("THOTH_HOSTILE_WORK", "/var/tmp/thoth-agnos-hostile")
SEED = WORK + "/seed"
TIMEOUT_MS = 2500
BOOT_S = int(os.environ.get("QEMU_TIMEOUT", "1500"))
ONLY = os.environ.get("THOTH_HOSTILE_ONLY", "")     # a class to run alone: wire, time, jail, capture, store, repo


def sh(*a, **k):
    return subprocess.run(a, **k)


def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p


def put(rel, text, mode=None):
    p = SEED + rel
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb").write(text if isinstance(text, bytes) else text.encode())
    if mode: os.chmod(p, mode)


def link(rel, target):
    p = SEED + rel
    os.makedirs(os.path.dirname(p), exist_ok=True)
    os.symlink(target, p)


PORT = free_port()
GATE = f"http://10.0.2.2:{PORT}"
VICTIM = "VICTIM: a file a link must not reach\n"


def home(name, url=GATE, stream=True, extra="", daimon=False):
    """One scenario's HOME, with a project under it."""
    h = "/h/" + name
    cfg = f'[hoosh]\nurl = "{url}"\nmodel = "m"\nstream = {"true" if stream else "false"}\ntimeout_ms = {TIMEOUT_MS}\n'
    if daimon: cfg += '\n[daimon]\nurl = "http://127.0.0.1:8090"\n'
    put(h + "/.thoth/config.cyml", cfg + extra)
    put(h + "/proj/a.txt", "PROJ-A: the project's a.txt\n")
    return h


TOOLS = []   # (name, tool, args): scripted calls, served after the wire scenarios
RUNS = []    # the lines of /etc/runs
CLASS = {}   # run id -> (class, name, expectations)


def tool(name, t, args):
    TOOLS.append([name, t, json.dumps(args)])
    return name


def stage_tools():
    """The scripted calls have to exist before the server starts, because it numbers them."""
    jail = home("j", extra='\n[edit]\nenabled = true\n\n[tron]\npolicy = "/etc/tron-policy.toml"\nagent = "thoth"\n')
    put("/etc/tron-policy.toml", '[agent."thoth"]\nallow = ["read_file", "list_dir", "search", "edit", "create_file", "memory_write", "thoth_write", "thoth_read", "thoth_edit", "thoth_shell"]\n\n[agent."thoth".rate_limit]\ncalls_per_minute = 600\n')
    put("/etc/secret.txt", "SECRET: outside any project\n")
    put("/a.txt", "ROOT-A: the disk root's a.txt\n")
    link("/link-out", "/etc/secret.txt")
    link(jail + "/proj/link-out", "/etc/secret.txt")
    link(jail + "/proj/link-dir", "/etc")
    for n, p in (("j_rel", "a.txt"), ("j_rel_etc", "etc/secret.txt"), ("j_dotdot", "../../../etc/secret.txt"), ("j_abs", "/etc/secret.txt"),
                 ("j_link", "link-out"), ("j_link_dir", "link-dir/secret.txt"), ("j_home_cfg", ".thoth/config.cyml"),
                 ("j_abs_cfg", jail + "/.thoth/config.cyml"), ("j_policy", "/etc/tron-policy.toml"), ("j_bin", "/bin/thoth")):
        tool(n, "read_file", {"path": p})
    tool("j_list", "list_dir", {"path": "."})
    tool("j_list_etc", "list_dir", {"path": "/etc"})
    tool("j_search", "search", {"pattern": "SECRET"})
    tool("w_create", "create_file", {"path": "made.txt", "content": "made by the model\n"})
    tool("w_dotdot", "create_file", {"path": "../../../etc/evil.txt", "content": "evil\n"})
    tool("w_abs", "create_file", {"path": "/etc/evil2.txt", "content": "evil\n"})
    tool("w_rel_etc", "create_file", {"path": "etc/evil3.txt", "content": "evil\n"})
    tool("w_link_dir", "create_file", {"path": "link-dir/evil4.txt", "content": "evil\n"})
    tool("w_cfg", "create_file", {"path": ".thoth/config.cyml", "content": "[tron]\n"})
    home("cap_shell", extra="\n[shell]\nenabled = true\n")
    tool("c_shell", "shell", {"command": "id"})
    home("cap_hook", extra='\n[hooks]\npre_tool = "true"\n')
    tool("c_hook", "read_file", {"path": "a.txt"})
    home("cap_verify", extra='\n[edit]\nenabled = true\n\n[verify]\ncommand = "true"\n\n[tron]\npolicy = "/etc/tron-policy.toml"\nagent = "thoth"\n')
    tool("c_verify", "create_file", {"path": "v.txt", "content": "v\n"})
    return jail


# What each scripted call must come back as. A regression fails the kit, instead of scrolling past.
EXPECT = {
    "j_rel": "PROJ-A", "j_rel_etc": "no such file", "j_dotdot": "refused", "j_abs": "refused", "j_link": "symlink",
    "j_link_dir": "symlink", "j_home_cfg": "refused", "j_abs_cfg": "refused", "j_policy": "refused", "j_bin": "refused",
    "j_list": "link-dir", "j_list_etc": "refused", "j_search": "no matches", "w_create": "created", "w_dotdot": "refused",
    "w_abs": "refused", "w_rel_etc": "could not", "w_link_dir": "symlink", "w_cfg": "refused", "c_shell": "not enabled",
    "c_hook": "PROJ-A", "c_verify": "created",
}
# The longest a silent gateway may hold a turn with a 2.5 s deadline, in seconds. keepalive is the known gap: no poll on AGNOS.
TIME_MAX = {"silent_accept": 5, "silent_mid": 5, "refused": 3, "blackhole": 11, "noaccept": 11, "keepalive": 12, "trickle_body": 12}


def git(cwd, *a):
    env = {"PATH": "/usr/bin:/bin", "HOME": WORK, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    return subprocess.run(["git", *a], cwd=cwd, env=env, capture_output=True, check=True).stdout.decode().strip()


def repo_at(path, branch):
    """A real repository in the seed, with one commit on `branch`."""
    os.makedirs(path, exist_ok=True)
    git(path, "init", "-q", "--template=", "-b", branch)
    open(path + "/a.txt", "w").write("committed\n")
    git(path, "add", "-A")
    git(path, "commit", "-q", "-m", "x")


def repo_homes():
    """What /git prints in the line REPL. Each entry: name, its HOME, what must show, what must not, the command."""
    out = []
    h = home("r_here")
    repo_at(SEED + h + "/proj", "rooted-at-pwd")
    open(SEED + h + "/proj/a.txt", "w").write("edited\n")
    out.append(("r_here", h, "rooted-at-pwd", "no git/.sit", "/git"))
    h = home("r_link")
    os.unlink(SEED + h + "/proj/a.txt")
    os.rmdir(SEED + h + "/proj")
    os.makedirs(SEED + h + "/proj")
    repo_at(SEED + h + "/v", "victim-branch")
    link(h + "/proj/.git", "../v/.git")
    out.append(("r_link", h, "no git/.sit", "victim-branch", "/git"))
    h = home("r_broken")
    repo_at(SEED + h + "/proj", "main")
    tree = git(SEED + h + "/proj", "rev-parse", "HEAD^{tree}")
    os.unlink(f"{SEED}{h}/proj/.git/objects/{tree[:2]}/{tree[2:]}")
    out.append(("r_broken", h, "no answer", "clean", "/git"))
    h = home("r_head")                                # a HEAD that is a link to another repository's
    repo_at(SEED + h + "/v", "victim-head")
    os.unlink(SEED + h + "/proj/a.txt")
    repo_at(SEED + h + "/proj", "main")
    os.unlink(SEED + h + "/proj/.git/HEAD")
    link(h + "/proj/.git/HEAD", "../../v/.git/HEAD")
    out.append(("r_head", h, "no git/.sit", "victim-head", "/git"))
    h = home("r_difflink")                            # a tracked link, retargeted at a file outside the project
    os.unlink(SEED + h + "/proj/a.txt")
    os.makedirs(SEED + h + "/proj", exist_ok=True)
    put(h + "/outside.txt", "SECRET-OUTSIDE-THE-PROJECT\n")
    os.symlink("a.txt", SEED + h + "/proj/l")
    repo_at(SEED + h + "/proj", "main")
    os.unlink(SEED + h + "/proj/l")
    os.symlink("../outside.txt", SEED + h + "/proj/l")
    out.append(("r_difflink", h, "+1 -1", "SECRET-OUTSIDE", "/git l"))
    return out


def store_homes():
    """Each store attack gets a HOME of its own. `check` is read back off the image afterwards."""
    out = []
    def st(name, cfg_extra, build, check=None, argv=None, made=None, repl=False):
        h = home(name, extra=cfg_extra, daimon=True)
        build(h)
        out.append((name, h, check, argv, made, repl))
    bad = b"not a store of anybody's\n"
    def pin_link(h):
        put(h + "/victim", VICTIM); link(h + "/.thoth/toolpins", h + "/victim")
    # The controls: an honest store, written. Without these a run that never touched a store would read as a store defended.
    st("ctl_pin", "", lambda h: None, made="/.thoth/toolpins")
    st("ctl_sess", '\n[session]\nfile = "/h/ctl_sess/.thoth/session"\n', lambda h: None, made="/.thoth/session", repl=True)
    st("ctl_log", "", lambda h: None, argv="--logs /h/ctl_log/log", made="/log")
    # A project's own config, found from $PWD. With no cwd the walk used to start at the disk root and never saw it.
    st("ctl_local", "", lambda h: put(h + "/proj/.thoth/config.cyml", '[hoosh]\nmodel = "local-model"\n'), argv="--json")
    st("ctl_log_cfg", '\n[log]\nfile = "/h/ctl_log_cfg/log"\n', lambda h: None, made="/log")
    st("pin_link", "", pin_link, {"/victim": VICTIM})
    st("pin_garbage", "", lambda h: put(h + "/.thoth/toolpins", bad), {"/.thoth/toolpins": bad.decode()})
    st("pin_nodigest", "", lambda h: put(h + "/.thoth/toolpins", "THOTH-TOOLPIN-1\n"), {"/.thoth/toolpins": "THOTH-TOOLPIN-1\n"})
    st("pin_empty", "", lambda h: put(h + "/.thoth/toolpins", ""), None)
    st("pin_big", "", lambda h: put(h + "/.thoth/toolpins", b"x" * 2097152), None)
    def pin_dir(h): os.makedirs(SEED + h + "/.thoth/toolpins")
    st("pin_dir", "", pin_dir, None)
    def sess(n): return f'\n[session]\nfile = "/h/{n}/.thoth/session"\n'
    def sess_link(h):
        put(h + "/victim", VICTIM); link(h + "/.thoth/session", h + "/victim")
    st("sess_link", sess("sess_link"), sess_link, {"/victim": VICTIM}, repl=True)
    st("sess_garbage", sess("sess_garbage"), lambda h: put(h + "/.thoth/session", bad), {"/.thoth/session": bad.decode()}, repl=True)
    st("sess_newer", sess("sess_newer"), lambda h: put(h + "/.thoth/session", "THOTH-SESSION-99\nfuture\n"), {"/.thoth/session": "THOTH-SESSION-99\nfuture\n"}, repl=True)
    def sess_dir(h): os.makedirs(SEED + h + "/.thoth/session")
    st("sess_dir", sess("sess_dir"), sess_dir, None, repl=True)
    # The operator's own relative operands, in the line REPL, which has never run here until now.
    st("repl_read", "", lambda h: None, repl="/read a.txt")
    def log_link(h):
        put(h + "/victim", VICTIM); link(h + "/log", h + "/victim")
    st("log_link", "", log_link, {"/victim": VICTIM}, "--logs /h/log_link/log")
    st("log_cfg_link", '\n[log]\nfile = "/h/log_cfg_link/log"\n', log_link, {"/victim": VICTIM})
    return out


def main():
    shutil.rmtree(WORK, ignore_errors=True)
    os.makedirs(SEED + "/bin"); os.makedirs(SEED + "/d")
    home("s", stream=True); home("b", stream=False)
    jail = stage_tools()
    stores = store_homes()
    repos = repo_homes()
    json.dump(TOOLS, open(WORK + "/tools.json", "w"))
    r = sh("cyrius", "build", "--agnos", "hostile.cyr", WORK + "/launcher", cwd=REPO + "/tests/agnos", capture_output=True)
    if r.returncode != 0:
        print(r.stdout.decode()[-400:]); return 2
    shutil.copy(WORK + "/launcher", SEED + "/bin/agnsh")
    shutil.copy(THOTH, SEED + "/bin/thoth"); shutil.copy(DAIMON, SEED + "/bin/daimon")
    wire = subprocess.Popen(["python3", "-I", "-u", HERE + "/hostile-wire.py", "--serve", str(PORT), WORK + "/tools.json"],
                            stdout=open(WORK + "/wire.log", "w"), stderr=subprocess.STDOUT)
    try:
        while "SERVING" not in open(WORK + "/wire.log").read():
            time.sleep(0.1)
        idx = {}
        for l in open(WORK + "/wire.log"):
            if l.startswith("INDEX "):
                _, i, name, mode, st = l.rstrip("\n").split(" ", 4)
                idx[name] = (int(i), mode, int(st))
        def want(c): return ONLY == "" or ONLY == c
        def run(rid, cls, name, h, n, ms=25000, extra="", repl=False):
            argv = f"/bin/thoth -p wire:{n}" + ((" " + extra) if extra else "")
            line = f"R\t{rid}\t{ms}\t{h}\t{h}/proj\t{argv}"
            if repl:                                 # the line REPL, on a scripted stdin; byte 1 is a newline
                script = (repl if isinstance(repl, str) else f"wire:{n}") + "\x01/quit\x01"
                line = f"R\t{rid}\t{ms}\t{h}\t{h}/proj\t/bin/thoth\t{script}"
            RUNS.append(line)
            CLASS[rid] = (cls, name)
        if want("store") or want("jail"):
            RUNS.append("S\t/bin/daimon serve 8090 --data-dir /d")
        if want("time"): RUNS.append("L\t18999")
        if want("wire"):
            for name, (i, mode, stream) in idx.items():
                if mode in ("x", "tool"): continue
                run(f"w{i}", "wire", name, "/h/s" if stream else "/h/b", i)
        if want("time"):
            for name in ("silent_accept", "silent_mid", "keepalive", "trickle_body"):
                run("t_" + name, "time", name, "/h/s", idx[name][0])
            run("t_refused", "time", "refused", home("t_refused", url="http://10.0.2.2:1"), 0)
            run("t_blackhole", "time", "blackhole", home("t_blackhole", url="http://10.0.2.99:9"), 0, ms=60000)
            run("t_noaccept", "time", "noaccept", home("t_noaccept", url="http://127.0.0.1:18999"), 0, ms=90000)
        if want("jail"):
            for t in TOOLS:
                if t[0][:2] in ("j_", "w_"): run(t[0], "jail", t[0], jail, idx[t[0]][0])
        if want("capture"):
            run("c_shell", "capture", "c_shell", "/h/cap_shell", idx["c_shell"][0])
            run("c_hook", "capture", "c_hook", "/h/cap_hook", idx["c_hook"][0])
            run("c_verify", "capture", "c_verify", "/h/cap_verify", idx["c_verify"][0])
        if want("store"):
            for name, h, check, argv, made, repl in stores:
                run("s_" + name, "store", name, h, idx["comments"][0], extra=argv or "", repl=repl)
        if want("repo"):
            for name, h, must, not_, script in repos:
                run(name, "repo", name, h, 0, repl=script)
        put("/etc/runs", "\n".join(RUNS) + "\n")
        boot = f'''
set -u
ROOT="{AGNOS}"
. "$ROOT/scripts/smoke/lib/qemu-dwell.sh"
. "$ROOT/scripts/smoke/lib/ring3-seed.sh"
ring3_seed_init || exit 3
ring3_seed_image "{WORK}/H.img" "{KERNEL}" "{SEED}" "THOTH-HOSTILE" || exit 3
R3_MEM=1G R3_ACCEL="$(smoke_accel 2)"; export R3_MEM R3_ACCEL
ring3_seed_boot "{WORK}/H.img" "{WORK}/serial.log" "HOSTILE DONE" {BOOT_S} "{WORK}" -netdev user,id=n0 -device virtio-net-pci,netdev=n0
'''
        env = dict(os.environ); env.setdefault("SIBLINGS_ROOT", os.path.dirname(AGNOS))
        b = subprocess.run(["bash", "-c", boot], env=env, capture_output=True, timeout=BOOT_S + 120)
        open(WORK + "/boot.log", "wb").write(b.stdout + b.stderr)
        if b.returncode == 2: print("VOID: the kernel never started"); return 2
    finally:
        wire.terminate()
    text = subprocess.run(["strings", "-n", "3", WORK + "/serial.log"], capture_output=True).stdout.decode(errors="replace")
    done = "HOSTILE DONE" in text
    runs = {}
    for m in re.finditer(r"RUN (\S+) status (-?\d+) ms (\d+) out (\d+)", text):
        runs[m.group(1)] = dict(st=int(m.group(2)), ms=int(m.group(3)), out=int(m.group(4)), tail="")
    for m in re.finditer(r"TAIL (\S+) ?(.*)", text):
        if m.group(1) in runs: runs[m.group(1)]["tail"] = m.group(2)
    for m in re.finditer(r"HEAD (\S+) ?(.*)", text):
        if m.group(1) in runs: runs[m.group(1)]["head"] = m.group(2)
    wlog = open(WORK + "/wire.log", errors="replace").read()
    results = {}
    for m in re.finditer(r"^RESULT (\d+) (\S+) (.*)$", wlog, re.M):
        results.setdefault(m.group(2), m.group(3))
    badreq = re.findall(r"^REQ (\d+) (\S+) BADREQ", wlog, re.M)
    subprocess.run(["dd", f"if={WORK}/H.img", f"of={WORK}/part.img", "bs=1M", "skip=33", "count=67", "status=none"])
    def disk(path):
        return subprocess.run(["debugfs", "-R", f"cat {path}", WORK + "/part.img"], capture_output=True).stdout.decode(errors="replace")
    rep = []
    flagged = []
    def say(s): rep.append(s); print(s, flush=True)
    say(f"booted to the end: {done} · {len(runs)} of {len(CLASS)} runs reported · faults in the log: {len(re.findall(r'#PF|PANIC|^fault:', text, re.M))}")
    for rid, (cls, name) in CLASS.items():
        r = runs.get(rid)
        if r is None:
            flagged.append((rid, "NO RESULT")); continue
        if cls in ("wire", "time", "jail", "capture", "store", "repo") and r["st"] not in (0, 1, 256):
            flagged.append((rid, f"status {r['st']}"))
    if badreq: flagged.append(("wire", f"invalid JSON sent on {len(badreq)} scenarios: {badreq[:5]}"))
    say("-- time")
    for rid, (cls, name) in CLASS.items():
        if cls == "time" and rid in runs:
            secs = runs[rid]["ms"] / 1000
            if secs > TIME_MAX[name]: flagged.append((rid, f"held {secs:.1f} s, over {TIME_MAX[name]} s"))
            say(f"  {name:14s} status {runs[rid]['st']:>4} {secs:6.1f} s  {runs[rid]['tail'][-110:]}")
    say("-- jail and capture: what the tool returned to the model")
    for rid, (cls, name) in CLASS.items():
        if cls in ("jail", "capture"):
            got = results.get(name, "(no tool result reached the wire)")
            if EXPECT[name] not in got: flagged.append((rid, f"expected {EXPECT[name]!r}: {got[:80]}"))
            say(f"  {name:12s} {got[:150]}")
    if "c_hook" in runs and "hook is NOT running" not in runs["c_hook"].get("head", "") + runs["c_hook"]["tail"]:
        flagged.append(("c_hook", "the hook's gap was not announced"))
    if any(c == "jail" for c, _ in CLASS.values()):
        for p in ("/etc/evil.txt", "/etc/evil2.txt", "/etc/evil3.txt", "/made.txt", "/evil4.txt"):
            c = disk(p)
            if c: flagged.append(("disk", f"{p} was written"))
            say(f"  on disk {p:22s} {'PRESENT: ' + c[:40].strip() if c else 'absent'}")
        if "made by the model" not in disk("/h/j/proj/made.txt"): flagged.append(("disk", "the project's file was not written"))
    say("-- store")
    for name, h, check, argv, made, repl in stores:
        rid = "s_" + name
        if rid not in runs: continue
        verdict = "held"
        for rel, want_text in (check or {}).items():
            got = disk(h + rel)
            if got != want_text:
                verdict = f"CHANGED {rel}: {got[:50]!r}"; flagged.append((rid, verdict))
        if made:
            got = disk(h + made)
            verdict = f"wrote {len(got)} B" if got else "WROTE NOTHING"
            if not got: flagged.append((rid, "a control wrote nothing, so the attacks on this store prove nothing"))
        if name == "ctl_local" and "local-model" not in runs[rid]["tail"]:
            flagged.append((rid, "a project's own config under $PWD was not read"))
        if name == "repl_read" and "PROJ-A" not in runs[rid].get("head", "") + runs[rid]["tail"]:
            flagged.append((rid, "/read a.txt did not read the project's file"))
        note = (runs[rid].get("head", "") + " | " + runs[rid]["tail"])[:150]
        say(f"  {name:13s} status {runs[rid]['st']:>4} {runs[rid]['ms']/1000:5.1f} s {verdict:14s} {note}")
    say("-- repo")
    for name, h, must, not_, script in repos:
        if name not in runs: continue
        seen = runs[name].get("head", "") + " " + runs[name]["tail"]
        verdict = "held"
        if must not in seen: verdict = f"MISSING {must!r}"; flagged.append((name, verdict))
        if not_ in seen: verdict = f"SHOWED {not_!r}"; flagged.append((name, verdict))
        say(f"  {name:10s} status {runs[name]['st']:>4} {verdict:14s} {runs[name]['tail'][-120:]}")
    wr = [runs[r] for r, (c, _) in CLASS.items() if c == "wire" and r in runs]
    if wr:
        say(f"-- wire: {len(wr)} scenarios, slowest {max(x['ms'] for x in wr)/1000:.1f} s, statuses {sorted(set(x['st'] for x in wr))}")
    say(f"flagged: {len(flagged)}")
    for f in flagged[:40]: say(f"  !! {f[0]}: {f[1]}")
    open(WORK + "/report.txt", "w").write("\n".join(rep) + "\n")
    json.dump(runs, open(WORK + "/runs.json", "w"))
    return 1 if (flagged or not done) else 0


sys.exit(main())
