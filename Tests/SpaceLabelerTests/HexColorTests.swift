import AppKit
import SwiftUI
import XCTest

@testable import SpaceLabeler

final class HexColorTests: XCTestCase {

    func test_validHex_parsesCorrectly() {
        // "#FF6B6B" = (255, 107, 107)
        let c1 = NSColor(hex: "#FF6B6B")?.usingColorSpace(.sRGB)
        XCTAssertNotNil(c1)
        XCTAssertEqual(c1?.redComponent ?? -1, 255.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c1?.greenComponent ?? -1, 107.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c1?.blueComponent ?? -1, 107.0 / 255.0, accuracy: 0.01)

        XCTAssertNotNil(NSColor(hex: "4ECDC4"), "should parse hex without leading #")
        XCTAssertNotNil(NSColor(hex: "#ff6b6b"), "should accept lowercase")
        XCTAssertNotNil(NSColor(hex: "#Ff6B6b"), "should accept mixed case")
    }

    func test_invalidHex_returnsNil() {
        XCTAssertNil(NSColor(hex: ""))
        XCTAssertNil(NSColor(hex: "#"))
        XCTAssertNil(NSColor(hex: "ABC"))  // too short
        XCTAssertNil(NSColor(hex: "#12345678"))  // too long
        XCTAssertNil(NSColor(hex: "#ZZZZZZ"))  // non-hex chars
        XCTAssertNil(NSColor(hex: "   "))  // whitespace only
    }

    func test_bothExtensions_agree() {
        // NSColor(hex:) (in StatusItemController.swift) and Color(hex:) (in EditorPopover.swift)
        // are duplicated. This test guards against drift between the two implementations.
        let cases = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#000000", "#FFFFFF"]

        for hex in cases {
            guard let ns = NSColor(hex: hex)?.usingColorSpace(.sRGB) else {
                XCTFail("NSColor failed to parse \(hex)")
                continue
            }
            guard let swiftUI = Color(hex: hex) else {
                XCTFail("SwiftUI Color failed to parse \(hex)")
                continue
            }
            guard let bridged = NSColor(swiftUI).usingColorSpace(.sRGB) else {
                XCTFail("Could not bridge SwiftUI Color for \(hex)")
                continue
            }

            XCTAssertEqual(ns.redComponent, bridged.redComponent, accuracy: 0.01, "r mismatch for \(hex)")
            XCTAssertEqual(ns.greenComponent, bridged.greenComponent, accuracy: 0.01, "g mismatch for \(hex)")
            XCTAssertEqual(ns.blueComponent, bridged.blueComponent, accuracy: 0.01, "b mismatch for \(hex)")
        }
    }
}
