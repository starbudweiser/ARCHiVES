import CArchive
import Foundation

public enum Extractor {
    /// Extrait `archive` dans un nouveau dossier de `parent` et renvoie ce dossier.
    /// - password : nil = sans mot de passe (lève `.needsPassword` si l'archive est protégée).
    public static func extract(_ archive: URL, into parent: URL, prefs: Prefs, password: String? = nil,
                               cancel: CancelFlag, progress: @escaping (Double) -> Void) throws -> URL {
        let fm = FileManager.default
        let first = Volumes.first(of: archive)
        let tmp = parent.appendingPathComponent(".ARCHiVES-\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: false)
        var done = false
        defer { if !done { try? fm.removeItem(at: tmp) } }

        if password == nil {
            do {
                try extractWithLibarchive(first, to: tmp, cancel: cancel, progress: progress)
            } catch ArchiveError.cancelled {
                throw ArchiveError.cancelled
            } catch {
                // libarchive ne sait pas tout faire (protégé, RAR exotique) : repli sur 7zz s'il est là
                guard SevenZip.binary != nil else { throw error }
                try? fm.removeItem(at: tmp); try fm.createDirectory(at: tmp, withIntermediateDirectories: false)
                try SevenZip.extract(first, to: tmp, password: nil, cancel: cancel, progress: progress)
            }
        } else {
            try SevenZip.extract(first, to: tmp, password: password, cancel: cancel, progress: progress)
        }
        if cancel.isSet { throw ArchiveError.cancelled }

        let name = NameSimplifier.folderName(for: first.lastPathComponent, simplify: prefs.simplifyName, maxLength: prefs.maxNameLength)
        let final = NameSimplifier.unique(name, in: parent)
        let children = try fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: [.isDirectoryKey])
        if prefs.flattenSingleRoot, children.count == 1,
           (try? children[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            try fm.moveItem(at: children[0], to: final)
            try? fm.removeItem(at: tmp)
        } else {
            try fm.moveItem(at: tmp, to: final)
        }
        done = true
        return final
    }

    static func lastError(_ a: OpaquePointer?) -> String {
        guard let a, let c = archive_error_string(a) else { return "erreur inconnue" }
        return String(cString: c)
    }

    static func skip(_ name: String) -> Bool {
        let last = (name as NSString).lastPathComponent
        return name.hasPrefix("__MACOSX") || last == ".DS_Store" || last.hasPrefix("._")
    }

    static func safe(_ name: String) -> String? {
        var parts = name.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if parts.contains("..") { return nil }
        parts = parts.filter { $0 != "." }
        return parts.isEmpty ? nil : parts.joined(separator: "/")
    }

    static func extractWithLibarchive(_ first: URL, to dir: URL, cancel: CancelFlag, progress: (Double) -> Void) throws {
        guard let a = archive_read_new() else { throw ArchiveError.failed("libarchive") }
        defer { archive_read_free(a) }
        archive_read_support_filter_all(a)
        archive_read_support_format_all(a)
        guard let w = archive_write_disk_new() else { throw ArchiveError.failed("libarchive") }
        defer { archive_write_free(w) }
        archive_write_disk_set_options(w, Int32(ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_SECURE_SYMLINKS | ARCHIVE_EXTRACT_SECURE_NODOTDOT))

        let volumes = Volumes.all(from: first)
        let total = max(1, volumes.reduce(Int64(0)) { $0 + (((try? FileManager.default.attributesOfItem(atPath: $1.path)[.size]) as? NSNumber)?.int64Value ?? 0) })
        let paths = volumes.map { strdup($0.path) }
        defer { paths.forEach { free($0) } }
        var cpaths: [UnsafePointer<CChar>?] = paths.map { UnsafePointer($0) } + [nil]
        let r = archive_read_open_filenames(a, &cpaths, 1 << 20)
        if r != ARCHIVE_OK { throw ArchiveError.failed(lastError(a)) }

        var entry: OpaquePointer?
        var lastPct = -1.0
        while true {
            if cancel.isSet { throw ArchiveError.cancelled }
            let h = archive_read_next_header(a, &entry)
            if h == ARCHIVE_EOF { break }
            if h < ARCHIVE_WARN { throw ArchiveError.failed(lastError(a)) }
            guard let entry else { break }
            if archive_entry_is_data_encrypted(entry) != 0 || archive_entry_is_metadata_encrypted(entry) != 0 {
                throw ArchiveError.needsPassword
            }
            let rawPtr = archive_entry_pathname_utf8(entry) ?? archive_entry_pathname(entry)
            let raw = rawPtr.map { String(cString: $0) } ?? ""
            guard let name = safe(raw), !skip(name) else { archive_read_data_skip(a); continue }
            let target = dir.path + "/" + name
            archive_entry_update_pathname_utf8(entry, target)
            if let hl = archive_entry_hardlink(entry) {
                if let s = safe(String(cString: hl)) { archive_entry_set_hardlink(entry, dir.path + "/" + s) }
            }
            let wh = archive_write_header(w, entry)
            if wh < ARCHIVE_WARN { throw ArchiveError.failed(lastError(w)) }
            if archive_entry_size_is_set(entry) != 0, archive_entry_size(entry) > 0, (archive_entry_filetype(entry) & mode_t(AE_IFMT)) == mode_t(AE_IFREG) {
                var buf: UnsafeRawPointer?
                var size = 0
                var offset: Int64 = 0
                while true {
                    if cancel.isSet { throw ArchiveError.cancelled }
                    let br = archive_read_data_block(a, &buf, &size, &offset)
                    if br == ARCHIVE_EOF { break }
                    if br < ARCHIVE_WARN { throw ArchiveError.failed(lastError(a)) }
                    if let buf, archive_write_data_block(w, buf, size, offset) < 0 { throw ArchiveError.failed(lastError(w)) }
                    let pct = (Double(archive_filter_bytes(a, -1)) / Double(total) * 100).rounded()
                    if pct != lastPct { lastPct = pct; progress(min(1, pct / 100)) }
                }
            }
            archive_write_finish_entry(w)
        }
        archive_write_close(w)
        archive_read_close(a)
        progress(1)
    }
}
