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

- `pearl-miner-terminal.sh` — foreground terminal launcher.
- `pearl-miner-daemon.sh` — background daemon wrapper with `start`, `stop`, `restart`, `status`, and `logs`.
- `iso_rootfs_pearl/` — small extracted reference scripts from `/opt/pearl` and related service files.

## Usage on Linux NVIDIA host

```bash
chmod +x pearl-miner-terminal.sh
./pearl-miner-terminal.sh --host 129.226.55.135:9000 --user "YOUR_PRL_WALLET"
```

You can also use `--wallet` as an alias for `--user`.

The script downloads the miner with `curl` if available, otherwise it falls back to `wget`.

Optional foreground commands:

```bash
./pearl-miner-terminal.sh --status
./pearl-miner-terminal.sh --download-only
./pearl-miner-terminal.sh --stop
```

## Daemon / background usage

Start mining in the background:

```bash
chmod +x pearl-miner-daemon.sh
./pearl-miner-daemon.sh start --host 129.226.55.135:9000 --user "YOUR_PRL_WALLET"
```

Check, view logs, restart, or stop:

```bash
./pearl-miner-daemon.sh status
./pearl-miner-daemon.sh logs
./pearl-miner-daemon.sh logs --follow
./pearl-miner-daemon.sh restart --host 129.226.55.135:9000 --user "YOUR_PRL_WALLET"
./pearl-miner-daemon.sh stop
```

Daemon files are stored under `~/.pearl-miner-terminal/` by default:

- `pearl-miner.pid`
- `pearl-miner-daemon.log`
- `pearl-miner.log`

## Important

This miner is for Linux `x86_64` with NVIDIA/CUDA. It will not mine on macOS or
on a machine without NVIDIA drivers/GPU. On macOS, the script only supports safe
status/check behavior and refuses to run the miner.
