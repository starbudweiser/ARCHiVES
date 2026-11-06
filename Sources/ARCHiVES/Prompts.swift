import AppKit
import ArchivesCore

/// Fenêtres de mot de passe (seules fenêtres qui prennent le focus : l'utilisateur doit saisir quelque chose).
@MainActor
enum Prompts {
    private static func secure() -> NSSecureTextField {
        let f = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 280).isActive = true
        f.placeholderString = L("Mot de passe")
        return f
    }

    /// Mot de passe d'une archive à extraire ; nil = annulé.
    static func askExtractPassword(name: String, retry: Bool) -> String? {
        let alert = NSAlert()
        alert.messageText = L("Mot de passe requis")
        alert.informativeText = retry ? L("Mot de passe incorrect pour « {name} ». Réessayez.", ["name": name])
                                      : L("« {name} » est protégée par un mot de passe.", ["name": name])
        alert.icon = NSApp.applicationIconImage
        let field = secure()
        alert.accessoryView = field
        alert.addButton(withTitle: L("VALIDER"))
        alert.addButton(withTitle: L("Annuler"))
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return nil }
        return field.stringValue
    }

    /// Format + mot de passe (confirmé) d'une archive à créer ; nil = annulé.
    static func askCreate(defaultFormat: ArchiveFormat) -> (ArchiveFormat, String)? {
        var message = L("Choisissez le format et le mot de passe. Le contenu sera chiffré (AES-256).")
        while true {
            let alert = NSAlert()
            alert.messageText = L("Créer une ARCHiVE protégée")
            alert.informativeText = message
            alert.icon = NSApp.applicationIconImage
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.addItems(withTitles: ArchiveFormat.allCases.map { $0.ext.uppercased() })
            popup.selectItem(at: ArchiveFormat.allCases.firstIndex(of: defaultFormat) ?? 0)
            let p1 = secure(), p2 = secure()
            p2.placeholderString = L("Confirmer le mot de passe")
            let formatLabel = NSTextField(labelWithString: L("Format"))
            let row = NSStackView(views: [formatLabel, popup]); row.spacing = 8
            let stack = NSStackView(views: [row, p1, p2])
            stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
            stack.frame = NSRect(x: 0, y: 0, width: 280, height: 100)
            alert.accessoryView = stack
            alert.addButton(withTitle: L("VALIDER"))
            alert.addButton(withTitle: L("Annuler"))
            alert.window.initialFirstResponder = p1
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            if p1.stringValue.isEmpty { message = L("Le mot de passe est vide."); continue }
            if p1.stringValue != p2.stringValue { message = L("Les deux mots de passe sont différents."); continue }
            return (ArchiveFormat.allCases[popup.indexOfSelectedItem], p1.stringValue)
        }
    }

    static func error(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: L("Fermer"))
        NSApp.activate()
        alert.runModal()
    }
}
