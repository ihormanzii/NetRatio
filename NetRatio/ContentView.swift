//
//  ContentView.swift
//  NetRatio
//  Created by Ihor Manzii on 25.03.2026.
//

import SwiftUI

struct ContentView: View {
    let monitor: NetworkBandwidthMonitor
    @State private var isShowingAbout = false

    var body: some View {
        let selection = Binding(
            get: { monitor.selectedInterface },
            set: { monitor.selectInterface($0) }
        )

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Interface")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Interface", selection: selection) {
                    Text("All Interfaces")
                        .tag(NetworkInterfaceSelection.all)

                    ForEach(monitor.interfaceOptions) { option in
                        Text(option.pickerLabel)
                            .tag(NetworkInterfaceSelection.interface(option.bsdName))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

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
        .frame(width: 320)
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
        }
    }
}
