import XCTest
@testable import HabitTrackerCore

final class DayIdentifierTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    func testCanonicalLeapDayRoundTrips() {
        let date = DayIdentifier.date(from: "2024-02-29", calendar: calendar)
        XCTAssertNotNil(date)
        XCTAssertEqual(DayIdentifier.string(from: date!, calendar: calendar), "2024-02-29")
    }
    func testInvalidAndNoncanonicalDaysAreRejected() {
        for value in ["2023-02-29", "2024-02-30", "2024-13-01", "2024-2-3", "2024-02-03 trailing", "", " 2024-02-03"] {
            XCTAssertNil(DayIdentifier.date(from: value, calendar: calendar), value)
        }
    }
}
