#!/usr/bin/env bash
set -u

URL="http://localhost:8080"

for _ in $(seq 1 40); do
  curl -fsS "$URL/" >/dev/null 2>&1 && break
  sleep 1
done

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
MSG="Mo dien thoai (cung WiFi) vao:\n\n    http://${IP}:8080\n\nroi dan vi -> Apply."

for B in firefox chromium-browser chromium google-chrome epiphany-browser; do
  if command -v "$B" >/dev/null 2>&1; then
    "$B" --kiosk "$URL" >/dev/null 2>&1 &
    sleep 2
    command -v zenity >/dev/null 2>&1 && zenity --info --no-wrap --text="$MSG" >/dev/null 2>&1 &
    exit 0
  fi
done

if command -v zenity >/dev/null 2>&1; then
  exec zenity --info --no-wrap --text="$MSG"
elif command -v xmessage >/dev/null 2>&1; then
  exec xmessage -center "$MSG"
else
  exec xdg-open "$URL"
fi
