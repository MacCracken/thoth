#!/usr/bin/env bash
# gui-live.sh — verify thoth's WINDOW live from an SSH session: a private headless Hyprland, a raw-wire screenshot +
# input kit (scripts/live/wlkit.py) and a scripted stub gateway (scripts/live/stubhoosh.py). Nobody at the machine.
#
# Why (0.52.1): every GUI check was "owed to the operator's eyes — no compositor in the harness". There was one.
# Hyprland starts headless from a session that owns no seat when libseat opens the DRM device directly
# (LIBSEAT_BACKEND=noop): it takes a GBM allocator from the card, the kernel refuses it DRM master (whatever owns the
# console keeps it — the physical screen is never touched) and `hyprctl output create headless` gives it an output.
# The first pass against the window found eight defects, one of them a freeze on resize (the 0.52.1 CHANGELOG).
#
# Usage:
#   scripts/gui-live.sh up                   start Hyprland headless + the kit + the stub gateway
#   scripts/gui-live.sh launch NAME [BIN]    `BIN gui` (default build/thoth; an aarch64 BIN runs under qemu-aarch64) with HOME=$LIVE/NAME/home, in a throwaway
#                                            git project OUTSIDE any checkout (THOTH_LIVE_PROJ, default under $TMPDIR — a
#                                            repo's own .thoth/config.cyml would override the stub); NAME's global
#                                            ~/.thoth/config.cyml is written on first use — edit it
#                                            for hooks / [session] / [history] (authority keys are global-only)
#   scripts/gui-live.sh do COMMAND...        one kit command: type TEXT · key ctrl+k · move X Y · click X Y [right] ·
#                                            scroll DY (touchpad px) · wheel N · size
#   scripts/gui-live.sh shot NAME [X Y W H]  screenshot -> $LIVE/shots/NAME.png (prints the path)
#   scripts/gui-live.sh png ARGS...          scripts/live/pngtool.py: crop IN OUT X Y W H [SCALE] · vshift A B X0 X1 Y0 Y1
#   scripts/gui-live.sh hypr ARGS...         hyprctl on this instance: clients -j · dispatch closewindow class:thoth ·
#                                            dispatch setfloating class:thoth · dispatch resizewindowpixel exact W H,class:thoth
#   scripts/gui-live.sh proxy                start the logging relay (scripts/live/wlproxy.py); THOTH_LIVE_PROXY=1 on a
#                                            `launch` routes that window through it -> $LIVE/proxy.log
#   scripts/gui-live.sh close NAME           the compositor's close for NAME's window; waits for the process to exit
#   scripts/gui-live.sh env                  the exports for this instance (eval "$(scripts/gui-live.sh env)")
#   scripts/gui-live.sh status | down        what is running · stop everything this script started and clean up
#
# Env: THOTH_LIVE_DIR (default <repo>/build/live) · THOTH_LIVE_PROJ · THOTH_LIVE_SIZE (1280x900) · THOTH_LIVE_DRM ·
# THOTH_LIVE_STUB_PORT (18190) · THOTH_LIVE_NO_STUB=1 · THOTH_LIVE_PROXY=1 (launch only).
# Needs: Hyprland + hyprctl, python3, xkbcli; the user in the DRM device's group. Under a sandboxing agent harness run
# it unsandboxed (a compositor needs /dev/dri, the runtime dir and a local TCP port).
# The TUI's live driver is scripts/live/ptydrive.py (a pty + a step script); it needs none of this.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$ROOT/scripts/live"
LIVE="${THOTH_LIVE_DIR:-$ROOT/build/live}"
SIZE="${THOTH_LIVE_SIZE:-1280x900}"
PORT="${THOTH_LIVE_STUB_PORT:-18190}"
# The throwaway project the window runs IN. Never under this repo: thoth's config discovery walks UP from the working
# directory, so a project under a checkout inherits that checkout's .thoth/config.cyml — its [hoosh].url, model and
# token — and a live check's prompts would go to a real gateway instead of the stub (caught on the kit's first run).
PROJ="${THOTH_LIVE_PROJ:-${TMPDIR:-/tmp}/thoth-live-$(id -u)/proj}"
OUTPUT="THOTH-LIVE"
PROXY_SOCK="thoth-live-proxy"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

