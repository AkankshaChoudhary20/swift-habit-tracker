import Foundation

/// Errors surfaced by `HabitStore` persistence operations.
public enum HabitStoreError: Error, Equatable {
    case habitNotFound(UUID)
}

/// A simple `Codable` + `FileManager`-backed persistence layer for habits.
///
/// This deliberately does not use SwiftData or CoreData: those frameworks
/// require an Xcode project / app runtime context to work with, which would
/// make the core logic impossible to build and test from a plain
/// command-line `swift build` / `swift test` invocation. Plain JSON on disk
/// keeps `HabitTrackerCore` a portable, dependency-free Swift package that
/// runs anywhere Swift runs (Linux CI, command-line tools, tests, or inside
/// an iOS app), while still being trivial to adopt from SwiftUI.
public final class HabitStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - fileURL: Location of the JSON file backing this store. Callers
    ///     (including tests) can point this at a temporary directory to
    ///     avoid touching real user data.
    ///   - fileManager: Injectable for testability; defaults to `.default`.
    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Convenience initializer that stores `habits.json` inside the given
    /// directory (created if needed).
    public convenience init(directory: URL, fileManager: FileManager = .default) {
        self.init(fileURL: directory.appendingPathComponent("habits.json"), fileManager: fileManager)
    }

    /// Loads all habits from disk. Returns an empty array if no file exists
    /// yet (first launch), rather than throwing.
    public func load() throws -> [Habit] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty {
            return []
        }
        return try decoder.decode([Habit].self, from: data)
    }

    /// Overwrites the persisted habit list with `habits`, creating the
    /// parent directory if necessary.
    public func save(habits: [Habit]) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(habits)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads the current habits, appends `habit`, and persists the result.
    @discardableResult
    public func addHabit(_ habit: Habit) throws -> [Habit] {
        var habits = try load()
        habits.append(habit)
        try save(habits: habits)
        return habits
    }

    /// Loads the current habits, toggles completion for `habitId` on
    /// `date`, persists, and returns the updated list.
    @discardableResult
    public func toggleCompletion(habitId: UUID, date: Date, calendar: Calendar = .current) throws -> [Habit] {
        var habits = try load()
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else {
            throw HabitStoreError.habitNotFound(habitId)
        }
        habits[index].toggleCompletion(on: date, calendar: calendar)
        try save(habits: habits)
        return habits
    }
}
