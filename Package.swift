// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ARCHiVES",
    platforms: [.macOS(.v15)],
    targets: [
        // libarchive du système (/usr/lib/libarchive.dylib) : en-tête réduit aux fonctions utilisées
        .systemLibrary(name: "CArchive", path: "Sources/CArchive"),
        // Moteur sans interface (testable seul) : extraction, compression, noms, mots de passe
        .target(name: "ArchivesCore", dependencies: ["CArchive"]),
        .executableTarget(name: "ARCHiVES", dependencies: ["ArchivesCore"]),
        .testTarget(name: "ArchivesCoreTests", dependencies: ["ArchivesCore"]),
    ],
    swiftLanguageModes: [.v5]
)
