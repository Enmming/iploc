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

    public static func databaseInstalled(release: DBIPDatabaseRelease) -> String {
        String(format: "Database: DB-IP City Lite %04d-%02d", release.year, release.month)
    }

    public static func status(_ value: String) -> String {
        "Status: \(value)"
    }
}
