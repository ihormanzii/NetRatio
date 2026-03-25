//
//  NetworkBandwidthMonitor.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//

import Darwin
import Foundation
import Observation
import SystemConfiguration

@MainActor
@Observable
final class NetworkBandwidthMonitor {

    private let updateInterval: Duration
    private let snapshotSource: any NetworkSnapshotSource
    private let metadataProvider: any NetworkInterfaceMetadataProviding
    private var previousSnapshot: NetworkSnapshot?
    private var refreshTask: Task<Void, Never>?

    var selectedInterface: NetworkInterfaceSelection = .all
    var interfaceOptions: [NetworkInterfaceOption] = []
    var downloadRate: Double = 0
    var uploadRate: Double = 0

    var downloadRateDescription: String {
        formattedRate(downloadRate)
    }

    var uploadRateDescription: String {
        formattedRate(uploadRate)
    }

    var downloadRateCompact: String {
        formattedCompactRate(downloadRate)
    }

    var uploadRateCompact: String {
        formattedCompactRate(uploadRate)
    }

    init(
        updateInterval: Duration = .seconds(1),
        snapshotSource: (any NetworkSnapshotSource)? = nil,
        metadataProvider: (any NetworkInterfaceMetadataProviding)? = nil,
        startImmediately: Bool = true
    ) {
        self.updateInterval = updateInterval
        self.snapshotSource = snapshotSource ?? LiveNetworkSnapshotSource()
        self.metadataProvider =
            metadataProvider ?? LiveNetworkInterfaceMetadataProvider()

        if startImmediately {
            refreshTask = Task { @MainActor [weak self, updateInterval] in
                self?.refreshSample()

                while !Task.isCancelled {
                    try? await Task.sleep(for: updateInterval)
                    guard let self else {
                        return
                    }

                    self.refreshSample()
                }
            }
        }
    }

    func selectInterface(_ selection: NetworkInterfaceSelection) {
        guard selection != selectedInterface else {
            return
        }

        let activeInterfaceNames = previousSnapshot?.sortedInterfaceNames ?? []

        selectedInterface = selection
        previousSnapshot = nil
        downloadRate = 0
        uploadRate = 0
        interfaceOptions = buildInterfaceOptions(
            activeInterfaceNames: activeInterfaceNames,
            configuredServices: metadataProvider.configuredServices()
        )
    }

    func refreshNow() {
        refreshSample()
    }

    private func refreshSample() {
        guard let snapshot = snapshotSource.currentSnapshot() else {
            return
        }

        let configuredServices = metadataProvider.configuredServices()
        let configuredInterfaceNames = Set(configuredServices.map(\.bsdName))
        let filteredSnapshot = snapshot.filtered(to: configuredInterfaceNames)

        interfaceOptions = buildInterfaceOptions(
            activeInterfaceNames: filteredSnapshot.sortedInterfaceNames,
            configuredServices: configuredServices
        )

        defer {
            previousSnapshot = filteredSnapshot
        }

        guard let previousSnapshot else {
            downloadRate = 0
            uploadRate = 0
            return
        }

        let elapsed = filteredSnapshot.timestamp.timeIntervalSince(
            previousSnapshot.timestamp
        )
        guard elapsed > 0 else {
            return
        }

        let counters = filteredSnapshot.delta(
            since: previousSnapshot,
            selection: selectedInterface
        )

        downloadRate = Double(counters.receivedBytes) / elapsed
        uploadRate = Double(counters.sentBytes) / elapsed
    }

    private func formattedRate(_ bytesPerSecond: Double) -> String {
        let bytes = Int64(bytesPerSecond.rounded())
        return
            "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary))/s"
    }

    private func formattedCompactRate(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false

        let bytes = max(Int64(bytesPerSecond.rounded()), 0)

        if bytes < 1024 {
            return "0K"
        }

        return formatter.string(fromByteCount: bytes).replacingOccurrences(
            of: " ",
            with: ""
        )
    }

    private func buildInterfaceOptions(
        activeInterfaceNames: [String],
        configuredServices: [ConfiguredNetworkService]
    ) -> [NetworkInterfaceOption] {
        let activeSet = Set(activeInterfaceNames)

        let activeOptions: [NetworkInterfaceOption] = configuredServices.compactMap {
            service -> NetworkInterfaceOption? in
            guard activeSet.contains(service.bsdName) else {
                return nil
            }

            return NetworkInterfaceOption(
                bsdName: service.bsdName,
                displayName: service.displayName,
                isAvailable: true
            )
        }

        guard case let .interface(bsdName) = selectedInterface,
            activeSet.contains(bsdName) == false
        else {
            return activeOptions
        }

        let staleDisplayName = configuredServices.first {
            $0.bsdName == bsdName
        }?.displayName

        return activeOptions + [
            NetworkInterfaceOption(
                bsdName: bsdName,
                displayName: staleDisplayName,
                isAvailable: false
            )
        ]
    }
}

struct ConfiguredNetworkService: Equatable {
    let bsdName: String
    let displayName: String
}

enum NetworkInterfaceSelection: Hashable {
    case all
    case interface(String)
}

