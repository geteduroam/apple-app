import XCTest
import XMLCoder
import CustomDump
@testable import Models

final class LocalizedEntryTests: XCTestCase {
    
    func testLocalizationWithNilLanguage() throws {
        let sut = [
            LocalizedEntry(language: nil, value: "No lang value"),
            LocalizedEntry(language: "nl", value: "NL value")
        ]
        
        XCTAssertEqual("No lang value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
    }
    
    func testLocalizationWithAnyLanguage() throws {
        let sut = [
            LocalizedEntry(language: "any", value: "No lang value"),
            LocalizedEntry(language: "nl", value: "NL value")
        ]
        
        XCTAssertEqual("No lang value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
    }
    
    func testLocalizationWithoutAnyLanguage() throws {
        let sut = [
            LocalizedEntry(language: "nl", value: "NL value"),
            LocalizedEntry(language: "dk", value: "DK value")
        ]
        
        XCTAssertEqual("NL value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
        XCTAssertEqual("DK value", sut.localized(for: "dk"))
    }
    
    func testLocalizationWithSingleLanguage() throws {
        let sut = [
            LocalizedEntry(language: "nl", value: "NL value")
        ]
        
        XCTAssertEqual("NL value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
        XCTAssertEqual("NL value", sut.localized(for: "dk"))
    }

}
