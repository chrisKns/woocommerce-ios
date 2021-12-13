import XCTest
@testable import Yosemite

final class MediaFileManagerTests: XCTestCase {
    func testCreatingLocalMediaURL() {
        do {
            let basename = "media-service-test-sample"
            let pathExtension = "jpg"
            let expected = "\(basename).\(pathExtension)"

            let fileManager = MediaFileManager()

            var url = try fileManager.createLocalMediaURL(filename: basename, fileExtension: pathExtension)
            XCTAssertEqual(url.lastPathComponent, expected)

            url = try fileManager.createLocalMediaURL(filename: expected, fileExtension: pathExtension)
            XCTAssertEqual(url.lastPathComponent, expected)

            url = try fileManager.createLocalMediaURL(filename: basename + ".png", fileExtension: pathExtension)
            XCTAssertEqual(url.lastPathComponent, expected)

            url = try fileManager.createLocalMediaURL(filename: basename, fileExtension: nil)
            XCTAssertEqual(url.lastPathComponent, basename)

            url = try fileManager.createLocalMediaURL(filename: expected, fileExtension: nil)
            XCTAssertEqual(url.lastPathComponent, expected)
        } catch {
            XCTFail("Error creating local media URL: \(error)")
        }
    }

    func testRemovingLocalMediaAtURL() {
        do {
            let fileManager = MockFileManager()
            let data = Data()
            let mediaFileManager = MediaFileManager(fileManager: fileManager)
            let localURL = try mediaFileManager.createLocalMediaURL(filename: "hello", fileExtension: "txt")

            XCTAssertTrue(fileManager.createFile(atPath: localURL.path, contents: data))
            XCTAssertTrue(fileManager.fileExists(atPath: localURL.path))

            try mediaFileManager.removeLocalMedia(at: localURL)
            XCTAssertFalse(fileManager.fileExists(atPath: localURL.path))
        } catch {
            XCTFail("\(error)")
        }
    }
}
