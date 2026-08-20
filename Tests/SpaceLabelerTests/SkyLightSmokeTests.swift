import XCTest

@testable import SpaceLabeler

final class SkyLightSmokeTests: XCTestCase {

    /// If Apple removes or renames CGSMainConnectionID / CGSGetActiveSpace,
    /// dlsym resolution fails and currentSpaceID() returns nil. This test
    /// fails loudly on the macos-latest CI matrix row the first time the
    /// Xcode/runner image is rolled forward to a macOS that broke the private
    /// API. That early warning is the entire reason this test exists.
    func test_currentSpaceID_returnsNonNil() {
        let id = SkyLight.currentSpaceID()
        XCTAssertNotNil(
            id,
            "SkyLight private API symbol resolution failed — Apple may have changed CGSGetActiveSpace"
        )
    }

    /// The Space-enumeration symbols (CGSCopySpacesForDisplay,
    /// CGSCopyManagedDisplayForSpace, CGSSpaceGetType) power the "click a
    /// Space to jump to it" feature. Same failure-loudly-in-CI intent as the
    /// read-only symbols above.
    func test_switchSymbols_resolve() {
        XCTAssertTrue(
            SkyLight.switchSymbolsAvailable,
            "SkyLight switch symbols failed to resolve — Apple may have changed CGSCopySpacesForDisplay"
        )
    }

    /// End-to-end enumeration: the active Space must belong to a managed
    /// display whose user-space list actually contains it, and be ordered
    /// (so the Ctrl+N index mapping is meaningful).
    func test_currentSpace_isInDisplayUserSpaceList() {
        guard let current = SkyLight.currentSpaceID() else {
            return XCTFail("Cannot read current Space ID")
        }
        guard let uuid = SkyLight.displayUUID(for: current) else {
            return XCTFail("CGSCopyManagedDisplayForSpace returned nil")
        }
        let spaces = SkyLight.userSpaceIDs(onDisplay: uuid)
        XCTAssertFalse(spaces.isEmpty, "No user Spaces found on the active display")
        XCTAssertTrue(spaces.contains(current), "Active Space missing from its own display's user-space list")
    }
}
