# Swift Habit Tracker

A native iOS habit tracker, split into two layers:

- **`HabitTrackerCore`** — a pure Swift Package Manager library with all the
  model logic, streak math, and persistence. No UIKit, SwiftUI, or
  SwiftData. Builds and runs its full test suite from the command line with
  nothing but `swift build` / `swift test` — no Xcode required.
- **`App/`** — the SwiftUI app layer (views + `@main` entry point) that
  consumes `HabitTrackerCore`. This is real, complete SwiftUI source, but it
  is *not* wired into any SPM target (SwiftUI/UIKit aren't available to a
  plain command-line `swift build` on non-Apple-app targets), so it needs
  Xcode to actually compile and run as an app.

## What you can run right now, from the command line

```bash
swift build
swift test
```

Both operate only on `HabitTrackerCore` (see `Package.swift` — it defines a
single library target plus its test target, and nothing under `App/` is
referenced by it, by design). This is real, exercised logic: streak
calculation, completion-rate math, and JSON persistence, all covered by the
`XCTest` suite in `Tests/HabitTrackerCoreTests/`.

> **Note on Swift 5.9 + command-line-tools-only setups:** some Swift 5.9
> Command Line Tools installations (with no Xcode.app present) hit a
> SwiftPM host-toolchain regression where `swift build`/`swift test` fail
> immediately with `xcrun: error: unable to lookup item 'PlatformPath'`,
> for *any* package, before compiling a single file — this reproduces even
> with a brand-new, empty `swift package init` template, so it's not
> specific to this repository's code. If you hit this, it's fixed by
> updating to a newer Swift toolchain (5.9.2+/5.10+ from
> [swift.org](https://www.swift.org/install/) or a newer Xcode CLT), or by
> installing Xcode.app.

## What needs Xcode

`App/HabitTrackerApp.swift`, `ContentView.swift`, `HabitListView.swift`,
`AddHabitView.swift`, and `HabitDetailView.swift` are complete, idiomatic
SwiftUI (iOS 17+: `NavigationStack`, `List`, `@State`/`@StateObject`,
`ContentUnavailableView`, etc.) that build a full three-screen app (list →
add-habit sheet → detail) on top of `HabitTrackerCore`. They deliberately
live outside `Sources/` so `swift build` never tries (and fails) to compile
SwiftUI on a platform/toolchain that can't provide it.

To actually run the app:

1. Open Xcode → **File → New → Project** → iOS **App**, product name
   `HabitTracker`, interface **SwiftUI**, minimum deployment target
   **iOS 17**.
2. Delete the generated `ContentView.swift`/app-entry file Xcode creates.
3. Drag the five files from `App/` into the new project's app target.
4. Add `HabitTrackerCore` as a local Swift Package dependency: **File → Add
   Package Dependencies… → Add Local…**, then select this repository's root
   directory (where `Package.swift` lives), and add the `HabitTrackerCore`
   library to the app target.
5. Build & run on an iOS 17+ simulator or device.

No other setup is needed — the views only depend on `HabitTrackerCore` and
standard SwiftUI/Foundation.

## Architecture

### Why JSON + `Codable` instead of SwiftData/CoreData

`HabitTrackerCore` persists habits as a single JSON array via `HabitStore`
(`Codable` + `FileManager`, `Sources/HabitTrackerCore/HabitStore.swift`)
rather than SwiftData or CoreData. SwiftData/CoreData need an Xcode-managed
model/runtime context to function at all, which would make it impossible to
build or test the core package from a plain `swift build`/`swift test`
invocation (e.g. in CI, or on this machine, which only has the command-line
tools installed). Plain JSON on disk:

- Runs anywhere Swift runs — Linux, CI, a command-line tool, or inside the
  iOS app — with zero platform-specific dependencies.
- Is trivial to unit test: point `HabitStore` at a temp directory (see
  `Tests/HabitTrackerCoreTests/HabitStoreTests.swift`) and assert on exact
  round-tripped values, no in-memory Core Data stack or mocking needed.
- Is still perfectly adequate for a habit tracker's data volume (a JSON
  array of a few dozen/hundred habits, each holding a small set of "day
  completed" strings).

`HabitStore` exposes `load()`, `save(habits:)`, `addHabit(_:)`, and
`toggleCompletion(habitId:date:)`, each of which reads-modifies-writes the
full JSON file. The SwiftUI layer wraps this in an `ObservableObject`
(`HabitsViewModel`, in `App/ContentView.swift`) so views get `@Published`
updates — that adapter is the only place Combine/SwiftUI touches the store.

### Streak algorithm

Completed days are stored as normalized `"yyyy-MM-dd"` strings
(`DayIdentifier` in `Sources/HabitTrackerCore/Habit.swift`), not raw
`Date`s. Raw `Date`s carry a time-of-day component and are sensitive to the
calendar/timezone at the moment they're created, which makes "was this
habit completed on this calendar day" fragile — two `Date`s a few
milliseconds apart on the same day could compare unequal, and marking "today"
complete twice could silently create two entries instead of one. Normalizing
to a day-identifier string up front, stored in a `Set<String>`, makes
completion:

- **Idempotent** — marking the same day complete N times only ever inserts
  one set element.
- **Order-independent** — no reliance on insertion order for correctness.
- **Directly `Codable`** — the set serializes as a plain JSON array of
  strings.

Given that, `Habit+Streaks.swift` implements:

- **`currentStreak(asOf:)`** — walks backwards day-by-day from `asOf`
  counting consecutive completed days. Handles the "haven't checked off
  today yet" case explicitly: if `asOf`'s day isn't completed but the day
  before it is, the walk starts from that prior day instead of returning 0
  — not having completed *today* yet doesn't retroactively erase an
  existing streak until a day is actually missed. If neither `asOf` nor the
  day before is completed, the streak is 0.
- **`longestStreak()`** — sorts all completed day-identifiers
  chronologically and scans for the longest run of consecutive calendar
  days, independent of "now" (a long streak from months ago still counts,
  even if the current streak is shorter or zero).
- **`completionRate(lastNDays:asOf:)`** — counts completed days across the
  `lastNDays` calendar days ending at `asOf`, inclusive, and returns the
  fraction. Gaps simply don't count, and completions outside the window are
  ignored.

Every function takes an explicit `calendar` parameter (defaulting to
`.current`) so tests can pin a fixed `Calendar`/`TimeZone` and get fully
deterministic results, independent of the machine running them.

## Project layout

```
swift-habit-tracker/
├── Package.swift                          # HabitTrackerCore library + test target only
├── Sources/HabitTrackerCore/
│   ├── Habit.swift                        # Habit model, day-identifier normalization
│   ├── Habit+Streaks.swift                # currentStreak / longestStreak / completionRate
│   └── HabitStore.swift                   # Codable + FileManager persistence
├── Tests/HabitTrackerCoreTests/
│   ├── HabitStreakTests.swift             # streak/rate edge cases
│   └── HabitStoreTests.swift              # save/load round-trip, temp-directory based
└── App/                                   # SwiftUI app layer (Xcode-only, not an SPM target)
    ├── HabitTrackerApp.swift
    ├── ContentView.swift
    ├── HabitListView.swift
    ├── AddHabitView.swift
    └── HabitDetailView.swift
```
