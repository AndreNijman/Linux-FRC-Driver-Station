# Linux FRC Driver Station (Wine)

One-command installer for a known-good NI FRC 2026 Driver Station setup on Linux.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/AndreNijman/Linux-FRC-Driver-Station/main/install.sh | bash -s -- --repo AndreNijman/Linux-FRC-Driver-Station
```

The installer automatically downloads the latest release assets, reassembles split parts, restores the Wine prefix, and installs launchers.

## What Gets Installed

- `~/.wine-ni-frc-2026`
- `~/.local/bin/ni-frc-2026-*`
- `~/.local/share/applications/ni-frc-2026-*.desktop`
- `~/.local/share/ni-frc-tools`

## Requirements

- Linux x86_64
- Wine (with 32-bit support)
- `curl`, `tar`, `zstd`, `rsync`

## If You Download Release Files Manually

Put all release files in one folder, then run:

```bash
./install.sh --bundle-file ./ni-frc-2026-linux-full-<timestamp>.tar.zst.part-000
```

The installer will automatically stitch together `.part-###` files.

## Launch Driver Station

```bash
~/.local/bin/ni-frc-2026-driver-station
```

## Notes

- GitHub release files are split because of the 2 GB upload limit.
- Ethernet/Wi-Fi robot networking is recommended over USB tethering on Linux.
- Licensing for NI/FRC software remains your responsibility.
