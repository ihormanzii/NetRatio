//
//  NetworkBandwidthMonitor.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//

import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class NetworkBandwidthMonitor {

    private let updateInterval: Duration = .seconds(1)
    private var previousSnapshot: NetworkSnapshot?
    private var refreshTask: Task<Void, Never>?

    var downloadRate: Double = 0
    var uploadRate: Double = 0
    var totalDownloadedBytes: UInt64 = 0
    var totalUploadedBytes: UInt64 = 0

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

    var totalDownloadedDescription: String {
        formattedByteCount(totalDownloadedBytes)
    }

    var totalUploadedDescription: String {
        formattedByteCount(totalUploadedBytes)
    }

    init() {
        refreshTask = Task { [weak self] in
            await self?.runRefreshLoop()
        }
    }

    private func runRefreshLoop() async {
        refreshSample()

        while !Task.isCancelled {
            try? await Task.sleep(for: updateInterval)
            refreshSample()
        }
    }

    private func refreshSample() {
        guard let snapshot = NetworkSnapshot.current() else {
            downloadRate = 0
            uploadRate = 0
            previousSnapshot = nil
            return
        }

        guard let previousSnapshot else {
            self.previousSnapshot = snapshot
            return
        }

        let elapsed = snapshot.timestamp.timeIntervalSince(
            previousSnapshot.timestamp
        )
        guard elapsed > 0 else {
            return
        }

        guard
            snapshot.receivedBytes >= previousSnapshot.receivedBytes,
            snapshot.sentBytes >= previousSnapshot.sentBytes
        else {
            downloadRate = 0
            uploadRate = 0
            self.previousSnapshot = snapshot
            return
        }

        let downloadedBytes =
            snapshot.receivedBytes - previousSnapshot.receivedBytes
        let uploadedBytes = snapshot.sentBytes - previousSnapshot.sentBytes

        downloadRate = Double(downloadedBytes) / elapsed
        uploadRate = Double(uploadedBytes) / elapsed
        totalDownloadedBytes += downloadedBytes
        totalUploadedBytes += uploadedBytes
        self.previousSnapshot = snapshot
    }

    private func formattedRate(_ bytesPerSecond: Double) -> String {
        let bytes = safeByteCount(bytesPerSecond)
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

        let bytes = safeByteCount(bytesPerSecond)

        if bytes < 1024 {
            return "0K"
        }

        return formatter.string(fromByteCount: bytes).replacingOccurrences(
            of: " ",
            with: ""
        )
    }

    private func formattedByteCount(_ bytes: UInt64) -> String {
        let clampedBytes = min(bytes, UInt64(Int64.max))
        return ByteCountFormatter.string(
            fromByteCount: Int64(clampedBytes),
            countStyle: .binary
        )
    }

    private func safeByteCount(_ bytesPerSecond: Double) -> Int64 {
        let clampedValue = min(max(bytesPerSecond.rounded(), 0), Double(Int64.max))
        return Int64(clampedValue)
    }
}

private struct NetworkSnapshot {

    let timestamp: Date
    let receivedBytes: UInt64
    let sentBytes: UInt64

    static func current() -> NetworkSnapshot? {
        var interfaceAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddress) == 0,
            let firstAddress = interfaceAddress
        else {
            return nil
        }

        defer {
            freeifaddrs(interfaceAddress)
        }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0

        for pointer in sequence(
            first: firstAddress,
            next: { $0.pointee.ifa_next }
        ) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)

            guard
                (flags & IFF_UP) != 0,
                (flags & IFF_LOOPBACK) == 0,
                let data = interface.ifa_data
            else {
                continue
            }

            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            receivedBytes += UInt64(networkData.ifi_ibytes)
            sentBytes += UInt64(networkData.ifi_obytes)
        }

        return NetworkSnapshot(
            timestamp: Date(),
            receivedBytes: receivedBytes,
            sentBytes: sentBytes
        )
    }
}
