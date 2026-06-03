# Pearl Miner Terminal Launcher

Standalone bash launcher reconstructed from `pearl-miner-os-v1.11.iso`.

The ISO booted a Xubuntu live system and eventually ran the miner through:

```bash
pearl-miner --host 129.226.55.135:9000 --user <WALLET>
```

This repo keeps the terminal version only. It does not include the full live OS,
GUI dashboard, systemd services, NVIDIA driver installer, kiosk UI, or logsync
partition setup.

## Files

- `pearl-miner-terminal.sh` — standalone launcher.
- `iso_rootfs_pearl/` — small extracted reference scripts from `/opt/pearl` and related service files.

## Usage on Linux NVIDIA host

```bash
chmod +x pearl-miner-terminal.sh
./pearl-miner-terminal.sh --wallet "YOUR_PRL_WALLET"
```

Optional:

```bash
./pearl-miner-terminal.sh --status
./pearl-miner-terminal.sh --download-only
./pearl-miner-terminal.sh --stop
```

## Important

This miner is for Linux `x86_64` with NVIDIA/CUDA. It will not mine on macOS or
on a machine without NVIDIA drivers/GPU. On macOS, the script only supports safe
status/check behavior and refuses to run the miner.
