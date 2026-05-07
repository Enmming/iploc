import Foundation

public struct DatabaseMetadata: Codable, Equatable, Sendable {
    public let release: DBIPDatabaseRelease
    public let installedAt: Date
    public let sourceURL: URL

    public init(release: DBIPDatabaseRelease, installedAt: Date, sourceURL: URL) {
        self.release = release
        self.installedAt = installedAt
        self.sourceURL = sourceURL
    }
}

public struct DatabaseStore: Sendable {
    public let directoryURL: URL
    public let activeDatabaseURL: URL
    public let metadataURL: URL

    public init(applicationSupportDirectory: URL) {
        self.directoryURL = applicationSupportDirectory.appendingPathComponent("IPLoc", isDirectory: true)
        self.activeDatabaseURL = directoryURL.appendingPathComponent("dbip-city-lite.mmdb")
        self.metadataURL = directoryURL.appendingPathComponent("dbip-city-lite.json")
    }

    public static func userApplicationSupport(fileManager: FileManager = .default) throws -> DatabaseStore {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return DatabaseStore(applicationSupportDirectory: applicationSupport)
    }

    public func ensureDirectoryExists(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func databaseExists(fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: activeDatabaseURL.path)
    }

    public func readMetadata() throws -> DatabaseMetadata? {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode(DatabaseMetadata.self, from: data)
    }

    public func writeMetadata(_ metadata: DatabaseMetadata) throws {
        try ensureDirectoryExists()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL, options: [.atomic])
    }

    public func deleteDownloadedData(fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }
        try fileManager.removeItem(at: directoryURL)
    }
}
