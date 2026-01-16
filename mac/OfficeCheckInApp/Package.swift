// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OfficeCheckIn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OfficeCheckIn", targets: ["OfficeCheckIn"])
    ],
    targets: [
        .executableTarget(
            name: "OfficeCheckIn",
            path: "Sources"
        )
    ]
)

