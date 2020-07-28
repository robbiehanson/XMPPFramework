// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "XMPPFramework",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v8),
        .tvOS(.v9)
    ],
    products: [
        .library(
            name: "XMPPFramework",
            targets: ["XMPPFramework"]
        ),
        .library(
            name: "XMPPFrameworkSwift",
            targets: ["XMPPFrameworkSwift"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.6.1")),
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket.git", .upToNextMajor(from: "7.6.4")),
        .package(url: "https://github.com/karimhm/KissXML.git", .branch("swift-pm")),
        .package(url: "https://github.com/karimhm/libidn-framework.git", .branch("swift_pm"))
    ],
    targets: [
        .target(
            name: "XMPPFramework",
            dependencies: [
                "CocoaLumberjack",
                "CocoaAsyncSocket",
                "KissXML",
                "libidn"
            ],
            path: ".",
            exclude: [
                "Swift",
                "Xcode",
            ],
            publicHeadersPath: "include/XMPPFramework",
            linkerSettings: [
                .linkedLibrary("xml2"),
                .linkedLibrary("resolv")
            ]
        ),
        .target(
            name: "XMPPFrameworkSwift",
            dependencies: [
                "XMPPFramework",
                "CocoaLumberjackSwift"
            ],
            path: "Swift"
        ),
        .target(
            name: "XMPPFrameworkTestsShared",
            dependencies: [
                "XMPPFramework"
            ],
            path: "Xcode/Testing-Shared",
            sources: [
                "XMPPMockStream.m"
            ],
            publicHeadersPath: "."
        ),
        .testTarget(
            name: "XMPPFrameworkTests",
            dependencies: [
                "XMPPFramework",
                "XMPPFrameworkTestsShared"
            ],
            path: "Xcode/Testing-Shared",
            exclude: [
                "XMPPMockStream.m",
                "XMPPvCardTests.m",
                "XMPPRoomLightCoreDataStorageTests.m",
                "XMPPBookmarksTests.swift",
                "XMPPPushTests.swift",
                "XMPPStanzaIdTests.swift",
                "XMPPSwift.swift"
            ]
        ),
        .testTarget(
            name: "XMPPFrameworkSwiftTests",
            dependencies: [
                "XMPPFramework",
                "XMPPFrameworkSwift",
                "XMPPFrameworkTestsShared"
            ],
            path: "Xcode",
            exclude: [
                "XMPPFrameworkTests-Bridging-Header.h"
            ],
            sources: [
                "Testing-Shared/XMPPBookmarksTests.swift",
                "Testing-Shared/XMPPPushTests.swift",
                "Testing-Shared/XMPPStanzaIdTests.swift",
                "Testing-Shared/XMPPSwift.swift",
                "Testing-Swift/XMPPBookmarksModuleTests.swift",
                "Testing-Swift/XMPPPresenceTests.swift",
                "Testing-Swift/XMPPvCardTempTests.swift"
            ]
        )
    ]
)
