import Foundation
import Testing
@testable import IPLocCore

@Test func dbipMMDBLookupFindsCheckedPublicIPWhenFixtureIsPresent() throws {
    let fixture = URL(fileURLWithPath: ".tmp/dbip-check/dbip-city-lite-2026-05.mmdb")
    guard FileManager.default.fileExists(atPath: fixture.path) else {
        return
    }

    let reader = try MMDBReader(fileURL: fixture)
    let value = try reader.lookup(ipAddress: "173.44.178.162")
    let location = DBIPLocationMapper.location(from: value)

    #expect(location?.countryCode == "US")
    #expect(location?.countryName == "United States")
    #expect(location?.regionName == "Virginia")
    #expect(location?.cityName == "Ashburn")
}
