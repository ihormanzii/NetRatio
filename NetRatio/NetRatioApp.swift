//
//  NetRatioApp.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//

import SwiftUI

@main
struct NetRatioApp: App {

    @State private var monitor = NetworkBandwidthMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView(monitor: monitor)
        } label: {
            MenuBarLabelView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
