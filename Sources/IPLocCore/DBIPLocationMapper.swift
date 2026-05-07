import Foundation

public enum DBIPLocationMapper {
    public static func location(from value: MMDBValue?) -> IPLocation? {
        guard case let .map(root)? = value else {
            return nil
        }

        let country = root.mapValue("country")
        let city = root.mapValue("city")
        let location = root.mapValue("location")
        let subdivisions = root.arrayValue("subdivisions")
        let firstSubdivision = subdivisions?.first?.map

        return IPLocation(
            countryCode: country?.stringValue("iso_code"),
            countryName: localizedName(in: country?.mapValue("names")),
            regionName: localizedName(in: firstSubdivision?["names"]?.map),
            cityName: localizedName(in: city?.mapValue("names")),
            latitude: location?.doubleValue("latitude"),
            longitude: location?.doubleValue("longitude")
        )
    }

    private static func localizedName(in names: [String: MMDBValue]?) -> String? {
        guard let names else {
            return nil
        }
        for key in ["en"] {
            if case let .string(value)? = names[key], !value.isEmpty {
                return value
            }
        }
        return names.values.compactMap { value in
            if case let .string(string) = value, !string.isEmpty {
                return string
            }
            return nil
        }.first
    }
}

private extension MMDBValue {
    var map: [String: MMDBValue]? {
        if case let .map(value) = self {
            return value
        }
        return nil
    }
}

private extension Dictionary where Key == String, Value == MMDBValue {
    func mapValue(_ key: String) -> [String: MMDBValue]? {
        guard case let .map(map)? = self[key] else {
            return nil
        }
        return map
    }

    func arrayValue(_ key: String) -> [MMDBValue]? {
        guard case let .array(array)? = self[key] else {
            return nil
        }
        return array
    }

    func stringValue(_ key: String) -> String? {
        guard case let .string(string)? = self[key] else {
            return nil
        }
        return string
    }

    func doubleValue(_ key: String) -> Double? {
        switch self[key] {
        case let .double(value):
            return value
        case let .float(value):
            return Double(value)
        case let .uint(value):
            return Double(value)
        case let .int(value):
            return Double(value)
        default:
            return nil
        }
    }
}
