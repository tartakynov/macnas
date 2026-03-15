import Foundation
import os.log

private let logger = Logger(subsystem: "com.macnas.app", category: "installer")

/// Installs the privileged helper daemon if missing or outdated.
/// Prompts for administrator credentials via the system authorization dialog.
enum HelperInstaller {
    private static let helperInstallPath = "/usr/local/bin/com.macnas.helper"
    private static let plistInstallPath = "/Library/LaunchDaemons/com.macnas.helper.plist"
    private static let stampPath: String = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("MacNAS/helper-stamp").path
    }()

    /// Check whether the helper needs to be installed and install it if so.
    static func installIfNeeded() {
        guard let bundledHelper = Bundle.main.path(forResource: "com.macnas.helper", ofType: nil),
              let bundledPlist = Bundle.main.path(forResource: "com.macnas.helper", ofType: "plist"),
              let bundledEntitlements = Bundle.main.path(forResource: "helper-entitlements", ofType: "plist") else {
            logger.error("Helper resources not found in app bundle")
            return
        }

        if !needsInstall() {
            logger.info("Helper daemon is up to date (build \(BuildInfo.gitSHA.prefix(7), privacy: .public))")
            return
        }

        logger.notice("Helper installation required — prompting for authorization")
        install(bundledHelper: bundledHelper, bundledPlist: bundledPlist, bundledEntitlements: bundledEntitlements)
    }

    // MARK: - Private

    private static func needsInstall() -> Bool {
        let fm = FileManager.default

        guard fm.fileExists(atPath: helperInstallPath),
              fm.fileExists(atPath: plistInstallPath) else {
            logger.notice("Helper not found at \(helperInstallPath, privacy: .public) or plist missing")
            return true
        }

        // Compare the git SHA baked into this build against the stamp written after last install.
        guard let stampData = fm.contents(atPath: stampPath),
              let stamp = String(data: stampData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              stamp == BuildInfo.gitSHA else {
            logger.notice("Installed helper build differs from app build \(BuildInfo.gitSHA.prefix(7), privacy: .public) — update needed")
            return true
        }

        return false
    }

    private static func writeStamp() {
        try? BuildInfo.gitSHA.write(toFile: stampPath, atomically: true, encoding: .utf8)
    }

    private static func install(bundledHelper: String, bundledPlist: String, bundledEntitlements: String) {
        // Write an install script to a temp file to avoid AppleScript escaping issues
        let scriptPath = NSTemporaryDirectory() + "macnas-install-helper.sh"
        let script = """
        #!/bin/sh
        set -e
        mkdir -p /usr/local/bin
        cp \(shellQuote(bundledHelper)) \(shellQuote(helperInstallPath))
        codesign --force --sign - --entitlements \(shellQuote(bundledEntitlements)) \(shellQuote(helperInstallPath))
        cp \(shellQuote(bundledPlist)) \(shellQuote(plistInstallPath))
        launchctl bootout system/com.macnas.helper 2>/dev/null || true
        launchctl bootstrap system \(shellQuote(plistInstallPath))
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to write install script: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Use AppleScript to run the script with administrator privileges.
        // This triggers the standard macOS authorization dialog.
        let appleScriptSource = "do shell script \"sh \(shellQuote(scriptPath))\" with administrator privileges"
        guard let appleScript = NSAppleScript(source: appleScriptSource) else {
            logger.error("Failed to create authorization script")
            return
        }

        var errorInfo: NSDictionary?
        appleScript.executeAndReturnError(&errorInfo)

        // Clean up temp script
        try? FileManager.default.removeItem(atPath: scriptPath)

        if let errorInfo {
            // User cancelled (-128) is not an error worth logging as error
            let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int
            if errorNumber == -128 {
                logger.notice("Helper installation cancelled by user")
            } else {
                let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown error"
                logger.error("Helper installation failed: \(message, privacy: .public)")
            }
        } else {
            logger.notice("Helper daemon installed successfully (build \(BuildInfo.gitSHA.prefix(7), privacy: .public))")
            writeStamp()
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
