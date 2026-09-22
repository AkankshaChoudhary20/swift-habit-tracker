import SwiftUI

/// Simple form sheet for creating a new habit by name.
struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    /// Called with the trimmed habit name when the user taps "Add".
    let onAdd: (String) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Name") {
                    TextField("e.g. Drink Water", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(addIfValid)
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addIfValid)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func addIfValid() {
        guard !trimmedName.isEmpty else { return }
        onAdd(trimmedName)
        dismiss()
    }
}

#Preview {
    AddHabitView(onAdd: { _ in })
}