die() { echo "gui-live: $*" >&2; exit 1; }
say() { echo "gui-live: $*"; }

# alive_as PIDFILE PATTERN: 0 when the recorded pid is running AND its command line matches PATTERN (a recycled pid
# belonging to something else is never signalled).
alive_as() {
    [ -f "$1" ] || return 1
    local pid; pid="$(cat "$1")"
    [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] || return 1
    tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- "$2"
}
stop_pidfile() {    # stop_pidfile PIDFILE PATTERN
    if alive_as "$1" "$2"; then
        local pid; pid="$(cat "$1")"
        kill "$pid" 2>/dev/null
        for _ in 1 2 3 4 5 6 7 8 9 10; do [ -d "/proc/$pid" ] || break; sleep 0.2; done
        [ -d "/proc/$pid" ] && kill -9 "$pid" 2>/dev/null
    fi
    rm -f "$1"
}
wait_for() {        # wait_for SECONDS COMMAND... — poll a condition
    local secs="$1"; shift
    local end=$(( $(date +%s) + secs ))
    while [ "$(date +%s)" -le "$end" ]; do "$@" >/dev/null 2>&1 && return 0; sleep 0.2; done
    return 1
}
sig()  { cat "$LIVE/hypr.sig" 2>/dev/null; }
sock() { cat "$LIVE/wayland" 2>/dev/null; }
hypr() { HYPRLAND_INSTANCE_SIGNATURE="$(sig)" hyprctl "$@"; }
HYPR_PAT="Hyprland -c $LIVE/hypr.conf"
need_up() { alive_as "$LIVE/hypr.pid" "$HYPR_PAT" || die "not up — run: scripts/gui-live.sh up"; }

# our instance's signature + socket, looked up by pid in `hyprctl instances -j`
find_instance() {
    hyprctl instances -j 2>/dev/null | python3 -c '
import json, sys
pid = int(sys.argv[1])
try:
    instances = json.load(sys.stdin)
except ValueError:          # not listed yet (a starting instance can print a partial list)
    sys.exit(1)
for i in instances:
    if int(i.get("pid", 0)) == pid:
        print(i["instance"], i["wl_socket"]); sys.exit(0)
sys.exit(1)' "$(cat "$LIVE/hypr.pid")"
}

