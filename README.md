# FRC Driver Station (Wine)

One-command installer for a known-good NI FRC 2026 Driver Station setup on Linux and macOS.

## Quick Install (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/AndreNijman/Linux-FRC-Driver-Station/main/install.sh | bash -s -- --repo AndreNijman/Linux-FRC-Driver-Station
```

## Quick Install (macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/AndreNijman/Linux-FRC-Driver-Station/main/install-macos.sh | bash -s -- --repo AndreNijman/Linux-FRC-Driver-Station
```

The installer automatically downloads the latest release assets, reassembles split parts, restores the Wine prefix, and installs launchers.

## What Gets Installed

- `~/.wine-ni-frc-2026`
- `~/.local/bin/ni-frc-2026-*`
- `~/.local/share/applications/ni-frc-2026-*.desktop` (Linux launchers; harmless on macOS)
- `~/.local/share/ni-frc-tools`

## Requirements

### Linux

- Linux x86_64
- Wine (installer will attempt automatic setup when missing)
- `curl`, `tar`, `zstd`, `rsync`

### macOS

- macOS (Darwin)
- Wine available as `wine` in `PATH` (installer will attempt setup via Homebrew when missing)
- `curl`, `tar`, `zstd`, `rsync` (`zstd` installer via Homebrew is attempted when missing)
- On Apple Silicon, use a Wine setup compatible with x86_64 tooling.

## If You Download Release Files Manually

Put all release files in one folder, then run:

Linux:

```bash
./install.sh --bundle-file ./ni-frc-2026-linux-full-<timestamp>.tar.zst.part-000
```

macOS:

```bash
./install-macos.sh --bundle-file ./ni-frc-2026-linux-full-<timestamp>.tar.zst.part-000
```

The installer will automatically stitch together `.part-###` files.

## Launch Driver Station

```bash
~/.local/bin/ni-frc-2026-driver-station
```

## Notes

- GitHub release files are split because of the 2 GB upload limit.
- `install.sh` can install an optional Linux `udev` rule; `install-macos.sh` skips Linux `udev` setup.
- Ethernet/Wi-Fi robot networking is recommended over USB tethering.
- Licensing for NI/FRC software remains your responsibility.
