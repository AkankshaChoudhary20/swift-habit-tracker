import SwiftUI
import HabitTrackerCore

/// Observable adapter around `HabitStore` so SwiftUI views can bind to and
/// react to habit changes with `@Published`/`@StateObject`.
///
/// `HabitTrackerCore` itself stays free of SwiftUI/Combine so it remains a
/// plain, cross-platform, command-line-testable package (see the README);
/// this view model is the seam where that pure Swift core meets the
/// SwiftUI app layer.
@MainActor
final class HabitsViewModel: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    @Published var errorMessage: String?

    private let store: HabitStore

    init(store: HabitStore = HabitsViewModel.defaultStore()) {
        self.store = store
        load()
    }

    /// Persists habits.json in the app's Documents directory on-device.
    private static func defaultStore() -> HabitStore {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return HabitStore(directory: documentsDirectory)
    }

    func load() {
        do {
            habits = try store.load()
        } catch {
            errorMessage = "Failed to load habits: \(error.localizedDescription)"
        }
    }

    func addHabit(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            habits = try store.addHabit(Habit(name: trimmed))
        } catch {
            errorMessage = "Failed to add habit: \(error.localizedDescription)"
        }
    }

    func toggleCompletion(for habit: Habit, on date: Date = Date()) {
        do {
            habits = try store.toggleCompletion(habitId: habit.id, date: date)
        } catch {
            errorMessage = "Failed to update habit: \(error.localizedDescription)"
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = HabitsViewModel()

    var body: some View {
        NavigationStack {
            HabitListView(viewModel: viewModel)
                .navigationTitle("Habits")
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.errorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
