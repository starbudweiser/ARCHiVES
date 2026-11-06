import Foundation

/// Archives en plusieurs volumes : .part1.rar / .part2.rar, .rar + .r00 .r01, .001 .002.
public enum Volumes {
    /// Premier volume de l'archive à laquelle appartient `url` (ou `url` elle-même).
    public static func first(of url: URL) -> URL {
        let name = url.lastPathComponent
        let dir = url.deletingLastPathComponent()
        if let m = name.range(of: #"^(.*)\.part0*(\d+)\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
            let s = String(name[m])
            if let r = s.range(of: #"\.part0*\d+\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
                let stem = String(s[..<r.lowerBound])
                let digits = s[r].filter(\.isNumber)
                let width = digits.count
                let one = String(repeating: "0", count: max(0, width - 1)) + "1"
                let cand = dir.appendingPathComponent("\(stem).part\(one).rar")
                if FileManager.default.fileExists(atPath: cand.path) { return cand }
            }
        }
        if let r = name.range(of: #"\.r\d{2}$"#, options: [.regularExpression, .caseInsensitive]) {
            let cand = dir.appendingPathComponent(String(name[..<r.lowerBound]) + ".rar")
            if FileManager.default.fileExists(atPath: cand.path) { return cand }
        }
        if let r = name.range(of: #"\.\d{3}$"#, options: .regularExpression), name[r] != ".001" {
            let cand = dir.appendingPathComponent(String(name[..<r.lowerBound]) + ".001")
            if FileManager.default.fileExists(atPath: cand.path) { return cand }
        }
        return url
    }

    /// Tous les volumes, dans l'ordre (le premier en tête).
    public static func all(from first: URL) -> [URL] {
        let fm = FileManager.default
        let name = first.lastPathComponent
        let dir = first.deletingLastPathComponent()
        var out = [first]
        func add(_ cands: (Int) -> String, from: Int) {
            var i = from
            while fm.fileExists(atPath: dir.appendingPathComponent(cands(i)).path) { out.append(dir.appendingPathComponent(cands(i))); i += 1 }
        }
        if let r = name.range(of: #"\.part(0*)1\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
            let stem = String(name[..<r.lowerBound])
            let zeros = name[r].lowercased().dropFirst(5).prefix { $0 == "0" }.count
            let width = zeros + 1
            add({ "\(stem).part\(String(format: "%0\(width)d", $0)).rar" }, from: 2)
        } else if name.lowercased().hasSuffix(".rar") {
            let stem = String(name.dropLast(4))
            add({ "\(stem).r\(String(format: "%02d", $0))" }, from: 0)
        } else if name.hasSuffix(".001") {
            let stem = String(name.dropLast(4))
            add({ "\(stem).\(String(format: "%03d", $0))" }, from: 2)
        }
        return out
    }
}
