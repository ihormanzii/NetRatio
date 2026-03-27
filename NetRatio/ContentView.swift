//
//  ContentView.swift
//  NetRatio
//s
//  Created by Ihor Manzii on 25.03.2026.
//

import SwiftUI

struct ContentView: View {
    let monitor: NetworkBandwidthMonitor
    @State private var isShowingAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            VStack(alignment: .leading, spacing: 10) {
                Text("Live")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Since Launch")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                StatRow(
                    title: "Downloaded",
                    value: monitor.totalDownloadedDescription,
                    systemImage: "tray.and.arrow.down.fill",
                    color: .blue
                )

                StatRow(
                    title: "Uploaded",
                    value: monitor.totalUploadedDescription,
                    systemImage: "tray.and.arrow.up.fill",
                    color: .green
                )
            }

            Divider()

            HStack(spacing: 12) {
                Button("About") {
                    isShowingAbout = true
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }

        }
        .padding(16)
        .frame(width: 280)
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
        }
    }
}
