import Foundation

/// Handles installing/uninstalling the LaunchAgent and the binary it points at.
enum LaunchAgent {
    static func install() throws {
        let fm = FileManager.default

        // 1. Copy the currently-running binary to ~/.local/bin/shade
        let source = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let dest = Constants.installedBinaryURL
        try fm.createDirectory(
            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)

        // 2. Write the LaunchAgent plist.
        try fm.createDirectory(
            at: Constants.launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try plistContents(binary: dest.path)
            .write(to: Constants.launchAgentURL, atomically: true, encoding: .utf8)

        // 3. Load it.
        Launchctl.bootout() // clear any stale instance first
        Launchctl.bootstrap(plist: Constants.launchAgentURL)

        print("Installed.")
        print("  binary: \(dest.path)")
        print("  agent:  \(Constants.launchAgentURL.path)")
        print("  log:    \(Constants.logURL.path)")
        print("shade is now running and will start automatically at login.")
    }

    static func uninstall() throws {
        let fm = FileManager.default
        Launchctl.bootout()

        for url in [Constants.launchAgentURL, Constants.installedBinaryURL] {
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
        print("Uninstalled. (Exclusion config at \(Constants.configDir.path) was left intact.)")
    }

    private static func plistContents(binary: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(Constants.label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binary)</string>
                <string>run</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(Constants.logURL.path)</string>
            <key>StandardErrorPath</key>
            <string>\(Constants.logURL.path)</string>
        </dict>
        </plist>
        """
    }
}
