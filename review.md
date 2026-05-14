# YaosamoNotBudgetingApp Code Review

Review date: 2026-05-14

Scope: small SwiftUI iOS app in `YaosamoNotBudgetingApp/`.

## Summary

No critical issues were found. The main problem is maintainability: `ContentView.swift` is 1,059 lines and contains most of the app, including design-system code, dashboard UI, settings, add/edit sheets, row views, and a hidden development tuning tool. This makes the code harder for future agents or humans to navigate safely.

## Important

### Validate Money Amounts Consistently

Locations:
- `YaosamoNotBudgetingApp/ContentView.swift:734`
- `YaosamoNotBudgetingApp/ContentView.swift:807`
- `YaosamoNotBudgetingApp/ContentView.swift:872`

The add/edit sheets only check that text can be parsed as `Double` and that the name is non-empty. Pasted values like negative numbers, extremely large values, or non-finite values can still reach the store.

Recommended fix:
- Add a shared validation helper, probably `amount.isFinite && amount > 0`.
- Use it in all add/edit sheets.
- Also enforce it in `BudgetStore` mutation methods so the model layer is not dependent on UI validation.

## Medium

### Split `ContentView.swift`

Location:
- `YaosamoNotBudgetingApp/ContentView.swift:1`

`ContentView.swift` mixes unrelated responsibilities and should be split for agent-friendly navigation.

Recommended split:
- `Models.swift`: `PurchaseItem`, `FinancialRecord`, `Currency`
- `BudgetStore.swift`: persistence and business logic only
- `LiquidGlass.swift`: `GlassParams`, `LiquidGlassConfig`, `LiquidGlass`
- `DashboardView.swift`: current main `ContentView`
- `Rows.swift`: `BoughtRowView`, `PlannedRowView`
- `SettingsSheet.swift`
- `PurchaseSheets.swift`
- `RecordSheets.swift`
- `LiquidGlassTweakSheet.swift`, ideally debug-only

### Cache Money Formatting

Location:
- `YaosamoNotBudgetingApp/BudgetStore.swift:62`

`formatAmount(_:)` creates a new `NumberFormatter` on every render. SwiftUI recomputes often, and list rows call this repeatedly.

Recommended fix:
- Cache a formatter and update its currency settings when `currencyCode` changes, or introduce a small `MoneyFormatter` helper.

### Move Development Tweak UI Behind Debug Build

Location:
- `YaosamoNotBudgetingApp/ContentView.swift:938`

The liquid-glass tuning UI is reachable in production through a hidden five-tap gesture. It is not dead code, but it is development tooling.

Recommended fix:
- Wrap tweak state, gesture, button, and sheet in `#if DEBUG`.
- Or remove the tweak UI entirely before release.

## Minor / Dead Code

### Remove Unused Navigation State

Location:
- `YaosamoNotBudgetingApp/ContentView.swift:117`

`navDirection` is declared but unused.

Recommended fix:
- Delete the property.

### Remove or Use `monthYearLabel`

Location:
- `YaosamoNotBudgetingApp/BudgetStore.swift:155`

`monthYearLabel` is unused.

Recommended fix:
- Delete it, or use it in the header if the UI should display year context.

### Remove or Use `roundedRect`

Location:
- `YaosamoNotBudgetingApp/ContentView.swift:63`

`LiquidGlass.Shape.roundedRect` has no call sites.

Recommended fix:
- Keep only if the upcoming split will reuse it soon.
- Otherwise remove the enum case and its switch branch.

### Replace No-Op Preview Button

Location:
- `YaosamoNotBudgetingApp/ContentView.swift:966`

`Button("Capsule") {}` is a no-op in the tweak preview.

Recommended fix:
- Replace it with static `Text`, or mark the button disabled so it does not imply an action.

### Ignore Xcode User State

Git status showed this untracked folder:

```text
YaosamoNotBudgetingApp.xcodeproj/project.xcworkspace/
```

It contains:
- `contents.xcworkspacedata`
- `xcuserdata/personal.xcuserdatad/UserInterfaceState.xcuserstate`

Recommended fix:
- Track `contents.xcworkspacedata` only if the project needs it.
- Ignore `xcuserdata/` and `*.xcuserstate`.

## Verification Notes

`xcodebuild -list -project YaosamoNotBudgetingApp.xcodeproj` was able to read the project and scheme.

`xcodebuild build -project YaosamoNotBudgetingApp.xcodeproj -scheme YaosamoNotBudgetingApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` failed because this environment could not access CoreSimulator services during asset catalog compilation. The visible failure was simulator/runtime related, not a Swift compiler error.
