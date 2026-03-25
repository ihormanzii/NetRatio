# NetRatio

NetRatio is a lightweight macOS menu bar application that shows current network download and upload bandwidth in real time.

The app runs as a menu bar utility instead of a standard Dock app. Its menu bar label updates continuously with live traffic rates, and clicking it opens a compact panel with current download and upload speeds.

## Features

- Real-time download and upload monitoring
- Menu bar label with live bandwidth values
- Compact popover with current network stats
- Dock-less utility app behavior on macOS
- Built with SwiftUI for macOS

## How It Works

NetRatio reads byte counters from active macOS network interfaces and calculates the traffic delta over time to estimate current throughput.

It does not generate network traffic on its own. Instead, it measures the system's existing network activity and converts it into human-readable transfer rates.

## Requirements

- macOS >= 24.0
- Xcode >= 24
- Apple Silicon or Intel Mac

## Run in Xcode

1. Open the project in Xcode.
2. Select the `NetRatio` scheme.
3. Choose `My Mac` as the run destination.
4. Build and run the app.

After launch, NetRatio appears in the macOS menu bar.

## Build for Local Installation

1. In Xcode, choose `Product > Archive`.
2. In Organizer, select the archive.
3. Choose `Distribute App`.
4. Select `Copy App`.
5. Export `NetRatio.app` and move it to `/Applications`.

## Notes

- The app measures active non-loopback network interfaces.
- Virtual interfaces such as VPNs may affect the displayed totals if they carry traffic.
- The update interval is currently one second.

## Tech Stack

- Swift
- SwiftUI
- AppKit/macOS system networking counters
