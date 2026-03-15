import Foundation

/// Result of running a subprocess.
struct ProcessResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var timedOut: Bool
}

/// Runs subprocesses with optional timeout support.
enum ProcessRunner {

    /// Run a command directly (no shell).
    static func run(_ command: String, args: [String], timeout: TimeInterval? = nil) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }

        if let timeout {
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                process.waitUntilExit()
                semaphore.signal()
            }

            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                return ProcessResult(exitCode: -1, stdout: "", stderr: "", timedOut: true)
            }
        } else {
            process.waitUntilExit()
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            timedOut: false
        )
    }
}
