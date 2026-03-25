import XCTest
@testable import NetRatio

@MainActor
final class NetworkBandwidthMonitorTests: XCTestCase {

    func testAggregateModeUsesOnlyConfiguredServicesAndServiceOrder() {
        let source = StubNetworkSnapshotSource(
            snapshots: [
                makeSnapshot(
                    second: 0,
                    counters: [
                        "awdl0": .init(receivedBytes: 500, sentBytes: 200),
                        "en0": .init(receivedBytes: 100, sentBytes: 40),
                        "en1": .init(receivedBytes: 200, sentBytes: 80),
                    ]
                ),
                makeSnapshot(
                    second: 1,
                    counters: [
                        "awdl0": .init(receivedBytes: 650, sentBytes: 260),
                        "en0": .init(receivedBytes: 160, sentBytes: 65),
                        "en1": .init(receivedBytes: 260, sentBytes: 95),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(
                services: [
                    .init(bsdName: "en1", displayName: "USB LAN"),
                    .init(bsdName: "en0", displayName: "Wi-Fi"),
                ]
            ),
            startImmediately: false
        )

        monitor.refreshNow()
        monitor.refreshNow()

        XCTAssertEqual(monitor.downloadRate, 120)
        XCTAssertEqual(monitor.uploadRate, 40)
        XCTAssertEqual(
            monitor.interfaceOptions.map(\.pickerLabel),
            [
                "USB LAN (en1)",
                "Wi-Fi (en0)",
            ]
        )
    }

    func testInterfaceSelectionUsesOnlyChosenInterface() {
        let source = StubNetworkSnapshotSource(
            snapshots: [
                makeSnapshot(
                    second: 0,
                    counters: [
                        "en0": .init(receivedBytes: 100, sentBytes: 40),
                        "en1": .init(receivedBytes: 200, sentBytes: 80),
                    ]
                ),
                makeSnapshot(
                    second: 1,
                    counters: [
                        "en0": .init(receivedBytes: 180, sentBytes: 70),
                        "en1": .init(receivedBytes: 260, sentBytes: 95),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(
                services: [
                    .init(bsdName: "en0", displayName: "Wi-Fi"),
                    .init(bsdName: "en1", displayName: "USB LAN"),
                ]
            ),
            startImmediately: false
        )

        monitor.selectInterface(.interface("en1"))
        monitor.refreshNow()
        monitor.refreshNow()

        XCTAssertEqual(monitor.downloadRate, 60)
        XCTAssertEqual(monitor.uploadRate, 15)
    }

    func testSelectionChangeResetsBaselineBeforeReportingRates() {
        let source = StubNetworkSnapshotSource(
            snapshots: [
                makeSnapshot(
                    second: 0,
                    counters: [
                        "en0": .init(receivedBytes: 100, sentBytes: 40),
                        "en1": .init(receivedBytes: 200, sentBytes: 80),
                    ]
                ),
                makeSnapshot(
                    second: 1,
                    counters: [
                        "en0": .init(receivedBytes: 180, sentBytes: 70),
                        "en1": .init(receivedBytes: 260, sentBytes: 95),
                    ]
                ),
                makeSnapshot(
                    second: 2,
                    counters: [
                        "en0": .init(receivedBytes: 220, sentBytes: 90),
                        "en1": .init(receivedBytes: 320, sentBytes: 110),
                    ]
                ),
                makeSnapshot(
                    second: 3,
                    counters: [
                        "en0": .init(receivedBytes: 260, sentBytes: 110),
                        "en1": .init(receivedBytes: 390, sentBytes: 140),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(
                services: [
                    .init(bsdName: "en0", displayName: "Wi-Fi"),
                    .init(bsdName: "en1", displayName: "USB LAN"),
                ]
            ),
            startImmediately: false
        )

        monitor.refreshNow()
        monitor.refreshNow()
        XCTAssertEqual(monitor.downloadRate, 140)
        XCTAssertEqual(monitor.uploadRate, 45)

        monitor.selectInterface(.interface("en1"))
        XCTAssertEqual(monitor.downloadRate, 0)
        XCTAssertEqual(monitor.uploadRate, 0)

        monitor.refreshNow()
        XCTAssertEqual(monitor.downloadRate, 0)
        XCTAssertEqual(monitor.uploadRate, 0)

        monitor.refreshNow()
        XCTAssertEqual(monitor.downloadRate, 70)
        XCTAssertEqual(monitor.uploadRate, 30)
    }

    func testUnavailableSelectionStaysVisibleAndReportsZero() {
        let source = StubNetworkSnapshotSource(
            snapshots: [
                makeSnapshot(
                    second: 0,
                    counters: [
                        "en0": .init(receivedBytes: 100, sentBytes: 40),
                        "en1": .init(receivedBytes: 200, sentBytes: 80),
                    ]
                ),
                makeSnapshot(
                    second: 1,
                    counters: [
                        "en0": .init(receivedBytes: 150, sentBytes: 60),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(
                services: [
                    .init(bsdName: "en0", displayName: "Wi-Fi"),
                    .init(bsdName: "en1", displayName: "USB LAN"),
                ]
            ),
            startImmediately: false
        )

        monitor.selectInterface(.interface("en1"))
        monitor.refreshNow()
        monitor.refreshNow()

        XCTAssertEqual(monitor.downloadRate, 0)
        XCTAssertEqual(monitor.uploadRate, 0)
        XCTAssertEqual(
            monitor.interfaceOptions,
            [
                NetworkInterfaceOption(
                    bsdName: "en0",
                    displayName: "Wi-Fi",
                    isAvailable: true
                ),
                NetworkInterfaceOption(
                    bsdName: "en1",
                    displayName: "USB LAN",
                    isAvailable: false
                ),
            ]
        )
        XCTAssertEqual(
            monitor.interfaceOptions.last?.pickerLabel,
            "USB LAN (en1) (Unavailable)"
        )
    }

    func testServiceNamesFallbackToBSDWithoutDuplicateSuffix() {
        let source = StubNetworkSnapshotSource(
            snapshots: [
                makeSnapshot(
                    second: 0,
                    counters: [
                        "en0": .init(receivedBytes: 100, sentBytes: 40),
                        "en1": .init(receivedBytes: 200, sentBytes: 80),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(
                services: [
                    .init(bsdName: "en1", displayName: "USB LAN"),
                    .init(bsdName: "en0", displayName: "en0"),
                ]
            ),
            startImmediately: false
        )

        monitor.refreshNow()

        XCTAssertEqual(
            monitor.interfaceOptions.map(\.pickerLabel),
            [
                "USB LAN (en1)",
                "en0",
            ]
        )
    }

    private func makeSnapshot(
        second: TimeInterval,
        counters: [String: NetworkInterfaceCounters]
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: Date(timeIntervalSince1970: second),
            countersByInterface: counters
        )
    }
}

private final class StubNetworkSnapshotSource: NetworkSnapshotSource {
    private let snapshots: [NetworkSnapshot]
    private var index = 0

    init(snapshots: [NetworkSnapshot]) {
        self.snapshots = snapshots
    }

    func currentSnapshot() -> NetworkSnapshot? {
        guard index < snapshots.count else {
            return snapshots.last
        }

        let snapshot = snapshots[index]
        index += 1
        return snapshot
    }
}

private struct StubInterfaceMetadataProvider: NetworkInterfaceMetadataProviding {
    let services: [ConfiguredNetworkService]

    func configuredServices() -> [ConfiguredNetworkService] {
        services
    }
}
