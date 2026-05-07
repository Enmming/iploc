import Foundation
import Testing
@testable import IPLocCore

@Test func dbipDownloadCandidatesStartWithCurrentMonth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 7).date!

    let candidates = DBIPDatabaseRelease.candidates(now: now, calendar: calendar, count: 3)

    #expect(candidates.map(\.fileName) == [
        "dbip-city-lite-2026-05.mmdb.gz",
        "dbip-city-lite-2026-04.mmdb.gz",
        "dbip-city-lite-2026-03.mmdb.gz"
    ])
    #expect(candidates[0].url.absoluteString == "https://download.db-ip.com/free/dbip-city-lite-2026-05.mmdb.gz")
}

@Test func statusBarTitleShowsCountryCode() {
    let snapshot = IPSnapshot(
        publicIP: "173.44.178.162",
        localIP: "192.168.0.245",
        location: IPLocation(
            countryCode: "US",
            countryName: "United States",
            regionName: "Virginia",
            cityName: "Ashburn",
            latitude: 39.0438,
            longitude: -77.4874
        ),
        message: nil
    )

    #expect(StatusFormatter.statusBarTitle(for: snapshot, isBusy: false, spinnerFrame: "x") == "US")
}

@Test func statusBarTitleShowsLoadingWhenBusy() {
    let snapshot = IPSnapshot(
        publicIP: "173.44.178.162",
        localIP: nil,
        location: IPLocation(
            countryCode: "US",
            countryName: "United States",
            regionName: nil,
            cityName: nil,
            latitude: nil,
            longitude: nil
        ),
        message: nil
    )

    #expect(StatusFormatter.statusBarTitle(for: snapshot, isBusy: true, spinnerFrame: "⠋") == "Loading")
}

@Test func statusBarTitleFallsBackWhenCountryIsMissing() {
    let snapshot = IPSnapshot(publicIP: nil, localIP: nil, location: nil, message: "Database required")

    #expect(StatusFormatter.statusBarTitle(for: snapshot, isBusy: false, spinnerFrame: "x") == "IP")
}
