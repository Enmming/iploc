import Foundation

public enum DBIPUpdateEvent: Sendable, Equatable {
    case trying(DBIPDatabaseRelease)
    case downloading(DBIPDatabaseRelease)
    case decompressing(DBIPDatabaseRelease)
    case installing(DBIPDatabaseRelease)
    case finished(DatabaseMetadata)
}

public enum DBIPUpdateError: Error, Equatable {
    case nonHTTPResponse
    case badStatus(Int)
    case noDownloadableRelease
    case gunzipFailed(Int32)
    case decompressedFileMissing
}

public struct DBIPDatabaseUpdater: Sendable {
    public let store: DatabaseStore
    public let candidateCount: Int

    public init(store: DatabaseStore, candidateCount: Int = 3) {
        self.store = store
        self.candidateCount = candidateCount
    }

    public func update(
        now: Date = Date(),
        calendar: Calendar = .current,
        eventHandler: (@Sendable (DBIPUpdateEvent) async -> Void)? = nil
    ) async throws -> DatabaseMetadata {
        try store.ensureDirectoryExists()
        let candidates = DBIPDatabaseRelease.candidates(now: now, calendar: calendar, count: candidateCount)
        var lastError: Error?

        for release in candidates {
            do {
                if let eventHandler {
                    await eventHandler(.trying(release))
                    await eventHandler(.downloading(release))
                }
                let downloadedArchive = try await download(release: release)
                if let eventHandler {
                    await eventHandler(.decompressing(release))
                }
                let decompressed = try decompress(gzipURL: downloadedArchive.archiveURL, release: release, temporaryDirectory: downloadedArchive.temporaryDirectory)
                _ = try MMDBReader(fileURL: decompressed)
                if let eventHandler {
                    await eventHandler(.installing(release))
                }
                let metadata = try install(decompressedDatabaseURL: decompressed, release: release)
                try? FileManager.default.removeItem(at: downloadedArchive.temporaryDirectory)
                if let eventHandler {
                    await eventHandler(.finished(metadata))
                }
                return metadata
            } catch DBIPUpdateError.badStatus(404) {
                lastError = DBIPUpdateError.badStatus(404)
                continue
            } catch {
                lastError = error
                continue
            }
        }

        if let lastError {
            throw lastError
        }
        throw DBIPUpdateError.noDownloadableRelease
    }

    private func download(release: DBIPDatabaseRelease) async throws -> DownloadedArchive {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IPLoc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let (temporaryURL, response) = try await URLSession.shared.download(from: release.url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DBIPUpdateError.nonHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DBIPUpdateError.badStatus(httpResponse.statusCode)
        }

        let archiveURL = temporaryDirectory.appendingPathComponent(release.fileName)
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
        return DownloadedArchive(temporaryDirectory: temporaryDirectory, archiveURL: archiveURL)
    }

    private func decompress(gzipURL: URL, release: DBIPDatabaseRelease, temporaryDirectory: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-kf", gzipURL.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DBIPUpdateError.gunzipFailed(process.terminationStatus)
        }

        let decompressedURL = temporaryDirectory.appendingPathComponent(release.decompressedFileName)
        guard FileManager.default.fileExists(atPath: decompressedURL.path) else {
            throw DBIPUpdateError.decompressedFileMissing
        }
        return decompressedURL
    }

    private func install(decompressedDatabaseURL: URL, release: DBIPDatabaseRelease) throws -> DatabaseMetadata {
        let replacementURL = store.directoryURL.appendingPathComponent("dbip-city-lite-\(UUID().uuidString).mmdb")
        try FileManager.default.moveItem(at: decompressedDatabaseURL, to: replacementURL)

        if FileManager.default.fileExists(atPath: store.activeDatabaseURL.path) {
            _ = try FileManager.default.replaceItemAt(
                store.activeDatabaseURL,
                withItemAt: replacementURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try FileManager.default.moveItem(at: replacementURL, to: store.activeDatabaseURL)
        }

        let metadata = DatabaseMetadata(release: release, installedAt: Date(), sourceURL: release.url)
        try store.writeMetadata(metadata)
        return metadata
    }

    private struct DownloadedArchive {
        let temporaryDirectory: URL
        let archiveURL: URL
    }
}
