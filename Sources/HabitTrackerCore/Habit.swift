import Foundation

/// A single habit the user is tracking, along with the set of calendar days
/// on which it was completed.
///
/// Completed days are stored as normalized "yyyy-MM-dd" day-identifier
/// strings rather than raw `Date` values. Raw `Date`s carry a time-of-day
/// component and are sensitive to the device's current calendar/timezone,
/// which makes set membership, equality, and "is this the same day as
/// today" checks fragile (e.g. two `Date`s a few milliseconds apart on the
/// same calendar day would otherwise be treated as different days, or the
/// same wall-clock day could round differently around a timezone change).
/// Normalizing to a `yyyy-MM-dd` string up front makes completion tracking
/// idempotent, `Codable`-friendly (plain JSON strings), and stable.
public struct Habit: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var completedDayIdentifiers: Set<String>

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        completedDayIdentifiers: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.completedDayIdentifiers = completedDayIdentifiers
    }

    /// Convenience accessor exposing completed days as normalized
    /// start-of-day `Date`s (in the current calendar), for callers that
    /// prefer working with `Date` rather than day-identifier strings.
    public var completedDates: Set<Date> {
        Set(completedDayIdentifiers.compactMap { DayIdentifier.date(from: $0) })
    }

    /// Marks `date` as complete. Idempotent: marking the same calendar day
    /// complete more than once has no additional effect.
    public mutating func markCompleted(on date: Date, calendar: Calendar = .current) {
        completedDayIdentifiers.insert(DayIdentifier.string(from: date, calendar: calendar))
    }

    /// Removes completion for `date`, if present. Idempotent.
    public mutating func markIncomplete(on date: Date, calendar: Calendar = .current) {
        completedDayIdentifiers.remove(DayIdentifier.string(from: date, calendar: calendar))
    }

    /// Toggles completion for `date`: complete becomes incomplete and vice
    /// versa.
    public mutating func toggleCompletion(on date: Date, calendar: Calendar = .current) {
        let key = DayIdentifier.string(from: date, calendar: calendar)
        if completedDayIdentifiers.contains(key) {
            completedDayIdentifiers.remove(key)
        } else {
            completedDayIdentifiers.insert(key)
        }
    }

    /// Whether `date` is marked complete.
    public func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDayIdentifiers.contains(DayIdentifier.string(from: date, calendar: calendar))
    }
}

/// Helpers for converting between `Date` and the normalized "yyyy-MM-dd"
/// day-identifier strings used for completion tracking.
public enum DayIdentifier {
    /// Builds a stable formatter. `DateFormatter` is not `Sendable`-cheap to
    /// share globally in a mutable way, so each call gets its own instance;
    /// this type is only used for infrequent, non-hot-path conversions.
    private static func formatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        formatter(calendar: calendar).string(from: date)
    }

    public static func date(from identifier: String, calendar: Calendar = .current) -> Date? {
        let parser = formatter(calendar: calendar)
        parser.isLenient = false
        guard let date = parser.date(from: identifier),
              parser.string(from: date) == identifier else {
            return nil
        }
        return date
    }
}
