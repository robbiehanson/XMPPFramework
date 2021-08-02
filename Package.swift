// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "XMPPFramework",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v9),
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
        .package(name: "CocoaLumberjack", url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.6.1")),
        .package(name: "CocoaAsyncSocket", url: "https://github.com/robbiehanson/CocoaAsyncSocket.git", .upToNextMajor(from: "7.6.4")),
        .package(name: "KissXML", url: "https://github.com/robbiehanson/KissXML.git", .upToNextMajor(from: "5.3.3")),
        .package(name: "libidn", url: "https://github.com/chrisballinger/libidn-framework.git", .upToNextMajor(from: "1.35.1"))
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
                "README.md",
                "copying.txt",
                "Cartfile.resolved",
                "xmppframework.png",
                "Cartfile",
                "Core/Info.plist",
                "XMPPFramework.podspec"
            ],
            resources: [
                .process("Extensions/Roster/CoreDataStorage/XMPPRoster.xcdatamodel"),
                .process("Extensions/XEP-0045/CoreDataStorage/XMPPRoom.xcdatamodeld"),
                .process("Extensions/XEP-0045/HybridStorage/XMPPRoomHybrid.xcdatamodeld"),
                .process("Extensions/XEP-0054/CoreDataStorage/XMPPvCard.xcdatamodeld"),
                .process("Extensions/XEP-0115/CoreDataStorage/XMPPCapabilities.xcdatamodel"),
                .process("Extensions/XEP-0136/CoreDataStorage/XMPPMessageArchiving.xcdatamodeld"),
                .process("Extensions/XMPPMUCLight/CoreDataStorage/XMPPRoomLight.xcdatamodel")
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
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack")
            ],
            path: "Swift",
            exclude: [
                "XMPPFrameworkSwift-Info.plist",
                "XMPPFrameworkSwift.h"
            ]
        ),
        .target(
            name: "XMPPFrameworkTestsShared",
            dependencies: [
                "XMPPFramework"
            ],
            path: "Xcode/Testing-Shared",
            exclude: [
                "Info.plist",
                "XMPPvCardTests.m",
                "XMPPStanzaIdTests.swift",
                "OMEMOServerTests.m",
                "XMPPDelayedDeliveryTests.m",
                "XMPPMessageDeliveryReceiptsTests.m",
                "XMPPHTTPFileUploadTests.m",
                "XMPPRoomLightTests.m",
                "OMEMOModuleTests.m",
                "XMPPPushTests.swift",
                "EncodeDecodeTest.m",
                "XMPPOutOfBandResourceMessagingTests.m",
                "XMPPRoomLightCoreDataStorageTests.m",
                "XMPPMessageArchiveManagementTests.m",
                "CapabilitiesHashingTest.m",
                "XMPPMUCLightTests.m",
                "OMEMOElementTests.m",
                "XMPPURITests.m",
                "XMPPSwift.swift",
                "XMPPBookmarksTests.swift",
                "XMPPOneToOneChatTests.m",
                "OMEMOTestStorage.m",
                "XMPPManagedMessagingTests.m",
                "XMPPStorageHintTests.m",
                "XMPPPubSubTests.m"
            ],
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
                "Info.plist",
                "XMPPMockStream.m",
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
                "Gemfile",
                "Gemfile.lock",
                "Examples",
                "Testing-Carthage",
                "Testing-iOS",
                "Testing-macOS",
                "Testing-Shared/OMEMOTestStorage.m",
                "Testing-Shared/Info.plist",
                "Testing-Shared/XMPPManagedMessagingTests.m",
                "Testing-Shared/XMPPMessageArchiveManagementTests.m",
                "Testing-Shared/XMPPOutOfBandResourceMessagingTests.m",
                "Testing-Shared/XMPPRoomLightCoreDataStorageTests.m",
                "Testing-Shared/XMPPRoomLightTests.m",
                "Testing-Shared/XMPPMessageDeliveryReceiptsTests.m",
                "Testing-Shared/OMEMOServerTests.m",
                "Testing-Shared/CapabilitiesHashingTest.m",
                "Testing-Shared/XMPPOneToOneChatTests.m",
                "Testing-Shared/XMPPDelayedDeliveryTests.m",
                "Testing-Shared/XMPPMockStream.m",
                "Testing-Shared/XMPPPubSubTests.m",
                "Testing-Shared/XMPPHTTPFileUploadTests.m",
                "Testing-Shared/XMPPvCardTests.m",
                "Testing-Shared/OMEMOElementTests.m",
                "Testing-Shared/OMEMOModuleTests.m",
                "Testing-Shared/EncodeDecodeTest.m",
                "Testing-Shared/XMPPStorageHintTests.m",
                "Testing-Shared/XMPPURITests.m",
                "Testing-Shared/XMPPMUCLightTests.m",
                "Testing-Shared/XMPPFrameworkTests-Bridging-Header.h"
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
