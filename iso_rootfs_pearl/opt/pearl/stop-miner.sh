#!/usr/bin/env bash
systemctl stop pearl-miner.service 2>/dev/null    # SIGTERM cgroup -> SIGKILL sau TimeoutStopSec
for b in pearl-miner alpha-miner SRBMiner-MULTI srbminer; do
  pkill -9 -f "/opt/pearl/$b" 2>/dev/null
done
mb="$(grep -E '^MINER_BIN=' /opt/pearl/wallet.conf 2>/dev/null | cut -d= -f2)"
[ -n "$mb" ] && pkill -9 -f "/opt/pearl/$mb" 2>/dev/null
exit 0
