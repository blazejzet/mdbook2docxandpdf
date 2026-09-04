// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "md2epub",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "md2epub",
            path: "Sources/md2epub"
        )
    ]
)
