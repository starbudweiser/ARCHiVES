import AppKit
import ArchivesCore
import SwiftUI
import UniformTypeIdentifiers

enum Types {
    static let exts = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst", "lz", "lzma", "cab", "cpio", "xar"]
    static var identifiers: [String] {
        Array(Set(exts.compactMap { UTType(filenameExtension: $0)?.identifier }.filter { !$0.hasPrefix("dyn.") })).sorted()
    }
}

struct SettingsView: View {
    @AppStorage("trashAfter") private var trashAfter = false
    @AppStorage("simplifyName") private var simplify = true
    @AppStorage("maxNameLength") private var maxLen = 40
    @AppStorage("flattenSingleRoot") private var flatten = true
    @AppStorage("revealAfter") private var reveal = false
    @AppStorage("defaultFormat") private var format = "zip"
    @AppStorage("autoUpdate") private var autoUpdate = true
    @State private var defaultsMessage = ""

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(title).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong)
            content()
        }
        .padding(Socle.M.space6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Socle.C.surface, in: RoundedRectangle(cornerRadius: Socle.M.radiusLg))
    }

    private func toggle(_ text: String, _ binding: Binding<Bool>, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: binding) { Text(text).socle(Socle.T.body).foregroundStyle(Socle.C.text) }.toggleStyle(.checkbox)
            if let hint { Text(hint).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted).padding(.leading, 20) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Socle.M.space4) {
                HStack {
                    Text(branded: "ARCHiVES").socle(Socle.T.display).foregroundStyle(Socle.C.textStrong)
                    Spacer()
                }
                card(L("Extraction")) {
                    toggle(L("Mettre l'archive à la corbeille après l'extraction"), $trashAfter)
                    toggle(L("Simplifier le nom du dossier"), $simplify, hint: L("Retire les étiquettes [..], les identifiants numériques de fin et les _ . superflus."))
                    if simplify {
                        HStack {
                            Text(L("Longueur maximale du nom : {n} caractères", ["n": maxLen])).socle(Socle.T.body).foregroundStyle(Socle.C.text)
                            Slider(value: Binding(get: { Double(maxLen) }, set: { maxLen = Int($0) }), in: 15...80, step: 5).frame(width: 140)
                        }.padding(.leading, 20)
                    }
                    toggle(L("Ne pas doubler le dossier si l'archive n'en contient qu'un"), $flatten)
                    toggle(L("Afficher le dossier dans le Finder après l'extraction"), $reveal)
                }
                card(L("Compression")) {
                    HStack {
                        Text(L("Format par défaut")).socle(Socle.T.body).foregroundStyle(Socle.C.text)
                        SocleSegmented(options: ArchiveFormat.allCases.map(\.rawValue), selection: format, label: { $0.uppercased() }, onSelect: { format = $0 })
                            .fixedSize()
                    }
                }
                card(L("Intégration au Finder")) {
                    Text(L("Double-clic : définissez ARCHiVES comme application par défaut pour les archives.")).socle(Socle.T.body).foregroundStyle(Socle.C.text)
                    HStack(spacing: Socle.M.space3) {
                        Button(L("DÉFINIR PAR DÉFAUT")) { defaultsMessage = setDefaultHandler() }.buttonStyle(SocleButtonStyle(.primary)).fixedSize()
                        if !defaultsMessage.isEmpty { Text(defaultsMessage).socle(Socle.T.meta).foregroundStyle(Socle.C.success) }
                    }
                    Text(L("Clic droit sur un ou plusieurs fichiers, menu Services : « Décompresser », « Créer une ARCHiVE ». S'ils manquent, activez-les dans Réglages Système › Clavier › Raccourcis clavier › Services."))
                        .socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
                }
                card(L("Mises à jour")) {
                    toggle(L("Installer automatiquement les mises à jour"), $autoUpdate)
                    Button(L("RECHERCHER MAINTENANT")) { UpdateEngine.shared.checkNow() }.buttonStyle(SocleButtonStyle(.secondary)).fixedSize()
                }
            }
            .padding(Socle.M.space6)
        }
        .frame(width: 560, height: 640)
        .background(Socle.C.bg)
    }

    @MainActor private func setDefaultHandler() -> String {
        let id = Bundle.main.bundleIdentifier ?? "fr.stephan.archives"
        var n = 0
        for t in Types.identifiers where LSSetDefaultRoleHandlerForContentType(t as CFString, .all, id as CFString) == noErr { n += 1 }
        return L("ARCHiVES est maintenant l'application par défaut de {n} formats.", ["n": n])
    }
}
