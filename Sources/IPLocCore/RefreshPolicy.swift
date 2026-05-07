import Foundation

public enum RefreshTrigger: Sendable {
    case launch
    case networkChange
    case timer
    case manual
}

public struct RefreshPolicy: Sendable {
    public let timerInterval: TimeInterval
    public let networkDebounceInterval: TimeInterval

    public init(timerInterval: TimeInterval, networkDebounceInterval: TimeInterval) {
        self.timerInterval = timerInterval
        self.networkDebounceInterval = networkDebounceInterval
    }

    public func shouldRefresh(
        trigger: RefreshTrigger,
        now: Date,
        lastRefreshAt: Date?,
        lastNetworkRefreshAt: Date?
    ) -> Bool {
        switch trigger {
        case .launch, .manual:
            return true
        case .networkChange:
            guard let lastNetworkRefreshAt else {
                return true
            }
            return now.timeIntervalSince(lastNetworkRefreshAt) >= networkDebounceInterval
        case .timer:
            guard let lastRefreshAt else {
                return true
            }
            return now.timeIntervalSince(lastRefreshAt) >= timerInterval
        }
    }
}
