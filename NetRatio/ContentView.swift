//
//  ContentView.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//

import SwiftUI

struct ContentView: View {
    let monitor: NetworkBandwidthMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NetRatio")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                StatRow(
                    title: "Download",
                    value: monitor.downloadRateDescription,
                    systemImage: "arrow.down.circle.fill",
                    color: .blue
                )

                StatRow(
                    title: "Upload",
                    value: monitor.uploadRateDescription,
                    systemImage: "arrow.up.circle.fill",
                    color: .green
                )
            }

            Divider()

            Text("Updates every second using live macOS interface counters.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Quit NetRatio") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 280)
    }
}

#Preview {
    ContentView(monitor: NetworkBandwidthMonitor())
}

private struct StatRow: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            Spacer(minLength: 0)
        }
    }
}

struct MenuBarLabelView: View {
    let monitor: NetworkBandwidthMonitor

    var body: some View {
        Text("\(monitor.downloadRateCompact)↓ \(monitor.uploadRateCompact)↑")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .monospacedDigit()
    }
}
