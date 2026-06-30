import Foundation

/// A Census ZIP Code Tabulation Area code, e.g. `"94110"`.
///
/// ZCTAs are Census-derived approximations of USPS ZIP delivery areas. Per the locked
/// V1 product rules, user-facing copy calls these "ZIP-like patches" / "postal areas"
/// and never claims "official ZIP coverage". This type carries the raw 5-character code.
public struct ZCTACode: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String { value }

    public static func < (lhs: ZCTACode, rhs: ZCTACode) -> Bool {
        lhs.value < rhs.value
    }
}

/// A dense, stable integer index assigned to each ZCTA in the bundled geodata.
///
/// The bundled dataset assigns every ZCTA a contiguous index in `0..<count`. That index
/// is what the compact visited bitset stores, and what spatial lookups return. The mapping
/// `index <-> ZCTACode` lives in the bundled dataset and is stable for a given data vintage.
public typealias ZCTAIndex = Int
