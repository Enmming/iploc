import Foundation
import Testing
@testable import IPLocCore

@Test func refreshPolicyRunsLaunchAndNetworkChangeImmediately() {
    let policy = RefreshPolicy(timerInterval: 60, networkDebounceInterval: 2)
    let base = Date(timeIntervalSince1970: 100)

    #expect(policy.shouldRefresh(trigger: .launch, now: base, lastRefreshAt: nil, lastNetworkRefreshAt: nil))
    #expect(policy.shouldRefresh(trigger: .networkChange, now: base, lastRefreshAt: base, lastNetworkRefreshAt: nil))
}

@Test func refreshPolicyDebouncesRepeatedNetworkChanges() {
    let policy = RefreshPolicy(timerInterval: 60, networkDebounceInterval: 2)
    let base = Date(timeIntervalSince1970: 100)

    #expect(policy.shouldRefresh(
        trigger: .networkChange,
        now: base.addingTimeInterval(1),
        lastRefreshAt: base,
        lastNetworkRefreshAt: base
    ) == false)

    #expect(policy.shouldRefresh(
        trigger: .networkChange,
        now: base.addingTimeInterval(3),
        lastRefreshAt: base,
        lastNetworkRefreshAt: base
    ))
}

@Test func refreshPolicyRunsTimerOnlyAfterInterval() {
    let policy = RefreshPolicy(timerInterval: 60, networkDebounceInterval: 2)
    let base = Date(timeIntervalSince1970: 100)

    #expect(policy.shouldRefresh(trigger: .timer, now: base.addingTimeInterval(59), lastRefreshAt: base, lastNetworkRefreshAt: nil) == false)
    #expect(policy.shouldRefresh(trigger: .timer, now: base.addingTimeInterval(60), lastRefreshAt: base, lastNetworkRefreshAt: nil))
}
