#!/usr/bin/env bash
set -u
PEARL_DIR=/opt/pearl
CONF="$PEARL_DIR/wallet.conf"
mkdir -p /run/pearl 2>/dev/null || true
LOG=/run/pearl/pearl-miner.log
log(){ echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

[ -f "$CONF" ] && source "$CONF"
MINER_BIN="${MINER_BIN:-pearl-miner}"
HOST="${HOST:-}"
WALLET="${WALLET:-}"
WORKER="${WORKER:-}"
BIN="$PEARL_DIR/$MINER_BIN"

if [ -z "$WALLET" ]; then
  log "No wallet - set it on the dashboard, then press Start."; sleep 3; exit 1
fi
if [ ! -x "$BIN" ]; then
  log "No miner - press 'Download latest miner' on the dashboard."; sleep 3; exit 1
fi

bash "$PEARL_DIR/overclock.sh" >>"$LOG" 2>&1 || true

case "$MINER_BIN" in
  alpha-miner)
    POOL="$HOST"
    case "$POOL" in stratum+tcp://*) ;; *) POOL="stratum+tcp://$POOL" ;; esac
    set -- --pool "$POOL" --address "$WALLET"
    [ -n "$WORKER" ] && set -- "$@" --worker "$WORKER"
    ;;
  *)
    set -- --host "$HOST" --user "$WALLET"
    ;;
esac

log "Mining: $MINER_BIN $*"
exec "$BIN" "$@" >>"$LOG" 2>&1
