import Foundation

/// Nom du dossier d'extraction : nom de l'archive sans extension, allégé si besoin.
public enum NameSimplifier {
    static let multiExt = ["tar.gz", "tar.bz2", "tar.xz", "tar.zst", "tar.lz", "tar.z"]
    static let archiveExt: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "zst", "lz", "lzma", "z", "cab",
        "iso", "cpio", "jar", "war", "xar", "pkg", "lha", "lzh", "arj", "zipx", "cbz", "cbr", "cb7", "img", "dmg",
    ]

    /// Nom sans extension d'archive (gère .tar.gz, .part1.rar, .zip.001, .r00).
    public static func baseName(_ fileName: String) -> String {
        var name = fileName
        let lower = name.lowercased()
        for e in multiExt where lower.hasSuffix("." + e) { return String(name.dropLast(e.count + 1)) }
        // .001 / .r00 / .z01 : numéro de volume
        if let r = name.range(of: #"\.(?:\d{3}|[rz]\d{2})$"#, options: [.regularExpression, .caseInsensitive]) {
            name.removeSubrange(r)
            if let ext = name.split(separator: ".").last, archiveExt.contains(ext.lowercased()) { name = String(name.dropLast(ext.count + 1)) }
            return name
        }
        // .part01.rar
        if let r = name.range(of: #"\.part0*\d+\.(?:rar)$"#, options: [.regularExpression, .caseInsensitive]) {
            name.removeSubrange(r)
            return name
        }
        let ns = name as NSString
        if archiveExt.contains(ns.pathExtension.lowercased()) { return ns.deletingPathExtension }
        return name
    }

    /// Simplifie un nom : retire les étiquettes [..] (..), les identifiants numériques de fin (Nexus : -1234-1-0-1700000000),
    /// remplace _ et . par des espaces, tronque proprement.
    public static func simplify(_ base: String, maxLength: Int = 40) -> String {
        var s = base
        // étiquettes entre crochets ou parenthèses
        let stripped = s.replacingOccurrences(of: #"\s*[\[\(][^\]\)]*[\]\)]"#, with: "", options: .regularExpression)
        if !stripped.trimmingCharacters(in: .whitespaces).isEmpty { s = stripped }
        // identifiants numériques de fin
        if let r = s.range(of: #"(?:[-_ ]\d+){3,}$"#, options: .regularExpression) {
            let tail = String(s[r])
            let groups = tail.split(whereSeparator: { "-_ ".contains($0) })
            if let last = groups.last, last.count >= 9 || groups.count >= 5 {
                let head = String(s[..<r.lowerBound])
                if !head.isEmpty { s = head }
            }
        }
        s = s.replacingOccurrences(of: "_", with: " ")
        // points entre mots → espaces ; points de version (entre chiffres) conservés
        var out = ""
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            if c == ".", !(i > 0 && chars[i - 1].isNumber && i + 1 < chars.count && chars[i + 1].isNumber) { out.append(" ") } else { out.append(c) }
        }
        s = out.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " -_."))
        if s.count > maxLength {
            let cut = String(s.prefix(maxLength))
            if let sp = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: sp) > maxLength / 2 { s = String(cut[..<sp]) } else { s = cut }
            s = s.trimmingCharacters(in: CharacterSet(charactersIn: " -_."))
        }
        return s.isEmpty ? base : s
    }

    /// Nom de dossier pour une archive.
    public static func folderName(for archiveFile: String, simplify doSimplify: Bool, maxLength: Int) -> String {
        let base = baseName(archiveFile)
        return doSimplify ? simplify(base, maxLength: maxLength) : base
    }

    /// Premier nom libre dans `dir` : « nom », « nom 2 », « nom 3 »…
    public static func unique(_ name: String, in dir: URL, ext: String = "") -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent(ext.isEmpty ? "\(name) \(n)" : "\(name) \(n).\(ext)")
            n += 1
        }
        return candidate
    }
}
