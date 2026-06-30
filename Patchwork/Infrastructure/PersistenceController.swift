import Foundation
import SwiftData

/// The single persisted blob of user progress: the serialized visited-ZCTA bitset for one
/// dataset (locked decision #5/#8 — SwiftData, user state only, heavy geo bundled read-only).
@Model
final class MapStateRecord {
    /// Which bundled dataset this state belongs to (e.g. "sample"). Lets us migrate/reset
    /// cleanly if the geodata vintage changes. Uniqueness is enforced in code (one record per
    /// dataset) rather than via `@Attribute(.unique)`, which we avoid here.
    var datasetID: String
    /// `VisitedBitset.serialized()` output.
    var bitsetData: Data
    var updatedAt: Date

    init(datasetID: String, bitsetData: Data, updatedAt: Date = .now) {
        self.datasetID = datasetID
        self.bitsetData = bitsetData
        self.updatedAt = updatedAt
    }
}

/// One claim event, kept for the (non-punitive) timeline and "new this month" counters.
/// Cumulative and never-decreasing by design — there is no streak to break.
@Model
final class ClaimEventRecord {
    var zctaIndex: Int
    var code: String
    var timestamp: Date

    init(zctaIndex: Int, code: String, timestamp: Date = .now) {
        self.zctaIndex = zctaIndex
        self.code = code
        self.timestamp = timestamp
    }
}

/// Owns the SwiftData container. All data is local to the device; there is no CloudKit/iCloud
/// sync in V1 (locked exclusion).
struct PersistenceController {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([MapStateRecord.self, ClaimEventRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory,
                                        cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A corrupt local store should never hard-crash the app on launch; fall back to an
            // in-memory store so the user can still play and re-export.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                              cloudKitDatabase: .none)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
