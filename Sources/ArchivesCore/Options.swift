import Foundation

public enum ArchiveFormat: String, CaseIterable, Sendable { case zip, sevenZip = "7z"
    public var ext: String { rawValue }
}

/// Réglages (UserDefaults), lus à chaque travail.
public struct Prefs: Sendable {
    public var trashAfter = false
    public var simplifyName = true
    public var maxNameLength = 40
    public var flattenSingleRoot = true
    public var revealAfter = false
    public var defaultFormat = ArchiveFormat.zip
    /// 0 = aucune, 1 = rapide, 5 = normal, 9 = maximale
    public var compressionLevel = 5

    public init() {}
    static let d = UserDefaults.standard
    public static func load() -> Prefs {
        var p = Prefs()
        if d.object(forKey: "trashAfter") != nil { p.trashAfter = d.bool(forKey: "trashAfter") }
        if d.object(forKey: "simplifyName") != nil { p.simplifyName = d.bool(forKey: "simplifyName") }
        if d.object(forKey: "maxNameLength") != nil { p.maxNameLength = max(10, min(120, d.integer(forKey: "maxNameLength"))) }
        if d.object(forKey: "flattenSingleRoot") != nil { p.flattenSingleRoot = d.bool(forKey: "flattenSingleRoot") }
        if d.object(forKey: "revealAfter") != nil { p.revealAfter = d.bool(forKey: "revealAfter") }
        if let f = d.string(forKey: "defaultFormat"), let fmt = ArchiveFormat(rawValue: f) { p.defaultFormat = fmt }
        if d.object(forKey: "compressionLevel") != nil { p.compressionLevel = max(0, min(9, d.integer(forKey: "compressionLevel"))) }
        return p
    }
}

public enum ArchiveError: Error, LocalizedError, Equatable {
    case needsPassword
    case wrongPassword
    case cancelled
    case failed(String)
    public var errorDescription: String? {
        switch self {
        case .needsPassword: return "password required"
        case .wrongPassword: return "wrong password"
        case .cancelled: return "cancelled"
        case .failed(let m): return m
        }
    }
}

/// Drapeau d'annulation partagé entre l'interface et le travail.
public final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    public init() {}
    public var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
    public func set() { lock.lock(); value = true; lock.unlock() }
}
