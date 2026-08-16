// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aria",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Composition-root executable. This is what you run.
        .executable(name: "AriaApp", targets: ["AriaApp"]),

        // Libraries are exposed as products mainly so they can be unit
        // tested / reused independently later (e.g. from a future GUI
        // target added in Stage 6 without restructuring anything here).
        .library(name: "AriaDomain", targets: ["AriaDomain"]),
        .library(name: "AriaApplication", targets: ["AriaApplication"]),
        .library(name: "AriaInfrastructure", targets: ["AriaInfrastructure"]),
        .library(name: "AriaPresentation", targets: ["AriaPresentation"])
    ],
    targets: [
        // MARK: Domain
        // Pure data + protocols. No dependency on any other Aria module,
        // no dependency on Foundation networking, no third-party SDKs.
        .target(
            name: "AriaDomain",
            dependencies: []
        ),

        // MARK: Application
        // Orchestration / use-cases. Depends only on Domain (protocols),
        // never on concrete Infrastructure or Presentation types.
        .target(
            name: "AriaApplication",
            dependencies: ["AriaDomain", "AriaInfrastructure"]
        ),

        // MARK: Infrastructure
        // Concrete implementations of Domain protocols (LLM provider,
        // config, logging). This is the ONLY layer allowed to know about
        // Gemini, the filesystem, environment variables, etc.
        .target(
            name: "AriaInfrastructure",
            dependencies: ["AriaDomain"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),

        // MARK: Presentation
        // Interfaces + stub implementations for how Aria is shown to the
        // user (desktop UI, avatar). Depends only on Domain so the real
        // UI/Live2D work in later stages can be dropped in without
        // touching Application/Domain.
        .target(
            name: "AriaPresentation",
            dependencies: ["AriaDomain"],
            resources: [
                .copy("Resources/FrameworkMetallibs")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreGraphics"),
                .unsafeFlags(["-Xlinker", "-force_load", "-Xlinker", "/Volumes/T7Sheald/Aria/ThirdParty/Live2D/Lib/libLive2DBridge.a"]),
                .unsafeFlags(["-L/Volumes/T7Sheald/Aria/ThirdParty/Live2D/Lib"]),
                .unsafeFlags(["-lAriaCubism"]),
                .unsafeFlags(["-L/Volumes/T7Sheald/Aria/ThirdParty/Live2D/CubismSdkForNative-5-r.5/Core/lib/macos/arm64"]),
                .unsafeFlags(["-lLive2DCubismCore"]),
                .unsafeFlags(["-lc++"])
            ]
        ),

        // MARK: App (composition root)
        // The only place allowed to wire concrete Infrastructure /
        // Presentation implementations into the Application layer.
        .executableTarget(
            name: "AriaApp",
            dependencies: [
                "AriaDomain",
                "AriaApplication",
                "AriaInfrastructure",
                "AriaPresentation"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreGraphics"),
                .unsafeFlags(["-Xlinker", "-force_load", "-Xlinker", "/Volumes/T7Sheald/Aria/ThirdParty/Live2D/Lib/libLive2DBridge.a"]),
                .unsafeFlags(["-L/Volumes/T7Sheald/Aria/ThirdParty/Live2D/Lib"]),
                .unsafeFlags(["-lAriaCubism"]),
                .unsafeFlags(["-L/Volumes/T7Sheald/Aria/ThirdParty/Live2D/CubismSdkForNative-5-r.5/Core/lib/macos/arm64"]),
                .unsafeFlags(["-lLive2DCubismCore"]),
                .unsafeFlags(["-lc++"])
            ]
        ),

        // MARK: Tests
        .testTarget(
            name: "AriaDomainTests",
            dependencies: ["AriaDomain"]
        ),
        .testTarget(
            name: "AriaApplicationTests",
            dependencies: ["AriaApplication", "AriaDomain", "AriaInfrastructure"]
        ),
        .testTarget(
            name: "AriaInfrastructureTests",
            dependencies: ["AriaInfrastructure", "AriaDomain"]
        )
    ]
)
