//
//  AboutView.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//


import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.and.line.horizontal.and.arrow.up")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("NetRatio")
                        .font(.title2.weight(.semibold))

                    Text("Real-time network bandwidth monitor for macOS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            InfoRow(title: "Author", value: "Ihor Manzii")

            VStack(alignment: .leading, spacing: 6) {
                Text("GitHub")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("GitHub", destination: URL(string: "https://github.com/ihormanzii/NetRatio")!)
                    .font(.body.monospaced())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Copyright")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Copyright © 2026 Ihor Manzii. All rights reserved.")
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("License")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("MIT License")
                    .font(.body)
            }

            HStack {
                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
