import Foundation

/// Manages the exclusion list — bundle identifiers that should never be hidden.
/// Stored one-per-line at ~/.config/shade/exclusions.txt
enum Config {
    static func load() -> Set<String> {
        guard let contents = try? String(contentsOf: Constants.exclusionsURL, encoding: .utf8) else {
            return []
        }
        let ids = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return Set(ids)
    }

    static func save(_ ids: Set<String>) throws {
        try FileManager.default.createDirectory(
            at: Constants.configDir, withIntermediateDirectories: true
        )
        let body = ids.sorted().joined(separator: "\n") + "\n"
        try body.write(to: Constants.exclusionsURL, atomically: true, encoding: .utf8)
    }

    static func add(_ id: String) throws {
        var ids = load()
        ids.insert(id)
        try save(ids)
    }

    static func remove(_ id: String) throws {
        var ids = load()
        ids.remove(id)
        try save(ids)
    }
}
