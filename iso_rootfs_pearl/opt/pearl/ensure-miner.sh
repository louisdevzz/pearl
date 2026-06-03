#!/usr/bin/env bash
set -u
PEARL_DIR=/opt/pearl
source "$PEARL_DIR/wallet.conf" 2>/dev/null || true
MINER_BIN="${MINER_BIN:-pearl-miner}"
BIN="$PEARL_DIR/$MINER_BIN"
MODE="${1:-quiet}"

if [ -z "${MINER_URL:-}" ]; then
  case "$MINER_BIN" in
    pearl-miner) MINER_URL="https://pearlhash.xyz/downloads/pearl-miner-v11" ;;
    alpha-miner) MINER_URL="https://github.com/AlphaMine-Tech/alpha-miner/releases/latest/download/alpha-miner" ;;
    *)           MINER_URL="" ;;
  esac
fi
if [ -z "$MINER_URL" ]; then
  echo "No download URL for '$MINER_BIN' - set MINER_URL in wallet.conf"; exit 1
fi

exec 9>/tmp/pearl-miner-dl.lock; flock 9
if [ "$MODE" != "force" ] && [ -x "$BIN" ]; then exit 0; fi

if ! getent hosts pearlhash.xyz >/dev/null 2>&1 && ! getent hosts github.com >/dev/null 2>&1; then
  echo "DNS resolve failed - adding public DNS (1.1.1.1 / 8.8.8.8)..."
  rm -f /etc/resolv.conf 2>/dev/null || true
  printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf 2>/dev/null || true
fi

HOST_ONLY="$(echo "$MINER_URL" | sed -E 's#^[a-z]+://([^/]+).*#\1#; s#:.*##')"
for _ in $(seq 1 20); do
  getent hosts "$HOST_ONLY" >/dev/null 2>&1 && break
  echo "Waiting for network/DNS ($HOST_ONLY)..."; sleep 2
done

echo "Downloading latest miner:"; echo "  $MINER_URL"
rm -f "$BIN.part"
if command -v wget >/dev/null 2>&1; then
  wget --tries=8 --waitretry=3 --timeout=25 --continue --progress=dot:mega -O "$BIN.part" "$MINER_URL" 2>&1 \
    || { echo "Download FAILED (check network)"; rm -f "$BIN.part"; exit 1; }
else
  curl -L --fail --retry 8 --retry-delay 3 --connect-timeout 25 "$MINER_URL" -o "$BIN.part" \
    || { echo "Download FAILED (check network)"; rm -f "$BIN.part"; exit 1; }
fi
if [ "$(stat -c%s "$BIN.part" 2>/dev/null || echo 0)" -lt 100000 ]; then
  echo "Downloaded file too small - abort."; rm -f "$BIN.part"; exit 1
fi
chmod +x "$BIN.part"; mv "$BIN.part" "$BIN"
echo "OK: miner downloaded ($(stat -c%s "$BIN") bytes)."
exit 0