struct NetworkInterfaceOption: Equatable, Identifiable {
    let bsdName: String
    let displayName: String?
    let isAvailable: Bool

    var id: String {
        bsdName
    }

    var label: String {
        guard let displayName else {
            return bsdName
        }

        if displayName == bsdName || displayName.contains("(\(bsdName))") {
            return displayName
        }

        return "\(displayName) (\(bsdName))"
    }

    var pickerLabel: String {
        guard isAvailable == false else {
            return label
        }

        return "\(label) (Unavailable)"
    }
}

protocol NetworkSnapshotSource {
    func currentSnapshot() -> NetworkSnapshot?
}

protocol NetworkInterfaceMetadataProviding {
    func configuredServices() -> [ConfiguredNetworkService]
}

struct NetworkSnapshot: Equatable {

    let timestamp: Date
    let countersByInterface: [String: NetworkInterfaceCounters]

    var sortedInterfaceNames: [String] {
        countersByInterface.keys.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    func filtered(to allowedInterfaceNames: Set<String>) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            countersByInterface: countersByInterface.filter { key, _ in
                allowedInterfaceNames.contains(key)
            }
        )
    }

    func delta(
        since previousSnapshot: NetworkSnapshot,
        selection: NetworkInterfaceSelection
    ) -> NetworkInterfaceCounters {
        switch selection {
        case .all:
            let interfaceNames = Set(countersByInterface.keys)
                .union(previousSnapshot.countersByInterface.keys)

            return interfaceNames.reduce(.zero) { partialResult, bsdName in
                partialResult + countersByInterface[bsdName].delta(
                    since: previousSnapshot.countersByInterface[bsdName]
                )
            }
        case let .interface(bsdName):
            return countersByInterface[bsdName].delta(
                since: previousSnapshot.countersByInterface[bsdName]
            )
        }
    }
}

struct NetworkInterfaceCounters: Equatable {
    let receivedBytes: UInt64
    let sentBytes: UInt64

    static let zero = NetworkInterfaceCounters(receivedBytes: 0, sentBytes: 0)

    static func + (
        lhs: NetworkInterfaceCounters,
        rhs: NetworkInterfaceCounters
    ) -> NetworkInterfaceCounters {
        NetworkInterfaceCounters(
            receivedBytes: lhs.receivedBytes + rhs.receivedBytes,
            sentBytes: lhs.sentBytes + rhs.sentBytes
        )
    }
}

private extension Optional where Wrapped == NetworkInterfaceCounters {
    func delta(
        since previousCounters: NetworkInterfaceCounters?
    ) -> NetworkInterfaceCounters {
        guard let currentCounters = self,
            let previousCounters,
            currentCounters.receivedBytes >= previousCounters.receivedBytes,
            currentCounters.sentBytes >= previousCounters.sentBytes
        else {
            return .zero
        }

        return NetworkInterfaceCounters(
            receivedBytes: currentCounters.receivedBytes
                - previousCounters.receivedBytes,
            sentBytes: currentCounters.sentBytes - previousCounters.sentBytes
        )
    }
}

struct LiveNetworkSnapshotSource: NetworkSnapshotSource {

    static func current() -> NetworkSnapshot? {
        LiveNetworkSnapshotSource().currentSnapshot()
    }

    func currentSnapshot() -> NetworkSnapshot? {
        var interfaceAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddress) == 0,
            let firstAddress = interfaceAddress
        else {
            return nil
        }

        defer {
            freeifaddrs(interfaceAddress)
        }

        var countersByInterface: [String: NetworkInterfaceCounters] = [:]

        for pointer in sequence(
            first: firstAddress,
            next: { $0.pointee.ifa_next }
        ) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)

            guard
                let address = interface.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                (flags & IFF_UP) != 0,
                (flags & IFF_LOOPBACK) == 0,
                let data = interface.ifa_data
            else {
                continue
            }

            let bsdName = String(cString: interface.ifa_name)
            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            countersByInterface[bsdName] = NetworkInterfaceCounters(
                receivedBytes: UInt64(networkData.ifi_ibytes),
                sentBytes: UInt64(networkData.ifi_obytes)
            )
        }

        return NetworkSnapshot(
            timestamp: Date(),
            countersByInterface: countersByInterface
        )
    }
}

struct LiveNetworkInterfaceMetadataProvider: NetworkInterfaceMetadataProviding {
    func configuredServices() -> [ConfiguredNetworkService] {
        guard
            let preferences = SCPreferencesCreate(
                nil,
                "NetRatio" as CFString,
                nil
            ),
            let currentSet = SCNetworkSetCopyCurrent(preferences),
            let services = SCNetworkSetCopyServices(currentSet) as? [SCNetworkService]
        else {
            return []
        }

        var seenBSDNames = Set<String>()

        return services.compactMap { service in
            guard SCNetworkServiceGetEnabled(service),
                let interface = SCNetworkServiceGetInterface(service),
                let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                seenBSDNames.insert(bsdName).inserted
            else {
                return nil
            }

            let displayName =
                (SCNetworkServiceGetName(service) as String?)
                ?? (SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?)
                ?? bsdName

            return ConfiguredNetworkService(
                bsdName: bsdName,
                displayName: displayName
            )
        }
    }
}
