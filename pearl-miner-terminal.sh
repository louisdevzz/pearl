#!/usr/bin/env bash
# Standalone terminal launcher reconstructed from pearl-miner-os-v1.11.iso.
# Source behavior found in ISO rootfs:
#   /opt/pearl/ensure-miner.sh -> downloads https://pearlhash.xyz/downloads/pearl-miner-v11
#   /opt/pearl/run-miner.sh    -> execs: pearl-miner --host <HOST> --user <WALLET>
#
# This script intentionally does NOT include the ISO dashboard, relay agent,
# systemd services, logsync partition handling, or overclock automation.

set -Eeuo pipefail

DEFAULT_HOST="129.226.55.135:9000"
DEFAULT_MINER_URL="https://pearlhash.xyz/downloads/pearl-miner-v11"
APP_DIR="${PEARL_HOME:-$HOME/.pearl-miner-terminal}"
MINER_BIN="${MINER_BIN:-pearl-miner}"
MINER_PATH_FROM_ENV="${MINER_PATH:-}"
LOG_FILE_FROM_ENV="${PEARL_LOG:-}"
MINER_PATH="${MINER_PATH_FROM_ENV:-$APP_DIR/$MINER_BIN}"
LOG_FILE="${LOG_FILE_FROM_ENV:-$APP_DIR/pearl-miner.log}"

HOST="${HOST:-$DEFAULT_HOST}"
WALLET="${WALLET:-}"
MINER_URL="${MINER_URL:-$DEFAULT_MINER_URL}"
FORCE_DOWNLOAD=0
ACTION="run"

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --wallet <PRL_WALLET> [options]
  WALLET=<PRL_WALLET> $(basename "$0") [options]

Options:
  --wallet <value>       Wallet/address to mine to. Required for --run.
  --host <host:port>     Pool host. Default from ISO: $DEFAULT_HOST
  --miner-url <url>      Miner download URL. Default from ISO: $DEFAULT_MINER_URL
  --home <dir>           Working dir. Default: ~/.pearl-miner-terminal
  --download-only        Download/update miner, then exit.
  --force-download       Re-download miner even if it already exists.
  --status              Show environment and miner status only; does not mine.
  --stop                Stop miner processes started from this script path.
  --help                Show this help.

Important:
  - The ISO miner is a Linux NVIDIA/CUDA miner. It will not mine on macOS or
    on machines without NVIDIA drivers/GPU.
  - On this Mac, use --status or --download-only only if you just want to inspect.
USAGE
}

log() {
  mkdir -p "$APP_DIR"
  printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --wallet)
        [ $# -ge 2 ] || { echo "--wallet needs a value" >&2; exit 2; }
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
        [ -z "$MINER_PATH_FROM_ENV" ] && MINER_PATH="$APP_DIR/$MINER_BIN"
        [ -z "$LOG_FILE_FROM_ENV" ] && LOG_FILE="$APP_DIR/pearl-miner.log"
        shift 2 ;;
      --download-only) ACTION="download"; shift ;;
      --force-download) FORCE_DOWNLOAD=1; shift ;;
      --status|status) ACTION="status"; shift ;;
      --stop|stop) ACTION="stop"; shift ;;
      --run|run) ACTION="run"; shift ;;
      --help|-h) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
  done
}

is_linux_x86_64() {
  [ "$(uname -s 2>/dev/null)" = "Linux" ] && [ "$(uname -m 2>/dev/null)" = "x86_64" ]
}

has_nvidia_runtime() {
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1
}

status() {
  echo "Pearl terminal miner status"
  echo "  os:        $(uname -s 2>/dev/null || echo unknown)"
  echo "  arch:      $(uname -m 2>/dev/null || echo unknown)"
  echo "  app_dir:   $APP_DIR"
  echo "  miner:     $MINER_PATH"
  echo "  host:      $HOST"
  echo "  wallet:    $([ -n "$WALLET" ] && echo set || echo missing)"
  echo "  nvidia:    $(has_nvidia_runtime && echo available || echo not_available)"
  if [ -x "$MINER_PATH" ]; then
    ls -lh "$MINER_PATH"
    file "$MINER_PATH" 2>/dev/null || true
  else
    echo "  miner_bin: not_downloaded"
  fi
}

download_miner() {
  mkdir -p "$APP_DIR"
  if [ "$FORCE_DOWNLOAD" -ne 1 ] && [ -x "$MINER_PATH" ]; then
    log "Miner already exists: $MINER_PATH"
    return 0
  fi

  need_cmd curl
  tmp="$MINER_PATH.part"
  log "Downloading miner from: $MINER_URL"
  rm -f "$tmp"
  curl -L --fail --retry 8 --retry-delay 3 --connect-timeout 25 "$MINER_URL" -o "$tmp"

  size="$(wc -c < "$tmp" | tr -d ' ')"
  if [ "${size:-0}" -lt 100000 ]; then
    rm -f "$tmp"
    echo "Downloaded file is too small; aborting." >&2
    exit 1
  fi

  chmod +x "$tmp"
  mv "$tmp" "$MINER_PATH"
  log "Miner ready: $MINER_PATH ($size bytes)"
}

stop_miner() {
  if pgrep -f "$MINER_PATH" >/dev/null 2>&1; then
    pkill -TERM -f "$MINER_PATH" || true
    sleep 2
    pkill -KILL -f "$MINER_PATH" || true
    log "Stopped miner process: $MINER_PATH"
  else
    log "No miner process found for: $MINER_PATH"
  fi
}

run_miner() {
  if [ -z "$WALLET" ]; then
    echo "Missing wallet. Pass --wallet <PRL_WALLET> or set WALLET=..." >&2
    exit 2
  fi

  # Hard guard: the ISO miner is Linux x86_64 + NVIDIA oriented.
  # Do not try to run it on this Mac or on non-NVIDIA hosts.
  if ! is_linux_x86_64; then
    status
    echo
    echo "Refusing to run: this miner is for Linux x86_64, not this OS/arch." >&2
    exit 1
  fi
  if ! has_nvidia_runtime; then
    status
    echo
    echo "Refusing to run: NVIDIA runtime/driver not detected." >&2
    exit 1
  fi

  download_miner
  log "Mining: $MINER_PATH --host $HOST --user <wallet-hidden>"
  "$MINER_PATH" --host "$HOST" --user "$WALLET" 2>&1 | tee -a "$LOG_FILE"
}

parse_args "$@"
case "$ACTION" in
  status) status ;;
  download) download_miner; status ;;
  stop) stop_miner ;;
  run) run_miner ;;
  *) echo "Unknown action: $ACTION" >&2; exit 2 ;;
esac
