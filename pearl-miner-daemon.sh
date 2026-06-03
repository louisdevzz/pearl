#!/usr/bin/env bash
# Background daemon wrapper for pearl-miner-terminal.sh.
# Keeps the wallet out of the process command line by passing it via env.

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LAUNCHER="$SCRIPT_DIR/pearl-miner-terminal.sh"
APP_DIR="${PEARL_HOME:-$HOME/.pearl-miner-terminal}"
PID_FILE="${PEARL_PID_FILE:-$APP_DIR/pearl-miner.pid}"
DAEMON_LOG="${PEARL_DAEMON_LOG:-$APP_DIR/pearl-miner-daemon.log}"
HOST="${HOST:-129.226.55.135:9000}"
WALLET="${WALLET:-}"
MINER_URL="${MINER_URL:-https://pearlhash.xyz/downloads/pearl-miner-v11}"
MINER_BIN="${MINER_BIN:-pearl-miner}"
ACTION="${1:-help}"
FOLLOW_LOG=0
TAIL_LINES=80
FORCE_DOWNLOAD=0

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") start --user <PRL_WALLET> [options]
  $(basename "$0") start --wallet <PRL_WALLET> [options]
  WALLET=<PRL_WALLET> $(basename "$0") start [options]
  $(basename "$0") stop
  $(basename "$0") restart --user <PRL_WALLET> [options]
  $(basename "$0") status
  $(basename "$0") logs [--follow] [-n lines]

Options for start/restart:
  --user <value>         Wallet/address to mine to.
  --wallet <value>       Alias for --user.
  --host <host:port>     Pool host. Default: $HOST
  --miner-url <url>      Miner download URL. Default: $MINER_URL
  --home <dir>           Working dir. Default: ~/.pearl-miner-terminal
  --force-download       Re-download miner before running.

Daemon files:
  pid: $PID_FILE
  log: $DAEMON_LOG
USAGE
}

log() {
  mkdir -p "$APP_DIR"
  printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$DAEMON_LOG"
}

read_pid() {
  [ -f "$PID_FILE" ] || return 1
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s' "$pid"
}

is_running() {
  pid="$(read_pid 2>/dev/null || true)"
  [ -n "${pid:-}" ] && kill -0 "$pid" >/dev/null 2>&1
}

parse_options() {
  [ $# -gt 0 ] && shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --user|--wallet)
        [ $# -ge 2 ] || { echo "$1 needs a value" >&2; exit 2; }
        WALLET="$2"; shift 2 ;;
      --host)
        [ $# -ge 2 ] || { echo "--host needs a value" >&2; exit 2; }
        HOST="$2"; shift 2 ;;
      --miner-url)
        [ $# -ge 2 ] || { echo "--miner-url needs a value" >&2; exit 2; }
        MINER_URL="$2"; shift 2 ;;
      --home)
        [ $# -ge 2 ] || { echo "--home needs a value" >&2; exit 2; }
        APP_DIR="$2"
        PID_FILE="${PEARL_PID_FILE:-$APP_DIR/pearl-miner.pid}"
        DAEMON_LOG="${PEARL_DAEMON_LOG:-$APP_DIR/pearl-miner-daemon.log}"
        shift 2 ;;
      --force-download) FORCE_DOWNLOAD=1; shift ;;
      --follow|-f) FOLLOW_LOG=1; shift ;;
      -n)
        [ $# -ge 2 ] || { echo "-n needs a value" >&2; exit 2; }
        TAIL_LINES="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
  done
}

start_daemon() {
  if is_running; then
    echo "Pearl miner daemon already running (pid $(read_pid))."
    exit 0
  fi
  if [ -z "$WALLET" ]; then
    echo "Missing wallet. Pass --user <PRL_WALLET>, --wallet <PRL_WALLET>, or set WALLET=..." >&2
    exit 2
  fi
  if [ ! -x "$LAUNCHER" ]; then
    echo "Launcher not executable: $LAUNCHER" >&2
    exit 1
  fi

  mkdir -p "$APP_DIR"
  rm -f "$PID_FILE"

  args=(--host "$HOST" --miner-url "$MINER_URL")
  [ "$FORCE_DOWNLOAD" -eq 1 ] && args+=(--force-download)

  log "Starting Pearl miner daemon: $LAUNCHER --host $HOST --user <wallet-hidden>"
  (
    cd "$SCRIPT_DIR"
    PEARL_HOME="$APP_DIR" \
    WALLET="$WALLET" \
    HOST="$HOST" \
    MINER_URL="$MINER_URL" \
    MINER_BIN="$MINER_BIN" \
      nohup "$LAUNCHER" "${args[@]}" >>"$DAEMON_LOG" 2>&1 &
    echo $! >"$PID_FILE"
  )

  sleep 1
  if is_running; then
    echo "Pearl miner daemon started (pid $(read_pid))."
    echo "Log: $DAEMON_LOG"
  else
    echo "Pearl miner daemon exited quickly. Last log lines:" >&2
    tail -n 30 "$DAEMON_LOG" 2>/dev/null >&2 || true
    exit 1
  fi
}

stop_daemon() {
  if is_running; then
    pid="$(read_pid)"
    log "Stopping Pearl miner daemon pid $pid"
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 1 10); do
      kill -0 "$pid" >/dev/null 2>&1 || break
      sleep 1
    done
    kill -0 "$pid" >/dev/null 2>&1 && kill -KILL "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Pearl miner daemon stopped."
  else
    rm -f "$PID_FILE"
    echo "Pearl miner daemon is not running."
  fi

  PEARL_HOME="$APP_DIR" "$LAUNCHER" --stop >/dev/null 2>&1 || true
}

status_daemon() {
  if is_running; then
    echo "Pearl miner daemon: running (pid $(read_pid))"
  else
    echo "Pearl miner daemon: stopped"
  fi
  echo "Host: $HOST"
  echo "PID file: $PID_FILE"
  echo "Log: $DAEMON_LOG"
  [ -f "$DAEMON_LOG" ] && tail -n 12 "$DAEMON_LOG" || true
}

logs_daemon() {
  mkdir -p "$APP_DIR"
  touch "$DAEMON_LOG"
  if [ "$FOLLOW_LOG" -eq 1 ]; then
    tail -n "$TAIL_LINES" -f "$DAEMON_LOG"
  else
    tail -n "$TAIL_LINES" "$DAEMON_LOG"
  fi
}

case "$ACTION" in
  start)
    parse_options "$@"
    start_daemon ;;
  stop)
    parse_options "$@"
    stop_daemon ;;
  restart)
    parse_options "$@"
    stop_daemon
    start_daemon ;;
  status)
    parse_options "$@"
    status_daemon ;;
  logs)
    parse_options "$@"
    logs_daemon ;;
  --help|-h|help)
    usage ;;
  *)
    echo "Unknown action: $ACTION" >&2
    usage
    exit 2 ;;
esac
