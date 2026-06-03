#!/usr/bin/env bash
set -u
LOGDIR=/run/pearl; mkdir -p "$LOGDIR" 2>/dev/null || true
MLOG=$LOGDIR/pearl-miner.log
ALOG=$LOGDIR/pearl-action.log
WLOG=$LOGDIR/pearl-web.log
touch "$MLOG" "$ALOG" "$WLOG" 2>/dev/null || true
CY=$'\e[1;36m'; GR=$'\e[1;32m'; YE=$'\e[1;33m'; RD=$'\e[1;31m'; DM=$'\e[2m'; RS=$'\e[0m'

ip_addr(){ hostname -I 2>/dev/null | awk '{print $1}'; }

clear; printf '%sPEARL MINER%s\n\nWaiting for network...\n' "$CY" "$RS"
for _ in $(seq 1 60); do [ -n "$(ip_addr)" ] && break; sleep 1; done

while true; do
  IPS="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.' )"
  gpu="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | paste -sd', ' -)"
  [ -z "$gpu" ] && gpu="(no NVIDIA driver)"
  if systemctl is-active --quiet pearl-web.service; then WEB="${GR}active${RS}"; else WEB="${RD}DEAD${RS}"; fi
  [ "$(wc -l < "$WLOG" 2>/dev/null || echo 0)" -gt 400 ] && tail -n 200 "$WLOG" > "$WLOG.t" 2>/dev/null && mv "$WLOG.t" "$WLOG" 2>/dev/null
  clear
  printf '%s============================================================%s\n' "$DM" "$RS"
  printf '  %sPEARL MINER%s   web server: %b\n' "$CY" "$RS" "$WEB"
  printf '  GPU: %s\n' "$gpu"
  printf '  %sĐiện thoại (CÙNG WiFi) mở 1 trong các địa chỉ:%s\n' "$YE" "$RS"
  if [ -n "$IPS" ]; then
    for x in $IPS; do printf '     %shttp://%s:8080%s\n' "$GR" "$x" "$RS"; done
  else
    printf '     (chưa có IP - kiểm tra dây mạng/WiFi)\n'
  fi
  printf '%s============================================================%s\n' "$DM" "$RS"
  printf '%sPhone requests (live):%s\n' "$DM" "$RS"
  tail -n 5 "$WLOG" 2>/dev/null | sed 's/^/  /'
  printf '%sSetup log:%s\n' "$DM" "$RS"
  tail -n 7 "$ALOG" 2>/dev/null | sed 's/^/  /'
  printf '%sMiner log:%s\n' "$DM" "$RS"
  tail -n 8 "$MLOG" 2>/dev/null | sed 's/^/  /'
  printf '%s(refresh 2s; if "GET /api/status" keeps scrolling, phone IS connected)%s\n' "$DM" "$RS"
  sleep 2
done
