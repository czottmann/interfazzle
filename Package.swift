// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "interfazzle",
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
      targets: ["InterfazzleCLI"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.3"),
  ],
  targets: [
    .target(
      name: "Interfazzle",
      dependencies: [],
      exclude: ["README.md"]
    ),
    .executableTarget(
      name: "InterfazzleCLI",
      dependencies: [
        "Interfazzle",
        .product(name: "SwiftCLI", package: "SwiftCLI"),
      ],
      path: "Sources/InterfazzleCLI",
      exclude: ["README.md"]
    ),
    .testTarget(
      name: "InterfazzleTests",
      dependencies: ["Interfazzle"],
      exclude: ["README.md"]
    ),
  ]
)
