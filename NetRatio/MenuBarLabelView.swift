//
//  MenuBarLabelView.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//


import SwiftUI

struct MenuBarLabelView: View {
    
    let monitor: NetworkBandwidthMonitor

    var body: some View {
        Text("\(monitor.downloadRateCompact)↓ \(monitor.uploadRateCompact)↑")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .monospacedDigit()
    }
}