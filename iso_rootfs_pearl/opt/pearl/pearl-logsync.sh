#!/usr/bin/env bash
set -u
MP=/mnt/pearllog

ensure_pearllog(){
  blkid -L PEARLLOG >/dev/null 2>&1 && return 0
  command -v sgdisk >/dev/null 2>&1 || return 1
  local src disk new
  src="$(findmnt -no SOURCE /cdrom 2>/dev/null)"
  [ -z "$src" ] && src="$(findmnt -no SOURCE /run/live/medium 2>/dev/null)"
  [ -z "$src" ] && src="$(blkid -L PEARL_MINER 2>/dev/null | head -1)"
  [ -z "$src" ] && return 1
  disk="$(lsblk -no pkname "$src" 2>/dev/null | head -1)"
  [ -z "$disk" ] && return 1
  disk="/dev/$disk"; [ -b "$disk" ] || return 1
  local before after
  before="$(lsblk -rno NAME "$disk" 2>/dev/null | sort)"
  sgdisk -e "$disk" >/dev/null 2>&1
  sgdisk -n 0:0:0 -t 0:8300 -c 0:PEARLLOG "$disk" >/dev/null 2>&1 || return 1
  partx -a "$disk" >/dev/null 2>&1 || partprobe "$disk" >/dev/null 2>&1 || true
  sleep 2
  after="$(lsblk -rno NAME "$disk" 2>/dev/null | sort)"
  new="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -1)"
  [ -n "$new" ] || return 1
  new="/dev/$new"; [ -b "$new" ] || return 1
  mkfs.ext4 -F -L PEARLLOG "$new" >/dev/null 2>&1 || return 1
  partx -a "$disk" >/dev/null 2>&1 || true
  sleep 1
}

DEV=""
for _ in $(seq 1 20); do DEV="$(blkid -L PEARLLOG 2>/dev/null)"; [ -n "$DEV" ] && break; sleep 1; done
if [ -z "$DEV" ]; then
  ensure_pearllog
  for _ in $(seq 1 12); do DEV="$(blkid -L PEARLLOG 2>/dev/null)"; [ -n "$DEV" ] && break; sleep 1; done
fi
[ -z "$DEV" ] && exit 0
mkdir -p "$MP"
mountpoint -q "$MP" || mount "$DEV" "$MP" 2>/dev/null || exit 0
mkdir -p "$MP/config" "$MP/bin" "$MP/logs"

miner_bin(){ local b; b="$(grep -E '^MINER_BIN=' /opt/pearl/wallet.conf 2>/dev/null | cut -d= -f2)"; echo "${b:-pearl-miner}"; }

[ -f "$MP/config/wallet.conf" ]     && cp -f "$MP/config/wallet.conf"     /opt/pearl/wallet.conf     2>/dev/null
[ -f "$MP/config/oc-profile.conf" ] && cp -f "$MP/config/oc-profile.conf" /opt/pearl/oc-profile.conf 2>/dev/null
[ -f "$MP/config/machine-code" ]    && cp -f "$MP/config/machine-code"    /opt/pearl/machine-code    2>/dev/null
MB="$(miner_bin)"
[ -f "$MP/bin/$MB" ] && { cp -f "$MP/bin/$MB" "/opt/pearl/$MB" 2>/dev/null; chmod +x "/opt/pearl/$MB" 2>/dev/null; }

while true; do
  cp -f /opt/pearl/wallet.conf /opt/pearl/oc-profile.conf "$MP/config/" 2>/dev/null
  [ -f /opt/pearl/machine-code ] && cp -f /opt/pearl/machine-code "$MP/config/" 2>/dev/null
  MB="$(miner_bin)"
  [ -x "/opt/pearl/$MB" ] && cp -f "/opt/pearl/$MB" "$MP/bin/$MB" 2>/dev/null
  for f in pearl-web pearl-action pearl-miner pearl-firstboot pearl-agent; do
    [ -f "/run/pearl/$f.log" ] && cp -f "/run/pearl/$f.log" "$MP/logs/$f.log" 2>/dev/null
  done
  {
    echo "=== $(date) ==="
    echo "ip: $(hostname -I 2>&1)"
    echo "gpu:"; nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,utilization.gpu \
                  --format=csv,noheader 2>&1
    echo "web: $(systemctl is-active pearl-web 2>&1)  miner: $(systemctl is-active pearl-miner 2>&1)"
    echo "miner tail:"; tail -6 /run/pearl/pearl-miner.log 2>/dev/null
  } > "$MP/logs/diag.txt" 2>&1
  sync
  sleep 10
done
