import XCTest
@testable import NetRatio

@MainActor
final class NetworkBandwidthMonitorTests: XCTestCase {

    func testAggregateModeSumsPositiveDeltasAcrossInterfaces() {
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
                        "en0": .init(receivedBytes: 160, sentBytes: 65),
                        "en1": .init(receivedBytes: 260, sentBytes: 95),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(names: [:]),
            startImmediately: false
        )

        monitor.refreshNow()
        monitor.refreshNow()

        XCTAssertEqual(monitor.downloadRate, 120)
        XCTAssertEqual(monitor.uploadRate, 40)
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
            metadataProvider: StubInterfaceMetadataProvider(names: [:]),
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
            metadataProvider: StubInterfaceMetadataProvider(names: [:]),
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
                names: [
                    "en0": "Wi-Fi",
                    "en1": "USB LAN",
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

    func testInterfaceOptionsFallbackToBSDNameWhenDisplayNameMissing() {
        let source = StubNetworkSnapshotSource(
            snapshots: [
                makeSnapshot(
                    second: 0,
                    counters: [
                        "en1": .init(receivedBytes: 200, sentBytes: 80),
                        "en0": .init(receivedBytes: 100, sentBytes: 40),
                    ]
                ),
            ]
        )

        let monitor = NetworkBandwidthMonitor(
            snapshotSource: source,
            metadataProvider: StubInterfaceMetadataProvider(
                names: [
                    "en1": "USB LAN",
                ]
            ),
            startImmediately: false
        )

        monitor.refreshNow()

        XCTAssertEqual(
            monitor.interfaceOptions.map(\.pickerLabel),
            [
                "en0",
                "USB LAN (en1)",
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
    let names: [String: String]

    func displayNamesByBSDName() -> [String: String] {
        names
    }
}
