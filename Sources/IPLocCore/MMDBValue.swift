import Foundation

public enum MMDBValue: Equatable, Sendable {
    case map([String: MMDBValue])
    case array([MMDBValue])
    case string(String)
    case double(Double)
    case bytes(Data)
    case uint(UInt64)
    case int(Int32)
    case bool(Bool)
    case float(Float)
    case null
}
