// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "godot-text-format",
    products: [
        .library(name: "GodotTextFormat", targets: ["GodotTextFormat"]),
    ],
    targets: [
        .target(name: "GodotTextFormat", dependencies: ["ZstdDecoder"]),
        .target(name: "ZstdDecoder", exclude: ["LICENSE"]),
        .testTarget(
            name: "GodotTextFormatTests",
            dependencies: ["GodotTextFormat"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