cmd_up() {
    if alive_as "$LIVE/hypr.pid" "$HYPR_PAT"; then say "already up ($(sock))"; return 0; fi
    for b in Hyprland hyprctl python3 xkbcli; do command -v "$b" >/dev/null || die "needs $b"; done
    mkdir -p "$LIVE/shots"
    local drm="${THOTH_LIVE_DRM:-}"
    if [ -z "$drm" ]; then
        for c in /dev/dri/card*; do [ -r "$c" ] && [ -w "$c" ] && { drm="$c"; break; }; done
    fi
    [ -n "$drm" ] || die "no DRM card this user can open (/dev/dri/card* — the video group?)"
    local card; card="$(basename "$drm")"
    {
        echo "# generated by scripts/gui-live.sh — a private headless instance; physical connectors disabled"
        for st in /sys/class/drm/"$card"-*/status; do
            [ -f "$st" ] || continue
            [ "$(cat "$st")" = "connected" ] || continue
            local d; d="$(basename "$(dirname "$st")")"
            echo "monitor = ${d#"$card"-}, disable"
        done
        echo "monitor = , ${SIZE}@60, 0x0, 1"
        echo "general {"; echo "    border_size = 0"; echo "    gaps_in = 0"; echo "    gaps_out = 0"; echo "}"
        echo "decoration {"; echo "    rounding = 0"; echo "}"
        echo "animations {"; echo "    enabled = false"; echo "}"
        echo "misc {"; echo "    disable_hyprland_logo = true"; echo "    disable_splash_rendering = true"
        echo "    force_default_wallpaper = 0"; echo "}"
        echo "ecosystem {"; echo "    no_update_news = true"; echo "    no_donation_nag = true"; echo "}"
        echo "debug {"; echo "    disable_logs = false"; echo "}"
    } > "$LIVE/hypr.conf"
    # No `( cd X && prog & echo $! )`: the `&` then backgrounds a bash that WAITS on prog, `$!` is that bash, and it holds
    # the caller's stdout open. Started directly, `$!` is the program (nohup and env exec it).
    nohup env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE LIBSEAT_BACKEND=noop AQ_DRM_DEVICES="$drm" \
        Hyprland -c "$LIVE/hypr.conf" > "$LIVE/hypr.log" 2>&1 < /dev/null &
    echo $! > "$LIVE/hypr.pid"
    local found=""
    local end=$(( $(date +%s) + 20 ))
    while [ "$(date +%s)" -le "$end" ]; do
        alive_as "$LIVE/hypr.pid" "$HYPR_PAT" || { tail -5 "$LIVE/hypr.log" >&2; die "Hyprland exited (log: $LIVE/hypr.log)"; }
        found="$(find_instance)" && break
        sleep 0.3
    done
    [ -n "$found" ] || die "Hyprland started but never listed its instance (log: $LIVE/hypr.log)"
    echo "${found% *}" > "$LIVE/hypr.sig"
    echo "${found#* }" > "$LIVE/wayland"
    hypr output create headless "$OUTPUT" >/dev/null || die "hyprctl output create headless failed"
    wait_for 10 sh -c "WAYLAND_DISPLAY='$(sock)' python3 '$KIT/wlkit.py' outputs | grep -q '^$OUTPUT '" \
        || die "the headless output $OUTPUT never appeared"
    WAYLAND_DISPLAY="$(sock)" THOTH_LIVE_OUTPUT="$OUTPUT" nohup python3 "$KIT/wlkit.py" serve "$LIVE/kit.sock" \
        > "$LIVE/kit.log" 2>&1 < /dev/null &
    echo $! > "$LIVE/kit.pid"
    wait_for 10 grep -q serving "$LIVE/kit.log" || { cat "$LIVE/kit.log" >&2; die "the input kit did not start"; }
    if [ -z "${THOTH_LIVE_NO_STUB:-}" ]; then
        nohup python3 "$KIT/stubhoosh.py" "$PORT" > "$LIVE/stub.log" 2>&1 < /dev/null &
        echo $! > "$LIVE/stub.pid"
        wait_for 10 python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:$PORT/v1/models', timeout=1)" \
            || { cat "$LIVE/stub.log" >&2; die "the stub gateway did not answer on :$PORT"; }
    fi
    say "up — Hyprland $(sock) (instance $(sig)), output $OUTPUT $SIZE, kit $LIVE/kit.sock, stub :$PORT"
    say "next: scripts/gui-live.sh launch NAME   (then do / shot / hypr / close; down when done)"
}

fixture_project() {
    local d="$PROJ"
    while [ "$d" != "/" ] && [ -n "$d" ]; do       # refuse a project that would inherit someone's thoth config
        if [ -f "$d/.thoth/config.cyml" ] || [ -f "$d/thoth.cyml" ]; then
            die "the project $PROJ sits under $d, which holds a thoth config — it would override the stub (set THOTH_LIVE_PROJ elsewhere)"
        fi
        d="$(dirname "$d")"
    done
    [ -d "$PROJ/.git" ] && return 0
    mkdir -p "$PROJ/src"
    printf '# demo project\n\nhello\n' > "$PROJ/README.md"
    printf 'fn main() { return 0; }\n' > "$PROJ/src/main.cyr"
    git -C "$PROJ" init -q . && git -C "$PROJ" add -A && git -C "$PROJ" -c user.name=live -c user.email=live@localhost commit -q -m fixture
}

