import Foundation

public struct IPLocation: Equatable, Sendable {
    public let countryCode: String?
    public let countryName: String?
    public let regionName: String?
    public let cityName: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        countryCode: String?,
        countryName: String?,
        regionName: String?,
        cityName: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.regionName = regionName
        self.cityName = cityName
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct IPSnapshot: Equatable, Sendable {
    public let publicIP: String?
    public let localIP: String?
    public let location: IPLocation?
    public let message: String?

    public init(publicIP: String?, localIP: String?, location: IPLocation?, message: String?) {
        self.publicIP = publicIP
        self.localIP = localIP
        self.location = location
        self.message = message
    }
}
