import Foundation

/// Completion of a single region, derived from the visited bitset.
public struct RegionProgress: Sendable, Identifiable, Hashable {
    public let region: Region
    /// Weighted completion in `0...1` (sum of visited member weights).
    public let completion: Double
    /// Number of the region's member ZCTAs that have been visited.
    public let visitedZCTACount: Int
    /// Total member ZCTAs in the region.
    public let totalZCTACount: Int

    public var id: String { region.id }

    /// Any progress at all.
    public var isStarted: Bool { visitedZCTACount > 0 }

    /// Considered complete when every member ZCTA is visited. We key completeness off the
    /// count (exact) rather than the weighted sum (floating point) to avoid a region that
    /// reads "100%" while a tiny-weight ZCTA is still missing.
    public var isComplete: Bool { totalZCTACount > 0 && visitedZCTACount == totalZCTACount }

    /// Whole-percent completion for display (`87` → "87%").
    public var percentComplete: Int { Int((completion * 100).rounded()) }

    public init(region: Region, completion: Double, visitedZCTACount: Int, totalZCTACount: Int) {
        self.region = region
        self.completion = completion
        self.visitedZCTACount = visitedZCTACount
        self.totalZCTACount = totalZCTACount
    }
}

/// Aggregate completion across all regions of one kind (e.g. "12 of 58 counties touched").
public struct LevelSummary: Sendable, Hashable {
    public let kind: RegionKind
    public let totalRegions: Int
    public let startedRegions: Int
    public let completedRegions: Int
    /// Mean weighted completion across all regions of this kind, `0...1`.
    public let meanCompletion: Double

    public var startedPercent: Int {
        totalRegions == 0 ? 0 : Int((Double(startedRegions) / Double(totalRegions) * 100).rounded())
    }

    public init(kind: RegionKind, totalRegions: Int, startedRegions: Int,
                completedRegions: Int, meanCompletion: Double) {
        self.kind = kind
        self.totalRegions = totalRegions
        self.startedRegions = startedRegions
        self.completedRegions = completedRegions
        self.meanCompletion = meanCompletion
    }
}

/// Computes region completion from the visited bitset using precomputed weighted-overlap
/// tables. This is the runtime side of locked decision #6: **weighted sums, never spatial
/// intersection at runtime.** All geometry work happens once, offline, in the geo pipeline.
public struct RollupEngine: Sendable {

    public init() {}

    /// Completion for a single weighted region.
    public func progress(for weighted: WeightedRegion, visited: VisitedBitset) -> RegionProgress {
        var sum = 0.0
        var visitedCount = 0
        for member in weighted.members where visited.contains(member.zctaIndex) {
            sum += member.weight
            visitedCount += 1
        }
        // Weights are normalized offline to sum to 1.0, but clamp defensively so floating
        // point drift can never surface a >100% region to the user.
        let completion = min(max(sum, 0.0), 1.0)
        return RegionProgress(
            region: weighted.region,
            completion: completion,
            visitedZCTACount: visitedCount,
            totalZCTACount: weighted.totalZCTACount
        )
    }

    /// Completion for many regions, preserving input order.
    public func progress(for regions: [WeightedRegion], visited: VisitedBitset) -> [RegionProgress] {
        regions.map { progress(for: $0, visited: visited) }
    }

    /// Rolls a set of regions of one kind into a single summary line.
    public func summary(kind: RegionKind, progress: [RegionProgress]) -> LevelSummary {
        let started = progress.filter { $0.isStarted }.count
        let completed = progress.filter { $0.isComplete }.count
        let mean = progress.isEmpty ? 0 : progress.reduce(0) { $0 + $1.completion } / Double(progress.count)
        return LevelSummary(
            kind: kind,
            totalRegions: progress.count,
            startedRegions: started,
            completedRegions: completed,
            meanCompletion: mean
        )
    }
}