cmd_launch() {
    need_up
    local name="${1:-}"; local bin="${2:-$ROOT/build/thoth}"
    [ -n "$name" ] || die "launch NAME [BIN]"
    [ -x "$bin" ] || die "no executable $bin (cyrius build src/main.cyr build/thoth)"
    local dir="$LIVE/$name"
    alive_as "$dir/gui.pid" "$dir/thoth gui" && die "$name's window is still running (close $name first)"
    fixture_project
    mkdir -p "$dir/home/.thoth"
    if [ ! -f "$dir/home/.thoth/config.cyml" ]; then
        printf '[hoosh]\nurl = "http://127.0.0.1:%s"\nmodel = "stub-model"\nstream = true\n' "$PORT" > "$dir/home/.thoth/config.cyml"
    fi
    cp "$bin" "$dir/thoth" || die "copy $bin"      # a copy: a rebuild of build/thoth never meets `Text file busy`
    # A binary for another architecture runs under qemu-user: the Wayland wire is architecture-independent, so an
    # aarch64 build talks to this compositor exactly as it would to one on an aarch64 machine (ELF e_machine 183).
    local runner=""
    local machine; machine="$(od -An -tu2 -j18 -N2 "$dir/thoth" | tr -d ' ')"
    local host; host="$(uname -m)"
    if [ "$machine" = "183" ] && [ "$host" != "aarch64" ]; then
        command -v qemu-aarch64 >/dev/null || die "$bin is an aarch64 binary and qemu-aarch64 is not installed"
        runner="qemu-aarch64"
    elif [ "$machine" = "62" ] && [ "$host" != "x86_64" ]; then
        command -v qemu-x86_64 >/dev/null || die "$bin is an x86_64 binary and qemu-x86_64 is not installed"
        runner="qemu-x86_64"
    fi
    local display; display="$(sock)"
    if [ -n "${THOTH_LIVE_PROXY:-}" ]; then
        alive_as "$LIVE/proxy.pid" "wlproxy.py" || die "THOTH_LIVE_PROXY=1 but the relay is not running (scripts/gui-live.sh proxy)"
        display="$PROXY_SOCK"
    fi
    env -i -C "$PROJ" HOME="$dir/home" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$display" \
        PATH=/usr/bin:/bin LANG=C.UTF-8 ${runner:+"$(command -v "$runner")"} "$dir/thoth" gui > "$dir/gui.out" 2> "$dir/gui.err" < /dev/null &
    echo $! > "$dir/gui.pid"
    local pid; pid="$(cat "$dir/gui.pid")"
    # the pid the COMPOSITOR sees: thoth's, or the relay's when the window goes through it (Hyprland reads the socket peer)
    local wlpid="$pid"
    [ -n "${THOTH_LIVE_PROXY:-}" ] && wlpid="$(cat "$LIVE/proxy.pid")"
    echo "$wlpid" > "$dir/wlpid"
    if wait_for 15 sh -c "HYPRLAND_INSTANCE_SIGNATURE='$(sig)' hyprctl clients -j | grep -q '\"pid\": $wlpid,'"; then
        say "$name mapped (pid $pid; HOME $dir/home; logs $dir/gui.err)"
    else
        cat "$dir/gui.err" >&2
        die "$name never mapped a window"
    fi
}

cmd_close() {
    need_up
    local dir="$LIVE/${1:?close NAME}"
    alive_as "$dir/gui.pid" "$dir/thoth gui" || { say "${1} is not running"; return 0; }
    local pid; pid="$(cat "$dir/gui.pid")"
    hypr dispatch closewindow "pid:$(cat "$dir/wlpid" 2>/dev/null || echo "$pid")" >/dev/null
    if wait_for 10 sh -c "! test -d /proc/$pid"; then say "${1} closed"; else die "${1} (pid $pid) did not exit after the close"; fi
}

