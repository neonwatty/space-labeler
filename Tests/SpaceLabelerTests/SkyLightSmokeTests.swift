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
}
