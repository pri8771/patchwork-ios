// swift-tools-version: 5.9
import PackageDescription

// Patchwork V1 core libraries.
//
// These targets hold all pure, UI-independent domain, geometry, and data logic so
// they can be unit-tested with `swift test` on macOS without an Xcode/iOS app target.
// The iOS app (generated via xcodegen, see project.yml) links these libraries.
//
// Locked V1 constraints honored here:
//  - No third-party dependencies. SQLite access uses the system `sqlite3` library only.
//  - All geography/location processing is on device; nothing in here touches the network.
let package = Package(
    name: "Patchwork",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PatchworkCore", targets: ["PatchworkCore"]),
        .library(name: "PatchworkGeo", targets: ["PatchworkGeo"]),
        .library(name: "PatchworkData", targets: ["PatchworkData"])
    ],
    targets: [
        // Pure domain: ZCTA identity, visited bitset, regions, rollups, patch colors.
        .target(
            name: "PatchworkCore"
        ),
        // Pure geometry: coordinates, polygons, point-in-polygon, packed R-tree, resolver.
        .target(
            name: "PatchworkGeo"
        ),
        // Persistence/geodata: bundled SQLite reader, geodata repository, fixtures.
        .target(
            name: "PatchworkData",
            dependencies: ["PatchworkCore", "PatchworkGeo"],
            resources: [
                .copy("Resources/patchwork-sample.sqlite")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "PatchworkCoreTests",
            dependencies: ["PatchworkCore"]
        ),
        .testTarget(
            name: "PatchworkGeoTests",
            dependencies: ["PatchworkGeo"]
        ),
        .testTarget(
            name: "PatchworkDataTests",
            dependencies: ["PatchworkData", "PatchworkCore", "PatchworkGeo"]
        )
    ]
)
