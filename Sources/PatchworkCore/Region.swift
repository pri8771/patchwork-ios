import Foundation

/// The administrative levels Patchwork rolls completion up through, broad → narrow.
///
/// Locked V1 decision #6 names city/county/state rollups; `country` is the top of the
/// zoom-out reveal. `place` is a Census Place (incorporated city / town / CDP).
public enum RegionKind: String, Codable, Sendable, CaseIterable, Comparable {
    case country
    case state
    case county
    case place

    /// Broad (country) sorts before narrow (place) so UI can order levels consistently.
    private var order: Int {
        switch self {
        case .country: return 0
        case .state: return 1
        case .county: return 2
        case .place: return 3
        }
    }

    public static func < (lhs: RegionKind, rhs: RegionKind) -> Bool {
        lhs.order < rhs.order
    }

    /// Singular display noun, e.g. for "12 of 58 counties".
    public var singularNoun: String {
        switch self {
        case .country: return "country"
        case .state: return "state"
        case .county: return "county"
        case .place: return "city"
        }
    }

    public var pluralNoun: String {
        switch self {
        case .country: return "countries"
        case .state: return "states"
        case .county: return "counties"
        case .place: return "cities"
        }
    }
}

/// An administrative region the user can make progress against.
///
/// `id` is a stable identifier from the bundled dataset: country `"US"`, state FIPS (`"06"`),
/// county GEOID (`"06075"`), or place GEOID. `parentID` links a region to its containing
/// region one level up (place → county is approximate, so place's parent is the state).
public struct Region: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let kind: RegionKind
    public let parentID: String?

    public init(id: String, name: String, kind: RegionKind, parentID: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.parentID = parentID
    }
}

/// One ZCTA's contribution to a region, precomputed offline.
///
/// `weight` is the area-overlap share of the region covered by this ZCTA. For a given
/// region, member weights sum to ~1.0, so weighted completion is a plain sum of the
/// weights of visited members — no runtime spatial intersection (locked decision #6).
public struct RegionMember: Hashable, Codable, Sendable {
    public let zctaIndex: ZCTAIndex
    public let weight: Double

    public init(zctaIndex: ZCTAIndex, weight: Double) {
        self.zctaIndex = zctaIndex
        self.weight = weight
    }
}

/// A region together with its precomputed weighted ZCTA membership.
public struct WeightedRegion: Sendable, Identifiable {
    public let region: Region
    public let members: [RegionMember]

    public var id: String { region.id }
    public var totalZCTACount: Int { members.count }

    public init(region: Region, members: [RegionMember]) {
        self.region = region
        self.members = members
    }
}
