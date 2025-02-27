// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
//  Package.swift
//
//  Created by Dave Carlson on 8/8/19.

import PackageDescription

let package = Package(
    name: "SMART",
	platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "SMART",
            targets: ["SMART"]),
    ],
    dependencies: [
        .package(url: "https://github.com/breatheai/Swift-FHIR.git", from: "4.3.0"),
        .package(url: "https://github.com/p2/OAuth2.git", from: "5.1.0"),
    ],
    targets: [
		.target(
			name: "SMART",
			dependencies: [
				.product(name: "OAuth2"),
				.product(name: "FHIR"),
			],
			path: "Sources",
			sources: ["SMART", "Client", "iOS", "macOS"]),
        .testTarget(
            name: "ClientTests",
            dependencies: ["SMART"]),
        .testTarget(
            name: "ServerTests",
            dependencies: ["SMART"]),
    ],
    swiftLanguageModes: [.version("5.10"), .version("6")]
)


func testDependencies() -> [PackageDescription.Target.Dependency] {
    #if os(macOS) || os(iOS)
        [
            "SMART",
            .product(name: "FHIR", package: "Swift-FHIR"),
            .product(name: "OAuth2", package: "OAuth2"),
        ]
    #endif
}
