import XCTest
@testable import Indxe

final class RingStateTests: XCTestCase {
    func testCursorInsideDeadZoneClearsSelection() {
        let state = makeState(sliceCount: 4)

        state.selectedIndex = 2
        let triggered = state.updateCursorPosition(CGPoint(x: 10, y: 10))

        XCTAssertFalse(triggered)
        XCTAssertNil(state.selectedIndex)
    }

    func testCursorSelectsTheTopSlice() {
        let state = makeState(sliceCount: 4)
        ProfileStore.shared.instantHoverTrigger = false

        let triggered = state.updateCursorPosition(CGPoint(x: 0, y: 100))

        XCTAssertFalse(triggered)
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testInstantHoverTriggerReturnsTrueOutsideTriggerRadius() {
        let state = makeState(sliceCount: 4)
        ProfileStore.shared.instantHoverTrigger = true

        defer { ProfileStore.shared.instantHoverTrigger = false }

        let triggered = state.updateCursorPosition(CGPoint(x: 0, y: 100))

        XCTAssertTrue(triggered)
        XCTAssertEqual(state.selectedIndex, 0)
    }

    private func makeState(sliceCount: Int) -> RingState {
        let state = RingState()
        state.centerScreenPoint = .zero
        state.activeProfile = AppProfile(
            bundleIdentifier: "com.indxe.tests",
            displayName: "Tests",
            appPath: nil,
            slices: (0..<sliceCount).map { index in
                RadialSlice(
                    title: "Slice \(index)",
                    systemImage: "circle",
                    accentColorHex: 0,
                    payload: .shell("")
                )
            }
        )
        return state
    }
}
