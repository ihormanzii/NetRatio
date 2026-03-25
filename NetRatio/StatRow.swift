//
//  StatRow.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//


import SwiftUI

struct StatRow: View {
    
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
