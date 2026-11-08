import XCTest
@testable import Indxe

final class RadialActionTests: XCTestCase {
    func testShortcutPayloadPreservesKeyAndModifiers() {
        let payload = ActionPayload.shortcut(
            keyCode: 8,
            flags: [.maskCommand, .maskShift]
        )

        XCTAssertEqual(payload.type, .keyShortcut)
        XCTAssertEqual(payload.keyCode, 8)
        XCTAssertTrue(payload.cgFlags.contains(.maskCommand))
        XCTAssertTrue(payload.cgFlags.contains(.maskShift))
        XCTAssertEqual(payload.humanReadableShortcut, "⇧⌘C")
    }

    func testPayloadDecodesLegacyTypeNames() throws {
        let json = """
        {
          "type": "Commande Shell",
          "keyCode": 0,
          "modifiersRaw": 0,
          "scriptOrCommand": "echo test"
        }
        """

        let payload = try JSONDecoder().decode(ActionPayload.self, from: Data(json.utf8))

        XCTAssertEqual(payload.type, .shellCommand)
        XCTAssertEqual(payload.scriptOrCommand, "echo test")
        XCTAssertEqual(payload.humanReadableShortcut, "Shell")
    }

    func testThemesExposeStableIdentifiers() {
        XCTAssertEqual(RingTheme.allCases.map(\.id), [
            "cyrex_crimson",
            "midnight_vanilla",
            "swiss_minimal",
            "terminal_matrix",
            "frost_glass"
        ])
    }
}
