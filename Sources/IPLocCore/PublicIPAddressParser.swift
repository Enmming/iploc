import Darwin
import Foundation

public enum PublicIPAddressParser {
    public enum ParseError: Error, Equatable {
        case invalidAddress
    }

    public static func parse(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isIPv4(value) || isIPv6(value) else {
            throw ParseError.invalidAddress
        }
        return value
    }

    private static func isIPv4(_ value: String) -> Bool {
        var address = in_addr()
        return value.withCString { inet_pton(AF_INET, $0, &address) } == 1
    }

    private static func isIPv6(_ value: String) -> Bool {
        var address = in6_addr()
        return value.withCString { inet_pton(AF_INET6, $0, &address) } == 1
    }
}
