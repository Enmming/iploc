import Foundation

public enum AppMenuCopy {
    public static let unknown = "Unknown"
    public static let databaseNotInstalled = "Database: Not installed"
    public static let refresh = "Refresh"
    public static let updateDatabase = "Update Database"
    public static let downloadDatabase = "Download Database"
    public static let deleteDatabase = "Delete Database..."
    public static let quit = "Quit"

    public static func publicIP(_ value: String?) -> String {
        "Public IP: \(value ?? unknown)"
    }

    public static func location(_ value: String?) -> String {
        "Location: \(value ?? unknown)"
    }

    public static func localIP(_ value: String?) -> String {
        "LAN IP: \(value ?? unknown)"
    }

    public static func lastRefreshed(_ value: Date?, calendar: Calendar = .current) -> String {
        guard let value else {
            return "Last refreshed: Never"
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: value)
        return String(
            format: "Last refreshed: %02d:%02d:%02d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }

    public static func databaseInstalled(release: DBIPDatabaseRelease) -> String {
        String(format: "Database: DB-IP City Lite %04d-%02d", release.year, release.month)
    }

    public static func status(_ value: String) -> String {
        "Status: \(value)"
    }
}
