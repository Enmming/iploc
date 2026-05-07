import Foundation

public struct PublicIPClient: Sendable {
    public enum ClientError: Error, Equatable {
        case nonHTTPResponse
        case badStatus(Int)
        case invalidBody
        case allEndpointsFailed
    }

    public let endpoints: [URL]

    public init(endpoints: [URL] = [
        URL(string: "https://api.ipify.org")!,
        URL(string: "https://api64.ipify.org")!,
        URL(string: "https://ifconfig.co/ip")!
    ]) {
        self.endpoints = endpoints
    }

    public func fetch() async throws -> String {
        for endpoint in endpoints {
            do {
                var request = URLRequest(url: endpoint)
                request.timeoutInterval = 8
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClientError.nonHTTPResponse
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw ClientError.badStatus(httpResponse.statusCode)
                }
                guard let body = String(data: data, encoding: .utf8) else {
                    throw ClientError.invalidBody
                }
                return try PublicIPAddressParser.parse(body)
            } catch {
                continue
            }
        }

        throw ClientError.allEndpointsFailed
    }
}
