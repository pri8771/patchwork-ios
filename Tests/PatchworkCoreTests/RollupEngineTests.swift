import XCTest
@testable import PatchworkCore

final class RollupEngineTests: XCTestCase {
    let engine = RollupEngine()

    /// A county made of three ZCTAs with area shares 0.5 / 0.3 / 0.2 (sum 1.0).
    private func sampleCounty() -> WeightedRegion {
        WeightedRegion(
            region: Region(id: "06075", name: "San Francisco", kind: .county, parentID: "06"),
            members: [
                RegionMember(zctaIndex: 0, weight: 0.5),
                RegionMember(zctaIndex: 1, weight: 0.3),
                RegionMember(zctaIndex: 2, weight: 0.2)
            ]
        )
    }

    func testNoProgress() {
        let county = sampleCounty()
        let visited = VisitedBitset(capacity: 3)
        let p = engine.progress(for: county, visited: visited)
        XCTAssertEqual(p.completion, 0.0, accuracy: 1e-9)
        XCTAssertEqual(p.visitedZCTACount, 0)
        XCTAssertEqual(p.totalZCTACount, 3)
        XCTAssertFalse(p.isStarted)
        XCTAssertFalse(p.isComplete)
        XCTAssertEqual(p.percentComplete, 0)
    }

    func testWeightedPartialProgress() {
        let county = sampleCounty()
        var visited = VisitedBitset(capacity: 3)
        visited.insert(0) // weight 0.5
        visited.insert(2) // weight 0.2
        let p = engine.progress(for: county, visited: visited)
        XCTAssertEqual(p.completion, 0.7, accuracy: 1e-9)
        XCTAssertEqual(p.visitedZCTACount, 2)
        XCTAssertTrue(p.isStarted)
        XCTAssertFalse(p.isComplete)
        XCTAssertEqual(p.percentComplete, 70)
    }

    func testFullCompletionUsesCountNotFloatingPoint() {
        // Weights that don't sum cleanly in floating point; completeness must key off count.
        let county = WeightedRegion(
            region: Region(id: "X", name: "X", kind: .county),
            members: (0..<7).map { RegionMember(zctaIndex: $0, weight: 1.0 / 7.0) }
        )
        var visited = VisitedBitset(capacity: 7)
        for i in 0..<7 { visited.insert(i) }
        let p = engine.progress(for: county, visited: visited)
        XCTAssertTrue(p.isComplete)
        XCTAssertEqual(p.visitedZCTACount, 7)
        XCTAssertLessThanOrEqual(p.completion, 1.0) // clamped, never >100%
        XCTAssertEqual(p.percentComplete, 100)
    }

    func testCompletionClampedToOne() {
        // Defensive: even if offline weights drift slightly above 1.0, runtime never exceeds 100%.
        let region = WeightedRegion(
            region: Region(id: "Y", name: "Y", kind: .state),
            members: [RegionMember(zctaIndex: 0, weight: 0.7),
                      RegionMember(zctaIndex: 1, weight: 0.45)]
        )
        var visited = VisitedBitset(capacity: 2)
        visited.insert(0); visited.insert(1)
        let p = engine.progress(for: region, visited: visited)
        XCTAssertEqual(p.completion, 1.0, accuracy: 1e-9)
    }

    func testLevelSummary() {
        let counties = [
            WeightedRegion(region: Region(id: "A", name: "A", kind: .county),
                           members: [RegionMember(zctaIndex: 0, weight: 1.0)]),
            WeightedRegion(region: Region(id: "B", name: "B", kind: .county),
                           members: [RegionMember(zctaIndex: 1, weight: 0.5),
                                     RegionMember(zctaIndex: 2, weight: 0.5)]),
            WeightedRegion(region: Region(id: "C", name: "C", kind: .county),
                           members: [RegionMember(zctaIndex: 3, weight: 1.0)])
        ]
        var visited = VisitedBitset(capacity: 4)
        visited.insert(0) // A complete
        visited.insert(1) // B half-started
        // C untouched
        let progress = engine.progress(for: counties, visited: visited)
        let summary = engine.summary(kind: .county, progress: progress)
        XCTAssertEqual(summary.totalRegions, 3)
        XCTAssertEqual(summary.startedRegions, 2)
        XCTAssertEqual(summary.completedRegions, 1)
        XCTAssertEqual(summary.meanCompletion, (1.0 + 0.5 + 0.0) / 3.0, accuracy: 1e-9)
    }

    func testProgressSnapshotNationwidePercent() {
        var visited = VisitedBitset(capacity: 1000)
        for i in 0..<250 { visited.insert(i) }
        let snapshot = ProgressSnapshot(patchesFilled: visited.count, patchesTotal: 1000, levels: [])
        XCTAssertEqual(snapshot.nationwidePercent, 25)
        XCTAssertEqual(snapshot.patchesFilled, 250)
    }
}
