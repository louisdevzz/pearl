#!/usr/bin/env bash
S=/opt/pearl/statusboard.sh
for T in xfce4-terminal x-terminal-emulator xterm gnome-terminal; do
  command -v "$T" >/dev/null 2>&1 || continue
  case "$T" in
    xfce4-terminal) exec "$T" --geometry=104x32 --hide-menubar -T "Pearl Miner" -e "bash $S" ;;
    gnome-terminal) exec "$T" --geometry=104x32 -- bash "$S" ;;
    xterm)          exec "$T" -geometry 104x32 -fa Monospace -fs 11 -T "Pearl Miner" -e bash "$S" ;;
    *)              exec "$T" -e "bash $S" ;;
  esac
done
exec bash "$S"
