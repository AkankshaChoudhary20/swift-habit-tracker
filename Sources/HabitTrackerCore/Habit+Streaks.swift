import Foundation

/// Streak and completion-rate math for a `Habit`.
///
/// All calculations work purely off the normalized day-identifier strings
/// on `Habit`, so they're immune to time-of-day noise. Every function takes
/// an explicit `calendar` (defaulting to `.current`) so tests can pin a
/// specific calendar/timezone and get fully deterministic results.
public extension Habit {

    /// The length of the current unbroken streak of completed days, ending
    /// at (or just before) `asOf`.
    ///
    /// - If `asOf`'s day is completed, the streak is counted back from
    ///   there (inclusive).
    /// - If `asOf`'s day is *not yet* completed (e.g. it's "today" and the
    ///   user hasn't checked in yet), but the day before was completed, the
    ///   streak is still reported by counting back from that prior day —
    ///   not completing today doesn't retroactively zero out an existing
    ///   streak until the day is actually missed.
    /// - If neither `asOf`'s day nor the day before is completed, the
    ///   streak is 0.
    func currentStreak(asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        var cursor = today

        if !isCompleted(on: cursor, calendar: calendar) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
            if !isCompleted(on: cursor, calendar: calendar) {
                return 0
            }
        }

        var streak = 0
        while isCompleted(on: cursor, calendar: calendar) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    /// The longest run of consecutive completed calendar days across the
    /// habit's entire history (not limited to a window around "now").
    func longestStreak(calendar: Calendar = .current) -> Int {
        let days = completedDayIdentifiers
            .compactMap { DayIdentifier.date(from: $0, calendar: calendar) }
            .sorted()

        guard !days.isEmpty else { return 0 }

        var longest = 1
        var running = 1

        for index in 1..<days.count {
            let previousDay = days[index - 1]
            let day = days[index]

            if let expectedNext = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(expectedNext, inSameDayAs: day) {
                running += 1
            } else {
                running = 1
            }
            longest = max(longest, running)
        }

        return longest
    }

    /// The fraction (0.0...1.0) of the `lastNDays` calendar days up to and
    /// including `asOf` on which the habit was completed. Gaps count
    /// against the rate; days beyond the habit's `createdAt` are still
    /// counted as "not completed" if they fall in the window (a habit
    /// created partway through the window doesn't get a free pass — callers
    /// wanting rate-since-creation should pass a smaller `lastNDays`).
    func completionRate(lastNDays: Int, asOf date: Date = Date(), calendar: Calendar = .current) -> Double {
        guard lastNDays > 0 else { return 0 }

        let today = calendar.startOfDay(for: date)
        var completedCount = 0

        for offset in 0..<lastNDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            if isCompleted(on: day, calendar: calendar) {
                completedCount += 1
            }
        }

        return Double(completedCount) / Double(lastNDays)
    }
}
