// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Qingli",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Qingli", targets: ["Qingli"])],
    targets: [
        .executableTarget(name: "Qingli"),
    ]
)
