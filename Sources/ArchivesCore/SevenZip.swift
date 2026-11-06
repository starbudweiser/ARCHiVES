import Foundation

/// 7zz embarqué (Contents/Resources/7zz) : sert aux archives protégées par mot de passe (zip AES, 7z, RAR) et de repli.
/// Le mot de passe passe par -p, seulement pour la durée du traitement.
public enum SevenZip {
    public static var binary: URL? {
        var candidates: [URL] = []
        if let r = Bundle.main.url(forResource: "7zz", withExtension: nil) { candidates.append(r) }
        candidates += ["/opt/homebrew/bin/7zz", "/usr/local/bin/7zz"].map { URL(fileURLWithPath: $0) }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    struct Result { var status: Int32; var output: String }

    static func run(_ args: [String], cwd: URL? = nil, cancel: CancelFlag?, progress: ((Double) -> Void)? = nil) throws -> Result {
        guard let bin = binary else { throw ArchiveError.failed("7zz introuvable") }
        let p = Process()
        p.executableURL = bin
        p.arguments = args
        p.currentDirectoryURL = cwd
        p.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        var all = Data()
        let fh = pipe.fileHandleForReading
        var buffer = ""
        while true {
            if cancel?.isSet == true { p.terminate(); p.waitUntilExit(); throw ArchiveError.cancelled }
            let chunk = fh.availableData
            if chunk.isEmpty { break }
            all.append(chunk)
            if let progress, let s = String(data: chunk, encoding: .utf8) {
                buffer += s
                if buffer.count > 400 { buffer = String(buffer.suffix(200)) }
                if let m = buffer.range(of: #"(\d{1,3})%(?!.*\d%)"#, options: .regularExpression, range: nil, locale: nil),
                   let v = Double(buffer[m].dropLast()) { progress(v / 100) }
            }
        }
        p.waitUntilExit()
        return Result(status: p.terminationStatus, output: String(decoding: all, as: UTF8.self))
    }

    static func isPasswordProblem(_ out: String) -> Bool {
        let o = out.lowercased()
        return o.contains("wrong password") || o.contains("enter password") || o.contains("cannot open encrypted archive")
            || o.contains("encrypted") && (o.contains("data error") || o.contains("crc failed"))
    }

    /// Extrait `archive` dans `dir` (dossier existant). `password` nil = aucun.
    static func extract(_ archive: URL, to dir: URL, password: String?, cancel: CancelFlag?, progress: ((Double) -> Void)?) throws {
        var args = ["x", "-y", "-bsp1", "-bso0", "-bse1", "-aou", "-o" + dir.path,
                    "-xr!__MACOSX", "-xr!.DS_Store", "-xr!._*"]
        args.append(password.map { "-p" + $0 } ?? "-p")  // « -p » seul : échoue au lieu de demander (stdin fermé)
        args.append(archive.path)
        let r = try run(args, cancel: cancel, progress: progress)
        if r.status == 0 { return }
        if isPasswordProblem(r.output) { throw password == nil ? ArchiveError.needsPassword : ArchiveError.wrongPassword }
        throw ArchiveError.failed(lastLines(r.output))
    }

    /// Crée une archive protégée. 7z : noms de fichiers chiffrés aussi ; zip : AES-256.
    static func create(_ sources: [URL], at output: URL, format: ArchiveFormat, password: String, cancel: CancelFlag?, progress: ((Double) -> Void)?) throws {
        var args = ["a", "-y", "-bsp1", "-bso0", "-bse1", "-snl", "-xr!.DS_Store"]
        switch format {
        case .zip: args += ["-tzip", "-mem=AES256"]
        case .sevenZip: args += ["-t7z", "-mhe=on"]
        }
        args.append("-p" + password)
        args.append(output.path)
        // chemins relatifs au dossier parent commun : l'archive contient « nom/… », pas le chemin complet
        let parent = sources[0].deletingLastPathComponent()
        args += sources.map { $0.lastPathComponent }
        let r = try run(args, cwd: parent, cancel: cancel, progress: progress)
        if r.status != 0 { try? FileManager.default.removeItem(at: output); throw ArchiveError.failed(lastLines(r.output)) }
    }

    static func lastLines(_ s: String) -> String {
        let lines = s.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.contains("%") && !$0.isEmpty }
        return lines.suffix(3).joined(separator: " ")
    }
}
