# FRC 2026 Linux Portable (Wine)

Portable NI FRC 2026 Driver Station bundle for Linux with a one-command installer.

## What This Repo Does

- Ships an installer script (`install.sh`) that restores a known-good Wine prefix setup.
- Lets you publish a large bundle as a **GitHub Release asset**.
- Lets recipients install with one command from GitHub.

## Important

- The full working bundle is large (~6 GB) and is **not committed to git**.
- GitHub release uploads are capped at 2 GB per file. Upload the split `.part-###` files.
- Licensing for NI/FRC software is your responsibility.

## Maintainer Workflow (You)

1. Build a full folder bundle (already done on your machine):
   - `~/Downloads/ni-frc-2026-linux-full-...`
2. In this repo, create archive:
   - `./scripts/make-release-archive.sh`
3. Upload the generated split files in `dist/` to a GitHub release (tag `v1` or newer).

Asset name should look like:
- `ni-frc-2026-linux-full-YYYYMMDD-HHMMSS.tar.zst.part-000`
- `ni-frc-2026-linux-full-YYYYMMDD-HHMMSS.tar.zst.part-001`
- `ni-frc-2026-linux-full-YYYYMMDD-HHMMSS.tar.zst.part-002`

## Receiver One-Command Install

After you push this repo and upload a release asset:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash -s -- --repo OWNER/REPO
```

The installer automatically detects split assets, downloads all parts, reassembles, and installs.

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/andre/FRC-2026-Linux-Portable/main/install.sh | bash -s -- --repo andre/FRC-2026-Linux-Portable
```

## Local Test (on your machine)

```bash
./scripts/quick-run-local.sh
```

## Launch Command After Install

```bash
~/.local/bin/ni-frc-2026-driver-station
```
