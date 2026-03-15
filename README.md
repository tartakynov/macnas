# MacNAS

A macOS menu bar app that manages NFS mounts to a NAS, with automatic health monitoring, recovery, and Spotlight blocking.

Requires macOS 14.0+ (Sonoma). No external dependencies.

## Building

```sh
make
```

This builds both:
- **MacNAS.app** — menu bar app (`.build/release/MacNAS.app`)
- **com.macnas.helper** — LaunchDaemon that runs as root to perform mount/unmount operations

## Installing the Helper Daemon

The helper daemon must be installed and running for mounts to work. It runs as root via launchd and communicates with the menu bar app over XPC.

The app **automatically installs** (or updates) the helper on launch — it prompts for your administrator password via the standard macOS authorization dialog. No manual steps needed.

For manual installation (e.g. headless setups):

```sh
sudo make install-helper
```

To uninstall:

```sh
sudo make uninstall-helper
```

## Running the App

```sh
make run
```

Or double-click `MacNAS.app` in `.build/release/`.

The app appears as a drive icon in the menu bar — no Dock icon. It automatically registers as a **login item** so it launches on boot.

## Configuration

Click the menu bar icon to open the popover, then click **Settings** to open the settings window.

Configuration is stored at `~/Library/Application Support/MacNAS/config.json`.

### General

- **Server IP** — your NAS IP address (e.g. `192.168.1.100`)
- **Mount Root** — local directory for mount points (default: `/Volumes/NAS`)
- **Poll Interval** — health check frequency in seconds (default: 15, minimum: 5)

### Mounts

Add, edit, or remove NFS exports:

- **Export Path** — NFS export on the server (e.g. `/volume1/media`), must start with `/`
- **Mount Name** — local subdirectory name (e.g. `media` → mounts at `/Volumes/NAS/media`), no slashes or spaces

## Menu Bar

### Icon States

| Icon | Color | Meaning |
|------|-------|---------|
| Drive + checkmark | Green | All mounts healthy |
| Warning triangle | Red | Network down or all mounts failed |
| Drive + exclamation | Yellow | Some mounts unhealthy |
| Plain drive | Gray | No mounts configured or not yet checked |

### Popover Menu

The popover shows:
- Server status (IP address with reachable/unreachable indicator)
- Each mount with its current status and a remount button for unhealthy mounts
- Settings and Quit buttons

### Per-Mount Status

| Status | Color | Meaning |
|--------|-------|---------|
| Mounted | Green | NFS share accessible and healthy |
| Not Mounted | Yellow | Share not in mount table |
| Stale | Red | Stale NFS file handle |
| Unreachable | Red | Mount exists but unresponsive |
| No Network | Red | No network connectivity |
| Error | Red | Mount operation failed |
| Unknown | Gray | Not yet checked |

## How It Works

- On launch, the app applies the saved config via XPC, mounting all configured shares
- Mounts use `mount_nfs` with: NFSv3, TCP, hard mounts, interruptible, reserved port, 5 retransmissions, 3s timeout, 32KB read/write buffers, 16-block readahead, local locks, `nobrowse`/`nodev`/`nosuid`
- Health checks run at the configured poll interval (default 15s):
  1. Checks network availability via `NWPathMonitor`
  2. Pings the NFS server with ICMP (`ping -c 1 -W 3`)
  3. Verifies each mount with `stat` (5s timeout to detect stale handles)
- Automatic recovery: missing mounts are remounted; stale or unreachable mounts are force-unmounted then remounted
- After sleep/wake (3s delay) or network reconnection (2s delay), an immediate health check runs
- Spotlight indexing is blocked on each mount via `.metadata_never_index` and `mdutil -i off`

## Architecture

Two-process model communicating over XPC:

- **MacNAS.app** — user-space menu bar app (SwiftUI). Manages UI, settings, and orchestrates health polling.
- **com.macnas.helper** — privileged LaunchDaemon (runs as root). Performs mount/unmount syscalls, health checks, and Spotlight blocking. Logs to `os_log` (subsystem `com.macnas.helper`, category `mount`).
