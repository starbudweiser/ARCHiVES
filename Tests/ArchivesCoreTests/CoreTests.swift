import XCTest
@testable import ArchivesCore

final class CoreTests: XCTestCase {
    func testNames() {
        XCTAssertEqual(NameSimplifier.baseName("a.tar.gz"), "a")
        XCTAssertEqual(NameSimplifier.baseName("Film.part01.rar"), "Film")
        XCTAssertEqual(NameSimplifier.baseName("x.zip.001"), "x")
        XCTAssertEqual(NameSimplifier.simplify("SkyUI-3-12604-5-2-1-1700000000"), "SkyUI")
        XCTAssertEqual(NameSimplifier.simplify("My_Great.Mod_v1.2.3 [Official] (x64)"), "My Great Mod v1.2.3")
        XCTAssertEqual(NameSimplifier.simplify("Un nom vraiment beaucoup trop long pour un dossier d'extraction", maxLength: 30), "Un nom vraiment beaucoup trop")
        XCTAssertEqual(NameSimplifier.folderName(for: "A_B.7z", simplify: false, maxLength: 40), "A_B")
    }

    func tmp() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("arch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func roundTrip(_ fmt: ArchiveFormat, password: String?) throws {
        let d = try tmp(); defer { try? FileManager.default.removeItem(at: d) }
        let src = d.appendingPathComponent("Données")
        try FileManager.default.createDirectory(at: src.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try "bonjour".write(to: src.appendingPathComponent("sub/a.txt"), atomically: true, encoding: .utf8)
        try "salut".write(to: src.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let out = Compressor.outputURL(for: [src], format: fmt, multiName: "Archive")
        try Compressor.create([src], at: out, format: fmt, password: password, cancel: CancelFlag(), progress: { _ in })
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        var prefs = Prefs(); prefs.flattenSingleRoot = true
        let dest = d.appendingPathComponent("dest"); try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        if let password {
            XCTAssertThrowsError(try Extractor.extract(out, into: dest, prefs: prefs, cancel: CancelFlag(), progress: { _ in })) {
                XCTAssertEqual($0 as? ArchiveError, .needsPassword)
            }
            XCTAssertThrowsError(try Extractor.extract(out, into: dest, prefs: prefs, password: "faux", cancel: CancelFlag(), progress: { _ in })) {
                XCTAssertEqual($0 as? ArchiveError, .wrongPassword)
            }
        }
        let r = try Extractor.extract(out, into: dest, prefs: prefs, password: password, cancel: CancelFlag(), progress: { _ in })
        XCTAssertEqual(r.lastPathComponent, "Données")
        XCTAssertEqual(try String(contentsOf: r.appendingPathComponent("sub/a.txt"), encoding: .utf8), "bonjour")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dest.path).sorted(), ["Données"])
    }

    func testZip() throws { try roundTrip(.zip, password: nil) }
    func test7z() throws { try roundTrip(.sevenZip, password: nil) }
    func testZipPassword() throws { try roundTrip(.zip, password: "s3cret") }
    func test7zPassword() throws { try roundTrip(.sevenZip, password: "s3cret") }
}

final class I18nTests: XCTestCase {
    func testAllLanguagesPresent() {
        for (k, v) in translations { XCTAssertEqual(v.count, 3, k); XCTAssertFalse(v.contains(""), k) }
    }
}
