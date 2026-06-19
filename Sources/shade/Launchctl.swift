import Foundation

/// Thin wrapper around `launchctl` for managing the per-user GUI domain agent.
enum Launchctl {
    private static var domainTarget: String {
        "gui/\(getuid())"
    }

    private static var serviceTarget: String {
        "\(domainTarget)/\(Constants.label)"
    }

    @discardableResult
    private static func run(_ args: [String]) -> (status: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return (-1, "failed to run launchctl: \(error)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    /// Load the agent. Prefers modern `bootstrap`, falls back to `load -w`.
    static func bootstrap(plist: URL) {
        let result = run(["bootstrap", domainTarget, plist.path])
        if result.status != 0 {
            _ = run(["load", "-w", plist.path])
        }
    }

    static func bootout() {
        let result = run(["bootout", serviceTarget])
        if result.status != 0 {
            _ = run(["unload", "-w", Constants.launchAgentURL.path])
        }
    }

    /// Restart the running service.
    static func kickstart() {
        _ = run(["kickstart", "-k", serviceTarget])
    }

    static func isLoaded() -> Bool {
        run(["print", serviceTarget]).status == 0
    }

    static func printDetails() -> String {
        run(["print", serviceTarget]).output
    }
}
