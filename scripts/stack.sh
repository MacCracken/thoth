#!/usr/bin/env bash
# stack.sh — dev convenience: bring up the AGNOS backend stack
# (hoosh + daimon + bote + mneme) and wire it so thoth can be started against a
# live spine with one command.
#
# INTERIM helper. It launches the capability spine as separate processes,
# registers the bote filesystem tools with daimon, and starts mneme's MCP
# endpoint (which self-registers its memory tools with daimon) — until thoth
# grows first-class one-stack startup. Everything that must persist (runtime
# config, logs, pidfiles, the workspace the AI writes projects into, and mneme's
# vault) lives under $STACK_HOME (default ~/.agnos-stack), OUTSIDE the repos.
# mneme is OPTIONAL: if its binary is missing the stack still comes up and the
# memory seam degrades to thoth's local .thoth/memory fallback.
#
# Usage:
#   scripts/stack.sh up        start hoosh + daimon + bote + mneme, register tools
#   scripts/stack.sh run       up, then launch the thoth TUI against it
#   scripts/stack.sh status    show what's listening + how to start thoth
#   scripts/stack.sh down      stop the services
#   scripts/stack.sh logs      show the tail of each service log
#
# Override via env: AGNOS_STACK_HOME, HOOSH_DIR, DAIMON_DIR, BOTE_DIR, MNEME_DIR,
# THOTH_DIR, AGNOS_KEY_FILE, HOOSH_PORT, DAIMON_PORT, BOTE_PORT, MNEME_PORT, THOTH_MODEL.

set -u

STACK_HOME="${AGNOS_STACK_HOME:-$HOME/.agnos-stack}"
HOOSH_DIR="${HOOSH_DIR:-$HOME/Repos/hoosh}"
DAIMON_DIR="${DAIMON_DIR:-$HOME/Repos/daimon}"
BOTE_DIR="${BOTE_DIR:-$HOME/Repos/bote}"
MNEME_DIR="${MNEME_DIR:-$HOME/Repos/mneme}"
THOTH_DIR="${THOTH_DIR:-$HOME/Repos/thoth}"
KEY_FILE="${AGNOS_KEY_FILE:-$HOME/.ssh/.api_keys}"
HOOSH_PORT="${HOOSH_PORT:-8088}"
DAIMON_PORT="${DAIMON_PORT:-8090}"
BOTE_PORT="${BOTE_PORT:-9000}"
MNEME_PORT="${MNEME_PORT:-8100}"
MODEL="${THOTH_MODEL:-claude-opus-4-8}"

RUN_DIR="$STACK_HOME/run"
LOG_DIR="$STACK_HOME/logs"
WORKSPACE="$STACK_HOME/workspace"
MNEME_VAULT_DIR="$STACK_HOME/mneme-vault"   # mneme's persistent knowledge vault (outside the repos)

c_g=$'\033[32m'; c_r=$'\033[31m'; c_y=$'\033[33m'; c_d=$'\033[2m'; c_0=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf "  ${c_g}✓${c_0} %s\n" "$*"; }
warn() { printf "  ${c_y}!${c_0} %s\n" "$*"; }
err()  { printf "  ${c_r}✗${c_0} %s\n" "$*" >&2; }

# PID listening on a TCP port (via ss, else lsof), empty if none.
port_pid() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnpH "sport = :$p" 2>/dev/null | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2
  elif command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null | head -1
  fi
}
listening() { [ -n "$(port_pid "$1")" ]; }

# Poll until a port is listening.
#
# The curl call does NOT pace this loop, and used to be the only thing between iterations: a connection
# to a CLOSED LOCAL port is refused immediately rather than timing out, so `--max-time 0.25` never
# elapsed and the whole n=40 budget measured ~0.6 s, not the ~10 s it was chosen for. Every service here
# is a 15-30 MB static binary that must load, read config and bind, so anything slower than that got
# "failed to listen" while it was coming up fine — and cmd_up does not check start_svc's status, so it
# went on to register_tools before daimon was up and the fs tools were silently never registered.
wait_listen() {
  local p="$1" n="${2:-40}" i=0
  while [ "$i" -lt "$n" ]; do
    listening "$p" && return 0
    i=$((i + 1))
    sleep 0.25 2>/dev/null || sleep 1
  done
  return 1
}

