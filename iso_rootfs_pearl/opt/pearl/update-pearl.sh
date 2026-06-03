#!/usr/bin/env bash
set -eu

PEARL_DIR="/opt/pearl"

UPDATE_URL="${UPDATE_URL:-https://pearlhash.xyz/downloads/pearl-miner-v11}"

TMP="$(mktemp)"
echo "Tải bản mới từ: ${UPDATE_URL}"
if ! curl -fsSL "$UPDATE_URL" -o "$TMP"; then
  echo "LỖI: tải thất bại. Kiểm tra mạng / URL."
  rm -f "$TMP"
  exit 1
fi

if [ "$(stat -c%s "$TMP" 2>/dev/null || echo 0)" -lt 100000 ]; then
  echo "LỖI: file tải về quá nhỏ, có thể hỏng. Huỷ cập nhật."
  rm -f "$TMP"
  exit 1
fi

chmod +x "$TMP"
mv "$TMP" "${PEARL_DIR}/pearl-miner"
echo "Đã cập nhật miner -> ${PEARL_DIR}/pearl-miner"

echo "Khởi động lại miner..."
systemctl restart pearl-miner.service 2>/dev/null \
  || sudo systemctl restart pearl-miner.service
echo "Xong."
