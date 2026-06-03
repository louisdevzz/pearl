#!/usr/bin/env bash
set -u
PEARL_DIR=/opt/pearl
source "$PEARL_DIR/oc-profile.conf" 2>/dev/null || true
log(){ echo "$(date '+%F %T') [OC] $*"; }

if [ "${ENABLE_OC:-false}" != "true" ]; then
  log "OC off (stock clocks)."
  exit 0
fi
command -v nvidia-smi >/dev/null 2>&1 || { log "nvidia-smi not found"; exit 0; }

nvidia-smi -pm 1 >/dev/null 2>&1 || true
n=$(nvidia-smi -L 2>/dev/null | grep -c .)
log "Applying per-card OC to ${n:-0} card(s)."
i=0
while [ "$i" -lt "${n:-0}" ]; do
  eval "pl=\${PL$i:-}"
  eval "clk=\${CLK$i:-}"
  if [ -n "$pl" ]; then log "GPU$i power limit ${pl}W"; nvidia-smi -i "$i" -pl "$pl" 2>&1 | tail -1; fi
  if [ -n "$clk" ]; then log "GPU$i core clock lock 0,${clk}MHz"; nvidia-smi -i "$i" -lgc 0,"$clk" 2>&1 | tail -1; fi
  i=$((i+1))
done
log "OC done."
