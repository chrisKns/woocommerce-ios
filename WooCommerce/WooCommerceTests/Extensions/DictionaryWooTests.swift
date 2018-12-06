import XCTest


/// Dictionary+Woo Unit Tests
///
class DictionaryWooTests: XCTestCase {

    private let sampleKey = "key"

    /// Verifies that a Float is effectively returned as a String Value, when retrieved via `string(forKey:)`
    ///
    func testStringForKeyReturnsStringValueWheneverTheValueIsStoredAsFloat() {
        let sample = [sampleKey: 3.14]
        XCTAssertEqual(sample.string(forKey: sampleKey), "3.14")
    }

    /// Verifies that an Integer is effectively returned as a String Value, when retrieved via `string(forKey:)`
    ///
    func testStringForKeyReturnsStringValueWheneverTheValueIsStoredAsInteger() {
        let sample = [sampleKey: 314]
        XCTAssertEqual(sample.string(forKey: sampleKey), "314")
    }

    /// Verifies that a String is effectively returned as a String Value, when retrieved via `string(forKey:)`
    ///
    func testStringForKeyReturnsStringValueWheneverTheValueIsStoredAsString() {
        let sample = [sampleKey: "3.14"]
        XCTAssertEqual(sample.string(forKey: sampleKey), "3.14")
    }

    /// Verifies that an Integer is effectively returned as an Integer value, when retrieved via `integer(forKey:)`
    ///
    func testIntegerForKeyReturnsIntegerValueWheneverTheValueIsStoredAsInteger() {
        let sample = [sampleKey: 314]
        XCTAssertEqual(sample.integer(forKey: sampleKey), 314)
    }

    /// Verifies that an String is effectively returned as an Integer value, when retrieved via `integer(forKey:)`
    ///
    func testIntegerForKeyReturnsIntegerValueWheneverTheValueIsStoredAsString() {
        let sample = [sampleKey: "314"]
        XCTAssertEqual(sample.integer(forKey: sampleKey), 314)
    }

    /// Verifies that an Float is effectively returned as an Integer value, when retrieved via `integer(forKey:)`
    ///
    func testIntegerForKeyReturnsIntegerValueWheneverTheValueIsStoredAsFloat() {
        let sample = [sampleKey: 314.00]
        XCTAssertEqual(sample.integer(forKey: sampleKey), 314)
    }
}
