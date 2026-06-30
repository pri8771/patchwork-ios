import Foundation

/// A headline view of the user's whole map: total patches plus a summary per administrative
/// level. Drives the Progress screen and the (region-level, privacy-safe) share card.
///
/// This is a pure derivation from the visited bitset and the bundled region tables; it holds
/// no precise location history, so it is safe to render into a shareable image.
public struct ProgressSnapshot: Sendable {
    /// Total ZCTAs visited (the count of filled patches).
    public let patchesFilled: Int
    /// Total ZCTAs in the active dataset.
    public let patchesTotal: Int
    /// One summary per level present in the data, ordered broad → narrow.
    public let levels: [LevelSummary]

    public init(patchesFilled: Int, patchesTotal: Int, levels: [LevelSummary]) {
        self.patchesFilled = patchesFilled
        self.patchesTotal = patchesTotal
        self.levels = levels.sorted { $0.kind < $1.kind }
    }

    public func summary(for kind: RegionKind) -> LevelSummary? {
        levels.first { $0.kind == kind }
    }

    /// Whole-percent of all patches filled nationwide.
    public var nationwidePercent: Int {
        patchesTotal == 0 ? 0 : Int((Double(patchesFilled) / Double(patchesTotal) * 100).rounded())
    }

    /// Builds a snapshot from already-computed per-level progress.
    public static func build(
        visited: VisitedBitset,
        patchesTotal: Int,
        progressByKind: [RegionKind: [RegionProgress]],
        engine: RollupEngine = RollupEngine()
    ) -> ProgressSnapshot {
        let levels = progressByKind.map { kind, progress in
            engine.summary(kind: kind, progress: progress)
        }
        return ProgressSnapshot(
            patchesFilled: visited.count,
            patchesTotal: patchesTotal,
            levels: levels
        )
    }
}
