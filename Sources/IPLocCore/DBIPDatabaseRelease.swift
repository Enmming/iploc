import Foundation

public struct DBIPDatabaseRelease: Codable, Equatable, Sendable {
    public let year: Int
    public let month: Int

    public var fileName: String {
        String(format: "dbip-city-lite-%04d-%02d.mmdb.gz", year, month)
    }

    public var decompressedFileName: String {
        String(format: "dbip-city-lite-%04d-%02d.mmdb", year, month)
    }

    public var url: URL {
        URL(string: "https://download.db-ip.com/free/\(fileName)")!
    }

    public static func candidates(now: Date, calendar inputCalendar: Calendar = .current, count: Int = 3) -> [DBIPDatabaseRelease] {
        let calendar = inputCalendar

        let components = calendar.dateComponents([.year, .month], from: now)
        guard let monthStart = calendar.date(from: components) else {
            return []
        }

        return (0..<max(0, count)).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: monthStart) else {
                return nil
            }
            let parts = calendar.dateComponents([.year, .month], from: date)
            guard let year = parts.year, let month = parts.month else {
                return nil
            }
            return DBIPDatabaseRelease(year: year, month: month)
        }
    }
}
