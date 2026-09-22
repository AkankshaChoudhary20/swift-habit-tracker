import XCTest
@testable import HabitTrackerCore

final class HabitStoreTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use a fresh temp directory per test so tests never touch real
        // user data and never interfere with each other.
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HabitTrackerCoreTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        if let tempDirectory, FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testLoad_whenNoFileExists_returnsEmptyArray() throws {
        let store = HabitStore(directory: tempDirectory)
        let habits = try store.load()
        XCTAssertEqual(habits, [])
    }

    func testSaveThenLoad_roundTripsHabitsExactly() throws {
        let store = HabitStore(directory: tempDirectory)

        var habit1 = Habit(name: "Drink Water")
        habit1.markCompleted(on: Date())
        var habit2 = Habit(name: "Read")
        habit2.markCompleted(on: Date())
        habit2.markCompleted(on: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

        try store.save(habits: [habit1, habit2])

        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(Set(loaded.map(\.id)), Set([habit1.id, habit2.id]))

        let loadedHabit1 = loaded.first { $0.id == habit1.id }
        XCTAssertEqual(loadedHabit1?.name, "Drink Water")
        XCTAssertEqual(loadedHabit1?.completedDayIdentifiers, habit1.completedDayIdentifiers)

        let loadedHabit2 = loaded.first { $0.id == habit2.id }
        XCTAssertEqual(loadedHabit2?.name, "Read")
        XCTAssertEqual(loadedHabit2?.completedDayIdentifiers, habit2.completedDayIdentifiers)
    }

    func testSave_createsIntermediateDirectoriesIfNeeded() throws {
        let nestedDirectory = tempDirectory.appendingPathComponent("nested/deeper")
        let store = HabitStore(directory: nestedDirectory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedDirectory.path))

        try store.save(habits: [Habit(name: "Meditate")])

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedDirectory.appendingPathComponent("habits.json").path))
    }

    func testAddHabit_appendsToExistingPersistedHabits() throws {
        let store = HabitStore(directory: tempDirectory)
        try store.save(habits: [Habit(name: "Existing")])

        let newHabit = Habit(name: "New Habit")
        let result = try store.addHabit(newHabit)

        XCTAssertEqual(result.count, 2)
        let reloaded = try store.load()
        XCTAssertEqual(reloaded.count, 2)
        XCTAssertTrue(reloaded.contains { $0.name == "New Habit" })
    }

    func testToggleCompletion_persistsChangeAcrossReload() throws {
        let store = HabitStore(directory: tempDirectory)
        let habit = Habit(name: "Exercise")
        try store.save(habits: [habit])

        let today = Date()
        _ = try store.toggleCompletion(habitId: habit.id, date: today)

        let reloaded = try store.load()
        let reloadedHabit = try XCTUnwrap(reloaded.first { $0.id == habit.id })
        XCTAssertTrue(reloadedHabit.isCompleted(on: today))

        // Toggling again should flip it back off and persist that too.
        _ = try store.toggleCompletion(habitId: habit.id, date: today)
        let reloadedAgain = try store.load()
        let reloadedHabitAgain = try XCTUnwrap(reloadedAgain.first { $0.id == habit.id })
        XCTAssertFalse(reloadedHabitAgain.isCompleted(on: today))
    }

    func testToggleCompletion_unknownHabitId_throwsHabitNotFound() throws {
        let store = HabitStore(directory: tempDirectory)
        try store.save(habits: [Habit(name: "Only Habit")])

        let unknownId = UUID()
        XCTAssertThrowsError(try store.toggleCompletion(habitId: unknownId, date: Date())) { error in
            XCTAssertEqual(error as? HabitStoreError, .habitNotFound(unknownId))
        }
    }
}
