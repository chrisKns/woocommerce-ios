import XCTest
@testable import WooCommerce

class ApplicationLogViewModelTests: XCTestCase {
    func test_excluded_types() {
        let model = ApplicationLogViewModel(logText: "")
        let excludedTypes = model.excludedActivityTypes
        let expectedTypes: Set<UIActivity.ActivityType> = [
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .message,
            .print,
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .openInIBooks,
            .markupAsPDF
        ]
        XCTAssertEqual(excludedTypes, expectedTypes)
    }

    func test_log_line_parses_correct_date() {
        let logText = "2021/06/07 11:59:46:454  🔵 Tracked application_opened"
        let model = ApplicationLogViewModel(logText: logText)
        XCTAssertEqual(model.lines.count, 1)
        let line = model.lines[0]
        XCTAssertNotNil(line.date)
        XCTAssertEqual(line.text, "🔵 Tracked application_opened")
    }

    func test_log_line_does_not_parse_incorrect_date() {
        let logText = "2021/06/07  🔵 Tracked application_opened"
        let model = ApplicationLogViewModel(logText: logText)
        XCTAssertEqual(model.lines.count, 1)
        let line = model.lines[0]
        XCTAssertNil(line.date)
        XCTAssertEqual(line.text, "2021/06/07  🔵 Tracked application_opened")
    }

    func test_log_line_parses_no_date() {
        let logText = "🔵 Tracked application_opened"
        let model = ApplicationLogViewModel(logText: logText)
        XCTAssertEqual(model.lines.count, 1)
        let line = model.lines[0]
        XCTAssertNil(line.date)
        XCTAssertEqual(line.text, "🔵 Tracked application_opened")
    }
}
