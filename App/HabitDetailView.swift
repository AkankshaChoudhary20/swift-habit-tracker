import SwiftUI
import HabitTrackerCore

/// Detail screen for a single habit: today's completion toggle plus the
/// streak and completion-rate stats computed by `HabitTrackerCore`.
struct HabitDetailView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitsViewModel

    /// Always re-reads the latest copy of this habit from the view model,
    /// so the view stays live after a toggle (the `habit` passed in at
    /// navigation time is just the starting snapshot).
    private var currentHabit: Habit {
        viewModel.habits.first(where: { $0.id == habit.id }) ?? habit
    }

    private var isCompletedToday: Bool {
        currentHabit.isCompleted(on: Date())
    }

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.toggleCompletion(for: currentHabit)
                } label: {
                    Label(
                        isCompletedToday ? "Completed Today" : "Mark as Complete",
                        systemImage: isCompletedToday ? "checkmark.circle.fill" : "circle"
                    )
                }
                .tint(isCompletedToday ? .green : .accentColor)
            }

            Section("Stats") {
                StatRow(title: "Current Streak", value: "\(currentHabit.currentStreak(asOf: Date())) days")
                StatRow(title: "Longest Streak", value: "\(currentHabit.longestStreak()) days")
                StatRow(
                    title: "Last 7 Days",
                    value: percentString(currentHabit.completionRate(lastNDays: 7, asOf: Date()))
                )
                StatRow(
                    title: "Last 30 Days",
                    value: percentString(currentHabit.completionRate(lastNDays: 30, asOf: Date()))
                )
            }

            Section("Details") {
                StatRow(
                    title: "Created",
                    value: currentHabit.createdAt.formatted(date: .abbreviated, time: .omitted)
                )
                StatRow(title: "Total Completions", value: "\(currentHabit.completedDayIdentifiers.count)")
            }
        }
        .navigationTitle(currentHabit.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func percentString(_ rate: Double) -> String {
        let percent = Int((rate * 100).rounded())
        return "\(percent)%"
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read"), viewModel: HabitsViewModel())
    }
}
