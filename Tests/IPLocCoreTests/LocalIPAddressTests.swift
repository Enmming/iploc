import Testing
@testable import IPLocCore

@Test func localIPSelectorPrefersPrivateIPv4() {
    let selected = LocalIPAddressSelector.bestAddress(from: [
        "fe80::1",
        "10.0.0.8",
        "192.168.0.245"
    ])

    #expect(selected == "10.0.0.8")
}

@Test func localIPSelectorFallsBackToIPv6WhenNoIPv4Exists() {
    let selected = LocalIPAddressSelector.bestAddress(from: [
        "fe80::1",
        "2001:db8::5"
    ])

    #expect(selected == "2001:db8::5")
}

@Test func localIPSelectorIgnoresLoopback() {
    let selected = LocalIPAddressSelector.bestAddress(from: [
        "127.0.0.1",
        "::1",
        "172.16.0.2"
    ])

    #expect(selected == "172.16.0.2")
}
