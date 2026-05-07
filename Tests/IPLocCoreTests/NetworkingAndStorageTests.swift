import Foundation
import Testing
@testable import IPLocCore

@Test func publicIPParserTrimsAndValidatesIPv4AndIPv6() throws {
    #expect(try PublicIPAddressParser.parse(" 173.44.178.162\n") == "173.44.178.162")
    #expect(try PublicIPAddressParser.parse(" 2001:db8::1\n") == "2001:db8::1")
    #expect(throws: PublicIPAddressParser.ParseError.invalidAddress) {
        try PublicIPAddressParser.parse("not an ip")
    }
}

@Test func databaseStoreUsesApplicationSupportDirectory() {
    let base = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)
    let store = DatabaseStore(applicationSupportDirectory: base)

    #expect(store.directoryURL.path == "/tmp/Application Support/IPLoc")
    #expect(store.activeDatabaseURL.lastPathComponent == "dbip-city-lite.mmdb")
    #expect(store.metadataURL.lastPathComponent == "dbip-city-lite.json")
}

@Test func databaseMetadataRoundTrips() throws {
    let metadata = DatabaseMetadata(
        release: DBIPDatabaseRelease(year: 2026, month: 5),
        installedAt: Date(timeIntervalSince1970: 1_777_600_697),
        sourceURL: URL(string: "https://download.db-ip.com/free/dbip-city-lite-2026-05.mmdb.gz")!
    )

    let data = try JSONEncoder().encode(metadata)
    let decoded = try JSONDecoder().decode(DatabaseMetadata.self, from: data)

    #expect(decoded == metadata)
}

@Test func databaseStoreDeletesDownloadedDataDirectory() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("IPLocTests-\(UUID().uuidString)", isDirectory: true)
    let store = DatabaseStore(applicationSupportDirectory: base)
    try store.ensureDirectoryExists()
    try Data("db".utf8).write(to: store.activeDatabaseURL)
    try Data("{}".utf8).write(to: store.metadataURL)

    try store.deleteDownloadedData()

    #expect(!FileManager.default.fileExists(atPath: store.directoryURL.path))
    try? FileManager.default.removeItem(at: base)
}
