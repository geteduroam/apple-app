import XCTest

final class Screenshots: XCTestCase {
    
    enum Language: String {
        case en
        case nl
    }
    
    enum Scenario: String, CaseIterable {
        case main
        case search
        case connect
        case connected
        
        var appearance: XCUIDevice.Appearance {
            switch self {
            case .main:
                .light
            case .search:
                .light
            case .connect:
                .light
            case .connected:
                .dark
            }
        }
    }
    
#if os(iOS)
    func testScreenshots() throws {
        let screenshotsFolder = URL(fileURLWithPath: "/Users/jkool/geteduroam-screenshots")
        let simulator = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"]!.replacingOccurrences(of: " ", with: "_")
        let host = ProcessInfo().environment["XCTestBundlePath"]!.contains("getgovroam") ? "getgovroam" : "geteduroam"
        let languages: [Language] = [.en, .nl]
        let scenarios = Scenario.allCases
        for language in languages {
            for (index, scenario) in scenarios.enumerated() {
                XCUIDevice.shared.appearance = scenario.appearance
                
                
                let app = XCUIApplication()
                app.launchArguments += ["-AppleLanguages", "(\(language))"]
                app.launchArguments += ["-AppleLocale", "\"\(language)\""]
                app.launchArguments += ["-Scenario", "\(scenario)"]
                app.launch()
                
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                let name = "\(host)-\(simulator)-\(language)-\(index)-\(scenario)"
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
                
                let path = screenshotsFolder.appendingPathComponent("\(name).png")
                try screenshot.image.pngData()?.write(to: path, options: .atomic)
            }
        }
    }
#elseif os(macOS)
    @MainActor func testScreenshots() throws {
        let languages: [Language] = [.en, .nl]
        let scenarios = Scenario.allCases
        for language in languages {
            for (index, scenario) in scenarios.enumerated() {
                XCUIDevice.shared.appearance = scenario.appearance
                
                let app = XCUIApplication()
                app.launchArguments += ["-AppleLanguages", "(\(language))"]
                app.launchArguments += ["-AppleLocale", "\"\(language)\""]
                app.launchArguments += ["-Scenario", "\(scenario)"]
                app.launch()
                
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                let name = "mac-\(language)-\(index)-\(scenario)"
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
                
                // Due to sandbox restrictions writing to disk doesn't work on macOS, navigate to the test results and find the attachments there
            }
        }
    }
#endif
}

#if os(macOS)
extension NSImage {
    func pngData() -> Data? {
        guard let imageData = tiffRepresentation, let imageRep = NSBitmapImageRep(data: imageData) else {
            return nil
        }
        return imageRep.representation(using: .png, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0])
    }
}
#endif
