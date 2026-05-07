import Darwin
import Foundation

public enum LocalIPAddressSelector {
    public static func bestAddress(from addresses: [String]) -> String? {
        let usable = addresses.filter { !isLoopback($0) && !isLinkLocal($0) }

        if let privateIPv4 = usable.first(where: isPrivateIPv4) {
            return privateIPv4
        }

        if let anyIPv4 = usable.first(where: isIPv4) {
            return anyIPv4
        }

        return usable.first(where: isIPv6)
    }

    private static func isLoopback(_ address: String) -> Bool {
        address == "127.0.0.1" || address == "::1" || address.hasPrefix("127.")
    }

    private static func isLinkLocal(_ address: String) -> Bool {
        address.lowercased().hasPrefix("fe80:")
    }

    private static func isPrivateIPv4(_ address: String) -> Bool {
        guard let parts = ipv4Parts(address) else {
            return false
        }
        if parts[0] == 10 {
            return true
        }
        if parts[0] == 172, (16...31).contains(parts[1]) {
            return true
        }
        if parts[0] == 192, parts[1] == 168 {
            return true
        }
        return false
    }

    private static func isIPv4(_ address: String) -> Bool {
        ipv4Parts(address) != nil
    }

    private static func isIPv6(_ address: String) -> Bool {
        var storage = in6_addr()
        return address.withCString { inet_pton(AF_INET6, $0, &storage) } == 1
    }

    private static func ipv4Parts(_ address: String) -> [UInt8]? {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else {
            return nil
        }
        return parts.map(String.init).map(UInt8.init).reduce(into: [UInt8]()) { result, value in
            if let value {
                result.append(value)
            }
        }.count == 4 ? parts.compactMap { UInt8($0) } : nil
    }
}

public enum LocalIPAddressProvider {
    public static func current() -> String? {
        bestAddress(from: allAddresses())
    }

    public static func bestAddress(from addresses: [String]) -> String? {
        LocalIPAddressSelector.bestAddress(from: addresses)
    }

    public static func allAddresses() -> [String] {
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let firstInterface = interfacePointer else {
            return []
        }
        defer { freeifaddrs(interfacePointer) }

        var addresses: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else {
                continue
            }
            guard let address = current.pointee.ifa_addr else {
                continue
            }

            let family = address.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else {
                continue
            }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = family == UInt8(AF_INET) ? socklen_t(MemoryLayout<sockaddr_in>.size) : socklen_t(MemoryLayout<sockaddr_in6>.size)
            let result = getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            guard result == 0 else {
                continue
            }

            let value = host.withUnsafeBufferPointer { buffer in
                String(cString: buffer.baseAddress!)
            }.components(separatedBy: "%").first ?? ""
            if !value.isEmpty {
                addresses.append(value)
            }
        }

        return addresses
    }
}
