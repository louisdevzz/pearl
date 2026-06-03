#!/usr/bin/env bash
set -u
mkdir -p /run/pearl 2>/dev/null || true
LOG=/run/pearl/pearl-firstboot.log

U="$(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1; exit}')"
if [ -n "$U" ]; then
  usermod -aG video,render "$U" 2>>"$LOG" || true
  DSK="/home/$U/Desktop"
  mkdir -p "$DSK"
  cp -f /usr/share/applications/pearl-dashboard.desktop "$DSK/" 2>/dev/null || true
  chmod +x "$DSK/pearl-dashboard.desktop" 2>/dev/null || true
  chown -R "$U:$U" "$DSK" 2>/dev/null || true
fi
exit 0
