import SwiftUI

/// App entry point.
///
/// This file (and the rest of `App/`) is plain SwiftUI source that is
/// intentionally NOT part of any Swift Package Manager target — see the
/// project README for why, and for the steps to add it to a real iOS app
/// target in Xcode. It depends on the `HabitTrackerCore` package for all
/// habit modeling, streak math, and persistence.
@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
