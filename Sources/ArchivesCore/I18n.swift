import Foundation

/// Internationalisation : le texte français sert de clé ; langues fr, en, it, es. Langue du Mac, anglais si non prise en charge.
public enum I18n {
    public static let langs = ["fr", "en", "it", "es"]
    static let index = ["en": 0, "it": 1, "es": 2]
    nonisolated(unsafe) public private(set) static var lang = "en"

    public static func systemLang(_ preferred: [String] = Locale.preferredLanguages) -> String {
        for code in preferred { let c = String(code.prefix(2)).lowercased(); if langs.contains(c) { return c } }
        return "en"
    }
    public static func setup() { lang = systemLang() }
    public static var keys: Set<String> { Set(translations.keys) }
}

public func L(_ text: String, _ kw: [String: Any] = [:]) -> String {
    var out = text
    if I18n.lang != "fr", let i = I18n.index[I18n.lang], let tr = translations[text], !tr[i].isEmpty { out = tr[i] }
    for (k, v) in kw { out = out.replacingOccurrences(of: "{\(k)}", with: "\(v)") }
    return out
}
