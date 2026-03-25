//
//  InfoRow.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//

import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
        }
    }
}
