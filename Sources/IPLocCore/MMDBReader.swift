import Darwin
import Foundation

public enum MMDBReaderError: Error, Equatable {
    case metadataMarkerMissing
    case invalidMetadata
    case unsupportedRecordSize(UInt64)
    case invalidIPAddress(String)
    case dataOutOfBounds
    case invalidData
}

public final class MMDBReader: @unchecked Sendable {
    private let data: Data
    private let metadata: Metadata
    private let searchTreeSize: Int
    private let dataSectionStart: Int

    public init(fileURL: URL) throws {
        self.data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let metadataStart = try Self.findMetadataStart(in: data)
        let decoder = DataDecoder(data: data, baseOffset: metadataStart)
        let metadataValue = try decoder.decode(at: metadataStart).value
        self.metadata = try Metadata(value: metadataValue)
        guard [24, 28, 32].contains(metadata.recordSize) else {
            throw MMDBReaderError.unsupportedRecordSize(metadata.recordSize)
        }
        self.searchTreeSize = Int(((metadata.recordSize * 2) / 8) * metadata.nodeCount)
        self.dataSectionStart = searchTreeSize + 16
    }

    public func lookup(ipAddress: String) throws -> MMDBValue? {
        let bits = try ipBits(for: ipAddress)
        var node: UInt64 = 0

        for bit in bits {
            let record = try readRecord(node: node, branch: bit ? 1 : 0)
            if record < metadata.nodeCount {
                node = record
            } else if record == metadata.nodeCount {
                return nil
            } else {
                let offset = Int(record - metadata.nodeCount) + searchTreeSize
                guard offset >= dataSectionStart else {
                    throw MMDBReaderError.invalidData
                }
                return try DataDecoder(data: data, baseOffset: dataSectionStart).decode(at: offset).value
            }
        }

        return nil
    }

    private static func findMetadataStart(in data: Data) throws -> Int {
        let marker = Data([0xab, 0xcd, 0xef] + Array("MaxMind.com".utf8))
        let searchStart = max(0, data.count - 131_072)
        guard let range = data.range(of: marker, options: [.backwards], in: searchStart..<data.count) else {
            throw MMDBReaderError.metadataMarkerMissing
        }
        return range.upperBound
    }

    private func readRecord(node: UInt64, branch: Int) throws -> UInt64 {
        let nodeOffset = Int(node) * Int((metadata.recordSize * 2) / 8)
        switch metadata.recordSize {
        case 24:
            let offset = nodeOffset + (branch == 0 ? 0 : 3)
            return try readUInt(offset: offset, length: 3)
        case 28:
            try requireRange(nodeOffset, length: 7)
            let bytes = data.bytes(in: nodeOffset, count: 7)
            if branch == 0 {
                return UInt64(bytes[3] >> 4) << 24
                    | UInt64(bytes[0]) << 16
                    | UInt64(bytes[1]) << 8
                    | UInt64(bytes[2])
            }
            return UInt64(bytes[3] & 0x0f) << 24
                | UInt64(bytes[4]) << 16
                | UInt64(bytes[5]) << 8
                | UInt64(bytes[6])
        case 32:
            let offset = nodeOffset + (branch == 0 ? 0 : 4)
            return try readUInt(offset: offset, length: 4)
        default:
            throw MMDBReaderError.unsupportedRecordSize(metadata.recordSize)
        }
    }

    private func ipBits(for ipAddress: String) throws -> [Bool] {
        if var ipv4 = parseIPv4(ipAddress) {
            if metadata.ipVersion == 6 {
                ipv4 = Array(repeating: 0, count: 12) + ipv4
            }
            return ipv4.flatMap { byte in
                (0..<8).map { bitIndex in
                    (byte & (0x80 >> UInt8(bitIndex))) != 0
                }
            }
        }

        if let ipv6 = parseIPv6(ipAddress) {
            return ipv6.flatMap { byte in
                (0..<8).map { bitIndex in
                    (byte & (0x80 >> UInt8(bitIndex))) != 0
                }
            }
        }

        throw MMDBReaderError.invalidIPAddress(ipAddress)
    }

    private func parseIPv4(_ ipAddress: String) -> [UInt8]? {
        var address = in_addr()
        guard ipAddress.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else {
            return nil
        }
        return withUnsafeBytes(of: address) { Array($0) }
    }

    private func parseIPv6(_ ipAddress: String) -> [UInt8]? {
        var address = in6_addr()
        guard ipAddress.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1 else {
            return nil
        }
        return withUnsafeBytes(of: address) { Array($0) }
    }

    private func readUInt(offset: Int, length: Int) throws -> UInt64 {
        try requireRange(offset, length: length)
        return data.bytes(in: offset, count: length).reduce(UInt64(0)) { partial, byte in
            (partial << 8) | UInt64(byte)
        }
    }

    private func requireRange(_ offset: Int, length: Int) throws {
        guard offset >= 0, length >= 0, offset + length <= data.count else {
            throw MMDBReaderError.dataOutOfBounds
        }
    }

    private struct Metadata {
        let nodeCount: UInt64
        let recordSize: UInt64
        let ipVersion: UInt64