load_key() {
  if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$KEY_FILE" ]; then
    set +u; . "$KEY_FILE" >/dev/null 2>&1 || true; set -u
  fi
}

# start_svc <name> <workdir> <log> <pidfile> <port> <cmd...>
start_svc() {
  local name="$1" wd="$2" log="$3" pf="$4" port="$5"; shift 5
  if listening "$port"; then ok "$name already up on :$port (pid $(port_pid "$port"))"; return 0; fi
  ( cd "$wd" && exec nohup "$@" >"$log" 2>&1 </dev/null ) &
  echo $! > "$pf"
  if wait_listen "$port"; then ok "$name up on :$port (pid $(port_pid "$port"))"
  else err "$name failed to listen on :$port — tail $log"; return 1; fi
}

# stop_svc <name> <port> <pidfile>
stop_svc() {
  local name="$1" port="$2" pf="$3" pid=""
  [ -f "$pf" ] && pid=$(cat "$pf" 2>/dev/null)
  { [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; } && pid=$(port_pid "$port")
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    local i=0
    while [ "$i" -lt 8 ] && kill -0 "$pid" 2>/dev/null; do
      i=$((i + 1)); curl -s -o /dev/null --max-time 0.3 "http://127.0.0.1:$port" 2>/dev/null || true
    done
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    ok "$name stopped (pid $pid)"
  else
    warn "$name not running"
  fi
  rm -f "$pf"
}

write_configs() {
  # The PREFERRED path (ADR-0016), not the legacy `$STACK_HOME/thoth.cyml`. Discovery consults the
  # legacy name LAST, so any `.thoth/` at or above $STACK_HOME — notably `~/.thoth/config.cyml`, which
  # the committed template recommends as a global default — silently shadowed everything written here:
  # the stack came up green while thoth read a different gateway, with no [daimon].url and no
  # [tron].policy. It only ever worked because ~/.thoth happened not to exist.
  mkdir -p "$STACK_HOME/.thoth"
  local tc="$STACK_HOME/.thoth/config.cyml" tp="$STACK_HOME/tron-policy.toml"
  if [ ! -f "$tc" ]; then
    cat > "$tc" <<EOF
# Generated by stack.sh — thoth runtime config for the local dev stack.
# Edit freely; stack.sh will not overwrite an existing file.
[hoosh]
url    = "http://127.0.0.1:$HOOSH_PORT"
model  = "$MODEL"
# stream=false is the agentic tool-call final-turn workaround (blocking mode).
# NOTE: keep config comments on their OWN line — an inline comment on a value
# line (\`stream = false  # ...\`) is currently NOT stripped by the bayan TOML
# reader, so thoth mis-parses the value (reads it as streaming). Filed vs bayan.
stream = false

[daimon]
url = "http://127.0.0.1:$DAIMON_PORT"

[memory]
# Consume mneme (the AGNOS memory/RAG domain) via daimon when it's hosted — the
# seam binds when daimon advertises mneme_* (mneme self-registers on serve). When
# mneme is absent this reads the local .thoth/memory fallback. /remember writes a
# note; /state shows the binding (mneme vs local).
enabled = true

[tron]
policy = "tron-policy.toml"
agent  = "thoth"
EOF
    ok "wrote $tc"
  fi
  if [ ! -f "$tp" ]; then
    cat > "$tp" <<'EOF'
# Generated by stack.sh — authorize the AI to call the fs tools + built-ins.
# The libro_* entries are daimon's own built-in audit/query tools (query, export,
# verify, proof, retention); daimon advertises them alongside bote's fs tools, so
# without them in the allow-list they are DENIED. NOTE: as of 2026-07 daimon's
# libro_* and bote's sample bote_echo return BARE JSON, not the MCP
# {"content":[{"type":"text","text":...}]} envelope, so thoth (strict MCP client)
# renders "no text content could be parsed" for them until daimon/bote wrap their
# results in content blocks — a conformance fix filed upstream. The fs_* tools are
# conformant and work end to end. The mneme_* entries are mneme's memory tools
# (create_note/search/get_note/... — a glob), which mneme self-registers with
# daimon; thoth_remember authorizes the /remember write path (routed to
# mneme_create_note when the seam is bound, else the local .thoth/memory file).
[agent."thoth"]
allow = ["fs_write", "fs_read", "fs_mkdir", "bote_echo", "libro_query", "libro_retention", "libro_export", "libro_verify", "libro_proof", "mneme_*", "thoth_run", "thoth_write", "thoth_remember"]

[agent."thoth".rate_limit]
calls_per_minute = 120
EOF
    ok "wrote $tp"
  fi
}

# Register bote's tools with daimon (idempotent — re-register is fine).
register_tools() {
  local reg="http://127.0.0.1:$DAIMON_PORT/v1/mcp/tools"
  local cb="http://127.0.0.1:$BOTE_PORT/mcp"
  _reg() { # name desc props required
    local body
    body=$(printf '{"name":"%s","description":"%s","callback_url":"%s","inputSchema":{"type":"object","properties":%s,"required":%s}}' \
      "$1" "$2" "$cb" "$3" "$4")
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST "$reg" \
      -H 'Content-Type: application/json' -d "$body" 2>/dev/null
  }
  local a b c e
  a=$(_reg fs_write "Write a UTF-8 text file (parent dirs auto-created) under the project root." \
      '{"path":{"type":"string","description":"path relative to the project root"},"content":{"type":"string","description":"full file contents"}}' '["path","content"]')
  b=$(_reg fs_read  "Read a text file under the project root." \
      '{"path":{"type":"string"}}' '["path"]')
  c=$(_reg fs_mkdir "Create a directory (and parents) under the project root." \
      '{"path":{"type":"string"}}' '["path"]')
  e=$(_reg bote_echo "Echo the arguments back (bote sample tool)." '{}' '[]')
  if [ "$a" = "201" ] && [ "$b" = "201" ] && [ "$c" = "201" ]; then
    ok "registered fs_write / fs_read / fs_mkdir / bote_echo with daimon"
  else
    warn "tool registration incomplete (fs_write=$a fs_read=$b fs_mkdir=$c echo=$e) — is daimon+bote up?"
  fi
}

svc_status() {
  local name="$1" port="$2" pid; pid=$(port_pid "$port")
  if [ -n "$pid" ]; then ok "$name  :$port  (pid $pid)"; else err "$name  :$port  down"; fi
}

cmd_status() {
  say "AGNOS stack — home: ${c_d}$STACK_HOME${c_0}"
  svc_status hoosh  "$HOOSH_PORT"
  svc_status daimon "$DAIMON_PORT"
  svc_status bote   "$BOTE_PORT"
  if [ -x "$MNEME_DIR/build/mneme" ]; then svc_status mneme "$MNEME_PORT"; else warn "mneme  :$MNEME_PORT  not built (memory seam → local fallback)"; fi
  local tj; tj=$(curl -s --max-time 3 "http://127.0.0.1:$DAIMON_PORT/v1/mcp/tools" 2>/dev/null || true)
  if [ -n "$tj" ]; then
    say "  ${c_d}daimon tools:${c_0} $(printf '%s' "$tj" | grep -oE '"name":"[^"]+"' | cut -d'"' -f4 | paste -sd, - )"
  fi
  say ""
  if listening "$HOOSH_PORT" && listening "$DAIMON_PORT" && listening "$BOTE_PORT"; then
    say "start thoth:  ${c_g}cd $STACK_HOME && $THOTH_DIR/build/thoth --tier=rich${c_0}"
    say "        or:   ${c_g}$0 run${c_0}"
    say "workspace (the AI writes projects here): ${c_d}$WORKSPACE${c_0}"
  else
    say "bring it up:  ${c_g}$0 up${c_0}"
  fi
}

cmd_up() {
  mkdir -p "$RUN_DIR" "$LOG_DIR" "$WORKSPACE" "$MNEME_VAULT_DIR"
  write_configs
  load_key
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then ok "ANTHROPIC_API_KEY loaded (${ANTHROPIC_API_KEY:0:7}…)"
  else warn "ANTHROPIC_API_KEY not set — hoosh can't reach Anthropic. Export it, or point $STACK_HOME/.thoth/config.cyml at a local model."; fi
  local hb="$HOOSH_DIR/build/hoosh" db="$DAIMON_DIR/build/daimon" bb="$BOTE_DIR/build/bote"
  local mb="$MNEME_DIR/build/mneme"   # mneme is OPTIONAL — not in the required set
  local m=0
  for pair in "hoosh:$hb" "daimon:$db" "bote:$bb"; do
    [ -x "${pair#*:}" ] || { err "missing binary: ${pair#*:} — build ${pair%%:*} first"; m=1; }
  done
  [ "$m" -eq 0 ] || return 1
  say "starting stack (workspace: $WORKSPACE)…"
  start_svc hoosh  "$HOOSH_DIR"  "$LOG_DIR/hoosh.log"  "$RUN_DIR/hoosh.pid"  "$HOOSH_PORT"  "$hb" serve "$HOOSH_PORT"
  start_svc daimon "$DAIMON_DIR" "$LOG_DIR/daimon.log" "$RUN_DIR/daimon.pid" "$DAIMON_PORT" "$db" serve "$DAIMON_PORT"
  export BOTE_FS_ROOT="$WORKSPACE"
  start_svc bote   "$BOTE_DIR"   "$LOG_DIR/bote.log"   "$RUN_DIR/bote.pid"   "$BOTE_PORT"   "$bb" http "$BOTE_PORT"
  # mneme (optional): `serve` self-registers its memory tools with daimon (MNEME_DAIMON_URL), so it must start
  # AFTER daimon. Its vault persists under $STACK_HOME. Missing binary → the memory seam degrades to local.
  if [ -x "$mb" ]; then
    export MNEME_VAULT="$MNEME_VAULT_DIR"
    export MNEME_DAIMON_URL="http://127.0.0.1:$DAIMON_PORT"
    export MNEME_MCP_CALLBACK="http://127.0.0.1:$MNEME_PORT"
    start_svc mneme "$MNEME_DIR" "$LOG_DIR/mneme.log" "$RUN_DIR/mneme.pid" "$MNEME_PORT" "$mb" serve "$MNEME_PORT"
  else
    warn "mneme not built ($mb) — memory seam degrades to thoth's local .thoth/memory (build mneme to enable it)"
  fi
  register_tools
  say ""
  cmd_status
}

cmd_down() {
  stop_svc mneme  "$MNEME_PORT"  "$RUN_DIR/mneme.pid"
  stop_svc bote   "$BOTE_PORT"   "$RUN_DIR/bote.pid"
  stop_svc daimon "$DAIMON_PORT" "$RUN_DIR/daimon.pid"
  stop_svc hoosh  "$HOOSH_PORT"  "$RUN_DIR/hoosh.pid"
}

cmd_run() {
  cmd_up || return 1
  say ""
  say "launching thoth TUI (Ctrl-X / /quit to exit; stack stays up — '$0 down' to stop it)…"
  cd "$STACK_HOME" && exec "$THOTH_DIR/build/thoth" --tier=rich
}

cmd_logs() {
  for s in hoosh daimon bote mneme; do
    say "${c_d}== $s ==${c_0}"
    tail -n 20 "$LOG_DIR/$s.log" 2>/dev/null || say "  (no log yet)"
  done
}

usage() {
  sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'   # 2,22 stopped one line short — the port/model overrides never printed
}

case "${1:-}" in
  up)     cmd_up ;;
  down)   cmd_down ;;
  run)    cmd_run ;;
  status) cmd_status ;;
  logs)   cmd_logs ;;
  ""|-h|--help|help) usage ;;
  *) err "unknown command: $1"; usage; exit 2 ;;
esac