cmd_status() {
    if alive_as "$LIVE/hypr.pid" "$HYPR_PAT"; then
        say "Hyprland up: $(sock), instance $(sig)"
        hypr -j clients 2>/dev/null | python3 -c 'import json,sys; [print("  window", c["class"], c["at"], c["size"], "pid", c["pid"]) for c in json.load(sys.stdin)]'
    else
        say "Hyprland: down"
    fi
    alive_as "$LIVE/kit.pid" "wlkit.py serve" && say "kit: $LIVE/kit.sock" || say "kit: down"
    alive_as "$LIVE/stub.pid" "stubhoosh.py" && say "stub: http://127.0.0.1:$PORT" || say "stub: down"
    alive_as "$LIVE/proxy.pid" "wlproxy.py" && say "proxy: $PROXY_SOCK -> $LIVE/proxy.log" || true
}

cmd_down() {
    for p in "$LIVE"/*/gui.pid; do [ -f "$p" ] && stop_pidfile "$p" "$(dirname "$p")/thoth gui"; done
    stop_pidfile "$LIVE/kit.pid" "wlkit.py serve"
    stop_pidfile "$LIVE/stub.pid" "stubhoosh.py"
    stop_pidfile "$LIVE/proxy.pid" "wlproxy.py"
    rm -f "$LIVE/kit.sock" "$XDG_RUNTIME_DIR/$PROXY_SOCK"
    if alive_as "$LIVE/hypr.pid" "$HYPR_PAT"; then
        local pid; pid="$(cat "$LIVE/hypr.pid")"
        hypr dispatch exit >/dev/null 2>&1
        wait_for 8 sh -c "! test -d /proc/$pid" || kill -9 "$pid" 2>/dev/null
        sleep 0.3
    fi
    rm -f "$LIVE/hypr.pid"
    local s; s="$(sig)"
    if [ -n "$s" ] && [ -d "$XDG_RUNTIME_DIR/hypr/$s" ]; then rm -rf "${XDG_RUNTIME_DIR:?}/hypr/$s"; fi
    rmdir "$XDG_RUNTIME_DIR/hypr" 2>/dev/null
    rm -f "$LIVE/hypr.sig" "$LIVE/wayland"
    say "down"
}

case "${1:-}" in
    up) cmd_up ;;
    launch) shift; cmd_launch "$@" ;;
    close) shift; cmd_close "$@" ;;
    do) shift; need_up; python3 "$KIT/wlkit.py" send "$LIVE/kit.sock" "$@" ;;
    shot)
        shift; need_up
        [ -n "${1:-}" ] || die "shot NAME [X Y W H]"
        mkdir -p "$LIVE/shots"
        name="$1"; shift
        WAYLAND_DISPLAY="$(sock)" THOTH_LIVE_OUTPUT="$OUTPUT" python3 "$KIT/wlkit.py" shot "$LIVE/shots/$name.png" "$@" >/dev/null \
            && echo "$LIVE/shots/$name.png" ;;
    png) shift; python3 "$KIT/pngtool.py" "$@" ;;
    hypr) shift; need_up; hypr "$@" ;;
    proxy)
        need_up
        alive_as "$LIVE/proxy.pid" "wlproxy.py" && { say "proxy already running"; exit 0; }
        WAYLAND_DISPLAY="$(sock)" nohup python3 "$KIT/wlproxy.py" "$PROXY_SOCK" "$LIVE/proxy.log" > "$LIVE/proxy.out" 2>&1 < /dev/null &
        echo $! > "$LIVE/proxy.pid"
        wait_for 10 test -S "$XDG_RUNTIME_DIR/$PROXY_SOCK" || die "the relay did not start"
        say "proxy: $PROXY_SOCK -> $LIVE/proxy.log (launch with THOTH_LIVE_PROXY=1)" ;;
    env)
        need_up
        echo "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' WAYLAND_DISPLAY='$(sock)' HYPRLAND_INSTANCE_SIGNATURE='$(sig)' THOTH_LIVE_OUTPUT='$OUTPUT'" ;;
    status) cmd_status ;;
    down) cmd_down ;;
    *) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
