# Releasing

## Steps

1. Update the version in `VERSION`
2. Build the release zip (automatically tags and updates the Cask formula):
   ```sh
   make release
   ```
3. Commit and push:
   ```sh
   git add VERSION Casks/macnas.rb
   git commit -m "Release v$(cat VERSION)"
   git push --tags
   ```
4. Create a GitHub Release for the tag and upload `.build/release/MacNAS-<version>.zip`

## Architecture

Two-process model communicating over XPC:

- **MacNAS.app** — user-space menu bar app (SwiftUI). Manages UI, settings, and orchestrates health polling.
- **com.macnas.helper** — privileged LaunchDaemon (runs as root). Performs mount/unmount syscalls, health checks, and Spotlight blocking. Logs to `os_log` (subsystem `com.macnas.helper`, category `mount`).
