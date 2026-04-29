# Perch - AI-Powered Stock Tracker

Perch is a modern iOS stock tracking app built with Swift and SwiftUI. It helps users monitor watchlists, inspect portfolio holdings, follow market movers, and read AI-powered market insights.

The app follows an MVVM structure with a repository layer, mock offline-first market data, reusable SwiftUI components, and an Xcode project wrapper for simulator runs.

## Core Features

- Market dashboard with portfolio value, daily gain/loss, index cards, and top movers
- Watchlist with ticker/company search and sector filters
- Stock detail screens with price, daily move, chart, metrics, sentiment, and AI summary
- Portfolio view with holdings, allocation bars, market value, and gain/loss
- Discover view for trending stocks and sector groups
- AI insights generated from watchlist, holdings, and market movement
- Cached mock data so the app works without API keys

## Tech Stack

- Swift
- SwiftUI
- MVVM
- Async/await
- Repository pattern
- Codable models
- Disk cache
- XCTest

## Project Layout

```text
Sources/Perch
├── App
│   └── ContentView.swift
├── Core
│   ├── AI
│   ├── Networking
│   ├── Persistence
│   ├── Repositories
│   └── Utilities
├── Features
│   ├── Dashboard
│   ├── Transactions   # Watchlist UI lives here to preserve project wiring
│   ├── Budgets        # Portfolio UI lives here to preserve project wiring
│   └── Insights
└── Shared
    ├── MockData.swift
    ├── PerchComponents.swift
    └── PerchTheme.swift
```

## Run Without Opening Xcode

```bash
./scripts/run-ios-simulator.sh
```

You can also choose a simulator:

```bash
./scripts/run-ios-simulator.sh "iPhone 14"
```

## Run In Xcode

```bash
open Perch.xcodeproj
```

Select the `PerchApp` scheme, choose a specific iPhone simulator, then press `Cmd + R`.

## Verify

```bash
swift build
swift test
xcodebuild -project Perch.xcodeproj -scheme PerchApp -destination 'generic/platform=iOS Simulator' -derivedDataPath .derivedData build
```
