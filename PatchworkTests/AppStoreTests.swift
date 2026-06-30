import XCTest
import SwiftData
@testable import Patchwork
import PatchworkData

/// App-layer tests for the claim / inspect / persistence / export-import / reset flows. These run
/// against the real bundled sample geodata and an in-memory SwiftData store, with no network,
/// location, or StoreKit involvement (we call `loadGeo()` rather than full `bootstrap()`).
@MainActor
final class AppStoreTests: XCTestCase {

    /// Keeps PersistenceControllers (and thus their ModelContainers) alive for the test's
    /// lifetime. A ModelContext must not outlive its container; the production app retains it
    /// for the whole process via the App struct.
    private var retained: [PersistenceController] = []

    override func tearDown() {
        retained.removeAll()
        super.tearDown()
    }

    private func makeStore() async -> AppStore {
        let persistence = PersistenceController(inMemory: true)
        retained.append(persistence)
        let store = AppStore(modelContext: persistence.container.mainContext,
                             location: LocationService(),
                             store: StoreManager())
        await store.loadGeo()
        return store
    }

    func testLoadsBundledGeo() async {
        let store = await makeStore()
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(store.patchesTotal, 400)
        XCTAssertEqual(store.patchesFilled, 0)
    }

    func testClaimMarksNewThenAlreadyFilled() async {
        let store = await makeStore()
        store.claim(index: 5, recenterToPatch: false)
        if case .filledNew(let info) = store.lastOutcome {
            XCTAssertEqual(info.index, 5)
        } else { XCTFail("expected filledNew") }
        XCTAssertEqual(store.patchesFilled, 1)
        XCTAssertTrue(store.isClaimed(5))

        store.claim(index: 5, recenterToPatch: false)
        if case .alreadyFilled = store.lastOutcome {} else { XCTFail("expected alreadyFilled") }
        XCTAssertEqual(store.patchesFilled, 1) // no double count
    }

    func testInspectDoesNotClaim() async {
        let store = await makeStore()
        store.inspect(index: 10)
        XCTAssertEqual(store.inspectedPatch?.index, 10)
        XCTAssertFalse(store.isClaimed(10))
        XCTAssertEqual(store.patchesFilled, 0) // inspecting must never color a patch
    }

    func testExportImportRoundTrip() async {
        let store = await makeStore()
        for i in [1, 2, 3, 50, 120] { store.claim(index: i, recenterToPatch: false) }
        XCTAssertEqual(store.patchesFilled, 5)
        let export = store.exportData()
        XCTAssertEqual(export.zctaCodes.count, 5)

        // Fresh store imports the export and ends up with the same patches.
        let store2 = await makeStore()
        let imported = store2.importData(export)
        XCTAssertEqual(imported, 5)
        XCTAssertEqual(store2.patchesFilled, 5)
        XCTAssertTrue(store2.isClaimed(120))
        // Re-importing the same data adds nothing.
        XCTAssertEqual(store2.importData(export), 0)
    }

    func testResetClearsEverything() async {
        let store = await makeStore()
        for i in 0..<10 { store.claim(index: i, recenterToPatch: false) }
        XCTAssertEqual(store.patchesFilled, 10)
        store.resetAllProgress()
        XCTAssertEqual(store.patchesFilled, 0)
        XCTAssertTrue(store.recentClaims.isEmpty)
        XCTAssertEqual(store.snapshot?.patchesFilled, 0)
    }

    func testPersistenceAcrossInstances() async {
        // Two AppStores sharing one container: claims by the first are restored by the second.
        let persistence = PersistenceController(inMemory: true)
        let ctx = persistence.container.mainContext
        let a = AppStore(modelContext: ctx, location: LocationService(), store: StoreManager())
        await a.loadGeo()
        a.claim(index: 7, recenterToPatch: false)
        a.claim(index: 8, recenterToPatch: false)

        let b = AppStore(modelContext: ctx, location: LocationService(), store: StoreManager())
        await b.loadGeo()
        XCTAssertEqual(b.patchesFilled, 2)
        XCTAssertTrue(b.isClaimed(7))
        XCTAssertTrue(b.isClaimed(8))
    }

    func testSnapshotReflectsCountyCompletion() async {
        let store = await makeStore()
        guard let sf = store.geoStore?.region(id: "06075") else { return XCTFail("missing county") }
        for m in sf.members { store.claim(index: m.zctaIndex, recenterToPatch: false) }
        let county = store.progress(kind: .county).first { $0.region.id == "06075" }
        XCTAssertEqual(county?.isComplete, true)
        XCTAssertEqual(county?.percentComplete, 100)
    }
}
