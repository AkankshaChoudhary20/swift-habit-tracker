import SwiftUI
import HabitTrackerCore

/// Root list of all tracked habits, with a quick-complete toggle for
/// "today" on each row and navigation into `HabitDetailView` for the full
/// streak/completion-rate breakdown.
struct HabitListView: View {
    @ObservedObject var viewModel: HabitsViewModel
    @State private var isPresentingAddHabit = false

    var body: some View {
        Group {
            if viewModel.habits.isEmpty {
                ContentUnavailableView(
                    "No Habits Yet",
                    systemImage: "checklist",
                    description: Text("Tap the + button to start tracking your first habit.")
                )
            } else {
                List {
                    ForEach(viewModel.habits) { habit in
                        NavigationLink(value: habit.id) {
                            HabitRow(habit: habit, viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { habitId in
            if let habit = viewModel.habits.first(where: { $0.id == habitId }) {
                HabitDetailView(habit: habit, viewModel: viewModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddHabit = true
                } label: {
                    Label("Add Habit", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddHabit) {
            AddHabitView { name in
                viewModel.addHabit(name: name)
            }
        }
    }
}

private struct HabitRow: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitsViewModel

    private var isCompletedToday: Bool {
        habit.isCompleted(on: Date())
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                Text("\(habit.currentStreak(asOf: Date()))-day streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.toggleCompletion(for: habit)
            } label: {
                Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isCompletedToday ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompletedToday ? "Completed today" : "Mark completed today")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HabitListView(viewModel: HabitsViewModel())
    }
}