        init(value: MMDBValue) throws {
            guard case let .map(map) = value,
                  let nodeCount = map.uint("node_count"),
                  let recordSize = map.uint("record_size"),
                  let ipVersion = map.uint("ip_version")
            else {
                throw MMDBReaderError.invalidMetadata
            }
            self.nodeCount = nodeCount
            self.recordSize = recordSize
            self.ipVersion = ipVersion
        }
    }
}

private final class DataDecoder {
    private let data: Data
    private let baseOffset: Int

    init(data: Data, baseOffset: Int) {
        self.data = data
        self.baseOffset = baseOffset
    }

    func decode(at offset: Int) throws -> (value: MMDBValue, nextOffset: Int) {
        try requireRange(offset, length: 1)
        var cursor = offset
        let control = data[cursor]
        cursor += 1

        var type = Int(control >> 5)
        var size = Int(control & 0x1f)

        if type == 0 {
            try requireRange(cursor, length: 1)
            type = Int(data[cursor]) + 7
            cursor += 1
        }

        if type == 1 {
            let pointer = try readPointer(sizeBits: size, cursor: &cursor)
            let pointedOffset = baseOffset + pointer
            let value = try decode(at: pointedOffset).value
            return (value, cursor)
        }

        size = try readSize(size, cursor: &cursor)

        switch type {
        case 2:
            try requireRange(cursor, length: size)
            let bytes = data[cursor..<(cursor + size)]
            guard let string = String(data: bytes, encoding: .utf8) else {
                throw MMDBReaderError.invalidData
            }
            return (.string(string), cursor + size)
        case 3:
            let bits = try readUInt(offset: cursor, length: 8)
            return (.double(Double(bitPattern: bits)), cursor + 8)
        case 4:
            try requireRange(cursor, length: size)
            return (.bytes(data[cursor..<(cursor + size)]), cursor + size)
        case 5, 6, 9, 10:
            let integer = try readUInt(offset: cursor, length: size)
            return (.uint(integer), cursor + size)
        case 7:
            var map: [String: MMDBValue] = [:]
            for _ in 0..<size {
                let keyResult = try decode(at: cursor)
                guard case let .string(key) = keyResult.value else {
                    throw MMDBReaderError.invalidData
                }
                let valueResult = try decode(at: keyResult.nextOffset)
                map[key] = valueResult.value
                cursor = valueResult.nextOffset
            }
            return (.map(map), cursor)
        case 8:
            let unsigned = try readUInt(offset: cursor, length: size)
            if size == 4 {
                return (.int(Int32(bitPattern: UInt32(unsigned))), cursor + size)
            }
            return (.int(Int32(unsigned)), cursor + size)
        case 11:
            var array: [MMDBValue] = []
            for _ in 0..<size {
                let result = try decode(at: cursor)
                array.append(result.value)
                cursor = result.nextOffset
            }
            return (.array(array), cursor)
        case 14:
            return (.bool(size != 0), cursor)
        case 15:
            let bits = try readUInt(offset: cursor, length: 4)
            return (.float(Float(bitPattern: UInt32(bits))), cursor + 4)
        default:
            throw MMDBReaderError.invalidData
        }
    }

    private func readSize(_ size: Int, cursor: inout Int) throws -> Int {
        switch size {
        case 0..<29:
            return size
        case 29:
            let value = try readUInt(offset: cursor, length: 1)
            cursor += 1
            return 29 + Int(value)
        case 30:
            let value = try readUInt(offset: cursor, length: 2)
            cursor += 2
            return 285 + Int(value)
        case 31:
            let value = try readUInt(offset: cursor, length: 3)
            cursor += 3
            return 65_821 + Int(value)
        default:
            throw MMDBReaderError.invalidData
        }
    }

    private func readPointer(sizeBits: Int, cursor: inout Int) throws -> Int {
        let pointerSize = (sizeBits >> 3) & 0x03
        let valueBits = sizeBits & 0x07

        switch pointerSize {
        case 0:
            let next = try readUInt(offset: cursor, length: 1)
            cursor += 1
            return (valueBits << 8) | Int(next)
        case 1:
            let next = try readUInt(offset: cursor, length: 2)
            cursor += 2
            return ((valueBits << 16) | Int(next)) + 2_048
        case 2:
            let next = try readUInt(offset: cursor, length: 3)
            cursor += 3
            return ((valueBits << 24) | Int(next)) + 526_336
        case 3:
            let next = try readUInt(offset: cursor, length: 4)
            cursor += 4
            return Int(next)
        default:
            throw MMDBReaderError.invalidData
        }
    }

    private func readUInt(offset: Int, length: Int) throws -> UInt64 {
        try requireRange(offset, length: length)
        return data.bytes(in: offset, count: length).reduce(UInt64(0)) { partial, byte in
            (partial << 8) | UInt64(byte)
        }
    }

    private func requireRange(_ offset: Int, length: Int) throws {
        guard offset >= 0, length >= 0, offset + length <= data.count else {
            throw MMDBReaderError.dataOutOfBounds
        }
    }
}

private extension Data {
    func bytes(in offset: Int, count: Int) -> [UInt8] {
        Array(self[offset..<(offset + count)])
    }
}

private extension Dictionary where Key == String, Value == MMDBValue {
    func uint(_ key: String) -> UInt64? {
        switch self[key] {
        case let .uint(value):
            return value
        case let .int(value) where value >= 0:
            return UInt64(value)
        default:
            return nil
        }
    }
}
