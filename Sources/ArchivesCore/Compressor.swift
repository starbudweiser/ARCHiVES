import CArchive
import Foundation

public enum Compressor {
    /// Nom et emplacement de l'archive : « nom.zip » à côté d'une source unique, « Archive.zip » pour plusieurs.
    public static func outputURL(for sources: [URL], format: ArchiveFormat, multiName: String) -> URL {
        let parent = sources[0].deletingLastPathComponent()
        let base: String
        if sources.count == 1 {
            let n = sources[0].lastPathComponent
            base = (try? sources[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? n : (n as NSString).deletingPathExtension
        } else { base = multiName }
        return NameSimplifier.unique(base, in: parent, ext: format.ext)
    }

    public static func create(_ sources: [URL], at output: URL, format: ArchiveFormat, password: String?,
                              cancel: CancelFlag, progress: @escaping (Double) -> Void) throws {
        precondition(!sources.isEmpty)
        if let password, !password.isEmpty {
            try SevenZip.create(sources, at: output, format: format, password: password, cancel: cancel, progress: progress)
            return
        }
        let fm = FileManager.default
        // liste à plat : (url, chemin dans l'archive)
        var items: [(URL, String)] = []
        var total: Int64 = 0
        for s in sources {
            items.append((s, s.lastPathComponent))
            if let subs = try? fm.subpathsOfDirectory(atPath: s.path) {
                for sub in subs.sorted() where (sub as NSString).lastPathComponent != ".DS_Store" {
                    let u = s.appendingPathComponent(sub)
                    items.append((u, s.lastPathComponent + "/" + sub))
                    total += Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
            } else {
                total += Int64((try? s.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        total = max(1, total)

        guard let a = archive_write_new(), let disk = archive_read_disk_new() else { throw ArchiveError.failed("libarchive") }
        defer { archive_write_free(a); archive_read_free(disk) }
        archive_read_disk_set_symlink_physical(disk)
        switch format {
        case .zip: archive_write_set_format_zip(a); archive_write_set_options(a, "zip:compression=deflate")
        case .sevenZip: archive_write_set_format_7zip(a); archive_write_set_options(a, "compression=lzma2")
        }
        var ok = false
        defer { if !ok { try? fm.removeItem(at: output) } }
        if archive_write_open_filename(a, output.path) != ARCHIVE_OK { throw ArchiveError.failed(Extractor.lastError(a)) }

        var done: Int64 = 0
        var lastPct = -1.0
        let chunk = 1 << 20
        var buf = [UInt8](repeating: 0, count: chunk)
        for (url, rel) in items {
            if cancel.isSet { throw ArchiveError.cancelled }
            guard let e = archive_entry_new() else { throw ArchiveError.failed("libarchive") }
            defer { archive_entry_free(e) }
            archive_entry_copy_sourcepath(e, url.path)
            archive_entry_set_pathname(e, rel)
            if archive_read_disk_entry_from_file(disk, e, -1, nil) < ARCHIVE_WARN { throw ArchiveError.failed(Extractor.lastError(disk)) }
            if archive_write_header(a, e) < ARCHIVE_WARN { throw ArchiveError.failed(Extractor.lastError(a)) }
            let isReg = (archive_entry_filetype(e) & mode_t(AE_IFMT)) == mode_t(AE_IFREG)
            if isReg, archive_entry_size(e) > 0 {
                guard let fh = try? FileHandle(forReadingFrom: url) else { throw ArchiveError.failed("Lecture impossible : \(rel)") }
                defer { try? fh.close() }
                while true {
                    if cancel.isSet { throw ArchiveError.cancelled }
                    guard let data = try fh.read(upToCount: chunk), !data.isEmpty else { break }
                    data.copyBytes(to: &buf, count: data.count)
                    if archive_write_data(a, buf, data.count) < 0 { throw ArchiveError.failed(Extractor.lastError(a)) }
                    done += Int64(data.count)
                    let pct = (Double(done) / Double(total) * 100).rounded()
                    if pct != lastPct { lastPct = pct; progress(min(1, pct / 100)) }
                }
            }
        }
        if archive_write_close(a) < ARCHIVE_WARN { throw ArchiveError.failed(Extractor.lastError(a)) }
        ok = true
        progress(1)
    }
}
