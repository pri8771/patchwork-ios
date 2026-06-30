import XCTest
@testable import PatchworkCore

final class PatchPaletteTests: XCTestCase {

    func testDeterministic() {
        XCTAssertEqual(PatchPalette.color(for: 42), PatchPalette.color(for: 42))
        XCTAssertNotEqual(PatchPalette.color(for: 0).hue, PatchPalette.color(for: 1).hue)
    }

    func testValuesInRange() {
        for index in stride(from: 0, to: 5000, by: 13) {
            let c = PatchPalette.color(for: index)
            for v in [c.hue, c.saturation, c.brightness, c.red, c.green, c.blue] {
                XCTAssertGreaterThanOrEqual(v, 0.0)
                XCTAssertLessThanOrEqual(v, 1.0)
            }
        }
    }

    func testSuccessiveHuesAreWellSeparated() {
        // Golden-angle spread should keep consecutive patches far apart on the wheel.
        for index in 0..<200 {
            let a = PatchPalette.color(for: index).hue
            let b = PatchPalette.color(for: index + 1).hue
            let delta = min(abs(a - b), 1 - abs(a - b)) // circular distance
            XCTAssertGreaterThan(delta, 0.1, "hues too close at index \(index)")
        }
    }

    func testHSBToRGBKnownColors() {
        // Pure red: hue 0, full sat/bri.
        let red = PatchColor(hue: 0, saturation: 1, brightness: 1)
        XCTAssertEqual(red.red, 1, accuracy: 1e-9)
        XCTAssertEqual(red.green, 0, accuracy: 1e-9)
        XCTAssertEqual(red.blue, 0, accuracy: 1e-9)
        // Gray: zero saturation.
        let gray = PatchColor(hue: 0.4, saturation: 0, brightness: 0.5)
        XCTAssertEqual(gray.red, 0.5, accuracy: 1e-9)
        XCTAssertEqual(gray.green, 0.5, accuracy: 1e-9)
        XCTAssertEqual(gray.blue, 0.5, accuracy: 1e-9)
    }
}
