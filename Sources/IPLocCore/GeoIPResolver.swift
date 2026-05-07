import Foundation

public final class GeoIPResolver: @unchecked Sendable {
    private let reader: MMDBReader

    public init(databaseURL: URL) throws {
        self.reader = try MMDBReader(fileURL: databaseURL)
    }

    public func location(for ipAddress: String) throws -> IPLocation? {
        try DBIPLocationMapper.location(from: reader.lookup(ipAddress: ipAddress))
    }
}
