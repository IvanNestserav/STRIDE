// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PacingCore", products: [.library(name: "PacingCore", targets: ["PacingCore"])], targets: [.target(name: "PacingCore"), .testTarget(name: "PacingCoreTests", dependencies: ["PacingCore"])])
