import XCTest
@testable import HabitTrackerCore

final class HabitStreakTests: XCTestCase {

    /// Fixed, deterministic calendar/timezone so tests never depend on the
    /// machine running them.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12 // noon, to avoid any midnight rounding edge cases
        return calendar.date(from: components)!
    }

    private func makeHabit(completedOn days: [Date]) -> Habit {
        var habit = Habit(name: "Test Habit", createdAt: days.first ?? Date())
        for day in days {
            habit.markCompleted(on: day, calendar: calendar)
        }
        return habit
    }

    // MARK: - currentStreak

    func testCurrentStreak_emptyHabit_isZero() {
        let habit = Habit(name: "Empty")
        XCTAssertEqual(habit.currentStreak(asOf: date(2024, 6, 10), calendar: calendar), 0)
    }

    func testCurrentStreak_todayCompleted_countsThroughToday() {
        let habit = makeHabit(completedOn: [
            date(2024, 6, 8), date(2024, 6, 9), date(2024, 6, 10)
        ])
        XCTAssertEqual(habit.currentStreak(asOf: date(2024, 6, 10), calendar: calendar), 3)
    }

    func testCurrentStreak_todayNotYetCompleted_butYesterdayWas_stillCountsStreak() {
        // Today is 6/10 and hasn't been checked off yet, but 6/8 and 6/9
        // were completed back-to-back. The streak should still read 2,
        // not 0 — not having completed "today" yet shouldn't erase an
        // active streak.
        let habit = makeHabit(completedOn: [date(2024, 6, 8), date(2024, 6, 9)])
        XCTAssertEqual(habit.currentStreak(asOf: date(2024, 6, 10), calendar: calendar), 2)
    }

    func testCurrentStreak_neitherTodayNorYesterdayCompleted_isZero() {
        let habit = makeHabit(completedOn: [date(2024, 6, 1), date(2024, 6, 2)])
        XCTAssertEqual(habit.currentStreak(asOf: date(2024, 6, 10), calendar: calendar), 0)
    }

    func testCurrentStreak_gapInMiddle_onlyCountsMostRecentRun() {
        let habit = makeHabit(completedOn: [
            date(2024, 6, 1), date(2024, 6, 2), // isolated earlier run
            date(2024, 6, 8), date(2024, 6, 9), date(2024, 6, 10) // recent run
        ])
        XCTAssertEqual(habit.currentStreak(asOf: date(2024, 6, 10), calendar: calendar), 3)
    }

    func testCurrentStreak_markingSameDayTwice_isIdempotentAndDoesNotInflateStreak() {
        var habit = Habit(name: "Idempotent")
        habit.markCompleted(on: date(2024, 6, 10), calendar: calendar)
        habit.markCompleted(on: date(2024, 6, 10), calendar: calendar)
        habit.markCompleted(on: date(2024, 6, 10), calendar: calendar)

        XCTAssertEqual(habit.completedDayIdentifiers.count, 1)
        XCTAssertEqual(habit.currentStreak(asOf: date(2024, 6, 10), calendar: calendar), 1)
    }

    func testToggleCompletion_isIdempotentTogglePair() {
        var habit = Habit(name: "Toggle")
        habit.toggleCompletion(on: date(2024, 6, 10), calendar: calendar)
        XCTAssertTrue(habit.isCompleted(on: date(2024, 6, 10), calendar: calendar))

        habit.toggleCompletion(on: date(2024, 6, 10), calendar: calendar)
        XCTAssertFalse(habit.isCompleted(on: date(2024, 6, 10), calendar: calendar))
        XCTAssertEqual(habit.completedDayIdentifiers.count, 0)
    }

    // MARK: - longestStreak

    func testLongestStreak_emptyHabit_isZero() {
        let habit = Habit(name: "Empty")
        XCTAssertEqual(habit.longestStreak(calendar: calendar), 0)
    }

    func testLongestStreak_singleDay_isOne() {
        let habit = makeHabit(completedOn: [date(2024, 6, 10)])
        XCTAssertEqual(habit.longestStreak(calendar: calendar), 1)
    }

    func testLongestStreak_pastRunLongerThanCurrentRun_returnsPastRun() {
        let habit = makeHabit(completedOn: [
            // 5-day run in the past
            date(2024, 5, 1), date(2024, 5, 2), date(2024, 5, 3), date(2024, 5, 4), date(2024, 5, 5),
            // gap
            date(2024, 6, 8), date(2024, 6, 9) // shorter, more recent 2-day run
        ])
        XCTAssertEqual(habit.longestStreak(calendar: calendar), 5)
    }

    func testLongestStreak_unorderedInsertion_stillComputesCorrectly() {
        // Insert out of chronological order to make sure the sort inside
        // longestStreak isn't accidentally relying on insertion order.
        let habit = makeHabit(completedOn: [
            date(2024, 6, 9), date(2024, 6, 3), date(2024, 6, 10), date(2024, 6, 4), date(2024, 6, 8)
        ])
        // 6/3, 6/4 = run of 2; 6/8, 6/9, 6/10 = run of 3
        XCTAssertEqual(habit.longestStreak(calendar: calendar), 3)
    }

    // MARK: - completionRate

    func testCompletionRate_noCompletions_isZero() {
        let habit = Habit(name: "Empty")
        XCTAssertEqual(habit.completionRate(lastNDays: 7, asOf: date(2024, 6, 10), calendar: calendar), 0.0)
    }

    func testCompletionRate_allDaysCompleted_isOne() {
        let days = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: date(2024, 6, 10))! }
        let habit = makeHabit(completedOn: days)
        XCTAssertEqual(habit.completionRate(lastNDays: 7, asOf: date(2024, 6, 10), calendar: calendar), 1.0)
    }

    func testCompletionRate_withGaps_computesFraction() {
        // Complete 3 out of the 5-day window ending 6/10: 6/6, 6/8, 6/10.
        let habit = makeHabit(completedOn: [date(2024, 6, 6), date(2024, 6, 8), date(2024, 6, 10)])
        let rate = habit.completionRate(lastNDays: 5, asOf: date(2024, 6, 10), calendar: calendar)
        XCTAssertEqual(rate, 3.0 / 5.0, accuracy: 0.0001)
    }

    func testCompletionRate_completionsOutsideWindow_areIgnored() {
        let habit = makeHabit(completedOn: [date(2024, 1, 1)]) // way outside any recent window
        let rate = habit.completionRate(lastNDays: 7, asOf: date(2024, 6, 10), calendar: calendar)
        XCTAssertEqual(rate, 0.0)
    }
}
