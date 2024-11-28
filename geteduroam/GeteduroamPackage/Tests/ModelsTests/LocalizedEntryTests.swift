import XCTest
import XMLCoder
import CustomDump
@testable import Models

final class LocalizedEntryTests: XCTestCase {
    
    func testLocalizationWithNilLanguage() throws {
        let sut = [
            LocalizedEntry(language: nil, display: "No lang value"),
            LocalizedEntry(language: "nl", display: "NL value")
        ]
        
        XCTAssertEqual("No lang value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
    }
    
    func testLocalizationWithAnyLanguage() throws {
        let sut = [
            LocalizedEntry(language: "any", display: "No lang value"),
            LocalizedEntry(language: "nl", display: "NL value")
        ]
        
        XCTAssertEqual("No lang value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
    }
    
    func testLocalizationWithoutAnyLanguage() throws {
        let sut = [
            LocalizedEntry(language: "nl", display: "NL value"),
            LocalizedEntry(language: "dk", display: "DK value")
        ]
        
        XCTAssertEqual("NL value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
        XCTAssertEqual("DK value", sut.localized(for: "dk"))
    }
    
    func testLocalizationWithSingleLanguage() throws {
        let sut = [
            LocalizedEntry(language: "nl", display: "NL value")
        ]
        
        XCTAssertEqual("NL value", sut.localized(for: "en"))
        XCTAssertEqual("NL value", sut.localized(for: "nl"))
        XCTAssertEqual("NL value", sut.localized(for: "dk"))
    }

}
