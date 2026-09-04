// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "md2docx",
    targets: [
        .executableTarget(
            name: "md2docx",
            path: "Sources/md2docx"
        )
    ]
)
