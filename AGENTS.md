# Agent Guide

SwiftUI iOS app. iCloud-synced personal budget tracker. Single target, no test bundle.

## Where to edit

| If you're working on… | Edit |
|---|---|
| Dashboard (home) UI, header, scroll, motion parallax | `ContentView.swift` |
| Purchase rows (bought/planned) | `RowViews.swift` |
| Plan-purchase / edit-item sheet | `PurchaseSheets.swift` |
| Balance sheet, currency picker, edit-income/expense | `SettingsSheet.swift` |
| Shared amount input (display + numpad + input helpers) | `AmountEntryView.swift` |
| Sheet top bar (title + close + delete) | `SheetHeader.swift` |
| Gyroscope tilt | `MotionManager.swift` |
| Data model, persistence, mutations, sample data, formatting | `BudgetStore.swift` |
| Liquid glass modifier, `AppColors` | `LiquidGlass.swift` |
| Debug-only glass tuner (`#if DEBUG`) | `LiquidGlassTweakSheet.swift` |
| App entry point | `YaosamoNotBudgetingAppApp.swift` |

## Conventions

- New shared UI primitives → their own top-level file (e.g. `SheetHeader.swift`, `AmountEntryView.swift`).
- Data and persistence live in `BudgetStore.swift`; views never touch `NSUbiquitousKeyValueStore` directly.
- Money input is funneled through `MoneyInput` (in `AmountEntryView.swift`) and rendered via `NumpadView` / `AmountDisplayText`. Don't reimplement digit/decimal/backspace logic.
- Currency formatting goes through `store.formatAmount(_:)`. Don't construct `NumberFormatter` inline.
- Per-item display rounds to integers via `maximumFractionDigits = 2, minimumFractionDigits = 0`. Decimals show only when present in stored amount.
- Color tokens: `AppColors.success`. Avoid hard-coded `Color(red:green:blue:)` in feature files.

## Build

```sh
xcodebuild build \
  -project YaosamoNotBudgetingApp.xcodeproj \
  -scheme YaosamoNotBudgetingApp \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

A clean simulator install requires Xcode-bundled simulator runtimes.

## Notes for AI agents

- **New `.swift` files** must be added to the Xcode project target manually (drag into Xcode or edit `project.pbxproj`). Creating the file on disk is not enough.
- Persistence is debounced (~500ms) via Combine. State mutations propagate to iCloud automatically; don't call `persist()` directly.
- Sample purchase items are seeded on first launch only when no saved items exist. Don't reset them on launch.
