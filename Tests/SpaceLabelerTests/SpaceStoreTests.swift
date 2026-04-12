import XCTest

@testable import SpaceLabeler

final class SpaceStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SpaceLabelerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_labelForUnknownID_autoAssignsAndPersists() {
        let store = SpaceStore(defaults: defaults)
        let label = store.label(for: 42)

        XCTAssertEqual(label.name, "Space 1")
        XCTAssertFalse(label.colorHex.isEmpty)
        XCTAssertTrue(label.colorHex.hasPrefix("#"))
        XCTAssertNotNil(defaults.data(forKey: "SpaceLabels.v1"))
    }

    func test_update_persistsAcrossInstances() {
        let store1 = SpaceStore(defaults: defaults)
        _ = store1.label(for: 99)
        store1.update(99, SpaceLabel(name: "Code", colorHex: "#4ECDC4"))

        let store2 = SpaceStore(defaults: defaults)
        let loaded = store2.labels[99]

        XCTAssertEqual(loaded?.name, "Code")
        XCTAssertEqual(loaded?.colorHex, "#4ECDC4")
    }

    func test_autoAssign_rotatesPaletteDeterministically() {
        let store = SpaceStore(defaults: defaults)
        let palette = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#C7B8EA", "#FFA07A"]

        // autoAssign computes n = labels.count + 1 then picks palette[n % palette.count].
        // Six successive assignments from an empty store yield indices [1,2,3,4,5,0].
        let expectedIndices = [1, 2, 3, 4, 5, 0]

        for (i, expectedIdx) in expectedIndices.enumerated() {
            let label = store.label(for: UInt64(100 + i))
            XCTAssertEqual(label.colorHex, palette[expectedIdx], "iteration \(i)")
        }
    }

    func test_load_handlesCorruptedDefaults() {
        defaults.set(Data([0xFF, 0x00, 0xFF, 0x00]), forKey: "SpaceLabels.v1")

        let store = SpaceStore(defaults: defaults)

        XCTAssertTrue(store.labels.isEmpty, "Store should come up empty when defaults are corrupted, not crash")
    }
}
