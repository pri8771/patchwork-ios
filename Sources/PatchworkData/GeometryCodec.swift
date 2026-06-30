import Foundation
import PatchworkGeo

/// Decodes the compact binary polygon blobs produced by the offline pipeline
/// (`Tools/geo_build/geo_format.py`). The format is mirrored exactly here; see that file for
/// the byte layout. Decoding is hand-rolled (no reflection) so it stays fast and allocation-lean
/// while loading thousands of ZCTAs at launch.
enum GeometryCodec {
    enum DecodeError: Error, Equatable {
        case tooShort
        case unsupportedVersion(UInt8)
        case truncated
    }

    static func decode(_ blob: [UInt8]) throws -> [GeoPolygon] {
        var cursor = 0
        func u8() throws -> UInt8 {
            guard cursor + 1 <= blob.count else { throw DecodeError.truncated }
            defer { cursor += 1 }
            return blob[cursor]
        }
        func u16() throws -> Int {
            guard cursor + 2 <= blob.count else { throw DecodeError.truncated }
            let v = Int(blob[cursor]) | (Int(blob[cursor + 1]) << 8)
            cursor += 2
            return v
        }
        func u32() throws -> Int {
            guard cursor + 4 <= blob.count else { throw DecodeError.truncated }
            let v = Int(blob[cursor]) | (Int(blob[cursor + 1]) << 8)
                  | (Int(blob[cursor + 2]) << 16) | (Int(blob[cursor + 3]) << 24)
            cursor += 4
            return v
        }
        func f64() throws -> Double {
            guard cursor + 8 <= blob.count else { throw DecodeError.truncated }
            var bits: UInt64 = 0
            for i in 0..<8 { bits |= UInt64(blob[cursor + i]) << (8 * i) }
            cursor += 8
            return Double(bitPattern: bits)
        }

        guard blob.count >= 4 else { throw DecodeError.tooShort }
        let version = try u8()
        guard version == 1 else { throw DecodeError.unsupportedVersion(version) }
        _ = try u8() // reserved
        let polygonCount = try u16()

        var polygons: [GeoPolygon] = []
        polygons.reserveCapacity(polygonCount)
        for _ in 0..<polygonCount {
            let ringCount = try u16()
            var exterior: [Point2D] = []
            var holes: [[Point2D]] = []
            for ring in 0..<ringCount {
                let pointCount = try u32()
                var pts: [Point2D] = []
                pts.reserveCapacity(pointCount)
                for _ in 0..<pointCount {
                    let x = try f64()
                    let y = try f64()
                    pts.append(Point2D(x: x, y: y))
                }
                if ring == 0 { exterior = pts } else { holes.append(pts) }
            }
            polygons.append(GeoPolygon(exterior: exterior, holes: holes))
        }
        return polygons
    }

    static func decode(_ data: Data) throws -> [GeoPolygon] {
        try decode([UInt8](data))
    }
}
