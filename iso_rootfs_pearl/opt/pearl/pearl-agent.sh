#!/usr/bin/env bash
set -u
PEARL_DIR=/opt/pearl
CONF="$PEARL_DIR/wallet.conf"
CODE_FILE="$PEARL_DIR/machine-code"
mkdir -p /run/pearl 2>/dev/null || true
LOG=/run/pearl/pearl-agent.log
log(){ echo "$(date '+%F %T') $*" >>"$LOG" 2>/dev/null; }

[ -f "$CONF" ] && source "$CONF"
RELAY_URL="${RELAY_URL:-}"
INTERVAL="${HEARTBEAT_SEC:-15}"

ensure_code(){
  if [ ! -s "$CODE_FILE" ]; then
    local src
    local src=""
    for i in /sys/class/net/*; do
      n="$(basename "$i")"; [ "$n" = "lo" ] && continue; [ -e "$i/device" ] || continue
      src="$(cat "$i/address" 2>/dev/null)"; [ -n "$src" ] && break
    done
    [ -z "$src" ] && src="$(cat /etc/machine-id 2>/dev/null)"
    [ -z "$src" ] && src="$(head -c16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    printf '%s' "$src" | sha256sum | tr 'a-f' 'A-F' | tr -dc 'A-F0-9' | head -c6 > "$CODE_FILE"
    printf '\n' >> "$CODE_FILE"
    log "Generated machine code: $(tr -dc 'A-Z0-9' < "$CODE_FILE")"
  fi
  CODE="$(tr -dc 'A-Z0-9' < "$CODE_FILE")"
}

restart_miner(){
  bash "$PEARL_DIR/stop-miner.sh" >>"$LOG" 2>&1
  if command -v systemctl >/dev/null 2>&1 && systemctl start pearl-miner.service >>"$LOG" 2>&1; then
    :
  else
    nohup bash "$PEARL_DIR/run-miner.sh" >>"$LOG" 2>&1 &
  fi
}

do_cmd(){
  case "$1" in
    stop)    log "CMD stop";    bash "$PEARL_DIR/stop-miner.sh" >>"$LOG" 2>&1 ;;
    restart) log "CMD restart"; restart_miner ;;
    reboot)  log "CMD reboot";  ( sleep 1; systemctl reboot 2>/dev/null || reboot 2>/dev/null || log "reboot not permitted (test env)" ) & ;;
    "")      ;;
    *)       log "CMD unknown: $1" ;;
  esac
}

[ -z "$RELAY_URL" ] && log "RELAY_URL chưa set trong wallet.conf — agent vẫn sinh mã máy, chưa gửi heartbeat."

while true; do
  ensure_code
  if [ -n "$RELAY_URL" ]; then
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    OUT="$(CODE="$CODE" IP="${IP:-}" RELAY="$RELAY_URL" python3 - <<'PY'
import os, json, urllib.request, glob
from collections import Counter

def mac():
    for i in sorted(glob.glob("/sys/class/net/*")):
        n = os.path.basename(i)
        if n == "lo" or not os.path.exists(i + "/device"):
            continue
        try:
            with open(i + "/address") as f:
                a = f.read().strip()
            if a:
                return a
        except Exception:
            pass
    return "-"

def http(url, data=None, timeout=8):
    req = urllib.request.Request(
        url, data=data,
        headers={"Content-Type": "application/json"} if data else {})
    return urllib.request.urlopen(req, timeout=timeout).read()

try:
    d = json.loads(http("http://127.0.0.1:8080/api/status", timeout=5))
except Exception:
    d = {}
g = d.get("gpus") or []
if g:
    c = Counter(x.get("name", "GPU") for x in g)
    gpus = ", ".join("%dx %s" % (n, nm) for nm, n in c.items())
else:
    gpus = "-"
payload = json.dumps({
    "code": os.environ.get("CODE", ""),
    "ip": os.environ.get("IP", "") or "-",
    "hashrate": (d.get("hashrate") or "-"),
    "mining": bool(d.get("mining")),
    "gpus": gpus,
    "mac": mac(),
}).encode()
cmd = ""
locked = "0"
try:
    r = json.loads(http(os.environ["RELAY"].rstrip("/") + "/heartbeat", data=payload, timeout=8))
    cmd = r.get("cmd", "") or ""
    locked = "1" if r.get("locked") else "0"
except Exception:
    pass
print(cmd)
print(locked)
PY
)"
    CMD="$(printf '%s\n' "$OUT" | sed -n 1p)"
    LOCKED="$(printf '%s\n' "$OUT" | sed -n 2p)"
    if [ "$LOCKED" = "1" ]; then
      bash "$PEARL_DIR/stop-miner.sh" >>"$LOG" 2>&1
    else
      [ -n "$CMD" ] && do_cmd "$CMD"
    fi
  fi
  sleep "$INTERVAL"
done
