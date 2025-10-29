// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-interfazzle",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "Interfazzle",
      targets: ["Interfazzle"]
    ),
    .executable(
      name: "interfazzle",
      targets: ["interfazzle"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.3"),
  ],
  targets: [
    .target(
      name: "Interfazzle",
      dependencies: []
    ),
    .executableTarget(
      name: "interfazzle",
      dependencies: [
        "Interfazzle",
        .product(name: "SwiftCLI", package: "SwiftCLI"),
      ]
    ),
    .testTarget(
      name: "InterfazzleTests",
      dependencies: ["Interfazzle"]
    ),
  ]
)
