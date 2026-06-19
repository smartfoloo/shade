import Foundation

enum Constants {
    static let label = "com.shade.agent"
    static let binaryName = "shade"

    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// Where the binary is copied to on `install`.
    static var installedBinaryURL: URL {
        home.appendingPathComponent(".local/bin/\(binaryName)")
    }

    static var launchAgentURL: URL {
        home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logURL: URL {
        home.appendingPathComponent("Library/Logs/shade.log")
    }

    static var configDir: URL {
        home.appendingPathComponent(".config/shade")
    }

    static var exclusionsURL: URL {
        configDir.appendingPathComponent("exclusions.txt")
    }
}
