import AppKit
import ArchivesCore

/// Fenêtre « À propos » (modèle Socle / DeskStay).
@MainActor
enum About {
    private static var window: NSWindow?
    private static let sideMargin: CGFloat = 28
    private static let textWidth: CGFloat = 300

    static func show() {
        if window == nil { window = makeWindow() }
        window?.socleCenter()
        window?.present()
    }

    private static func label(_ text: String, size: CGFloat = 12, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        field.textColor = secondary ? .secondaryLabelColor : .labelColor
        field.alignment = .center
        field.preferredMaxLayoutWidth = textWidth
        field.isSelectable = false
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(lessThanOrEqualToConstant: textWidth).isActive = true
        return field
    }

    private static func brandName() -> NSTextField {
        let f = label("ARCHiVES", size: 17, bold: true)
        let a = NSMutableAttributedString(string: "ARCHiVES", attributes: [.font: NSFont.boldSystemFont(ofSize: 17), .foregroundColor: NSColor.labelColor])
        a.addAttribute(.foregroundColor, value: NSColor(Socle.C.accentText), range: NSRange(location: 4, length: 1))
        f.attributedStringValue = a
        f.alignment = .center
        return f
    }

    private static func makeWindow() -> NSWindow {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 84).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 84).isActive = true
        let views: [NSView] = [
            icon, brandName(),
            label(L("Version {v} ({b})", ["v": version, "b": build]), secondary: true),
            label(L("Extraction et compression d'archives, légère et intégrée au Finder.")),
            label(L("Starbudweiser & Claude Code (Anthropic)"), bold: true),
            label(L("Licence MIT. © 2026 Starbudweiser.")),
            label(L("Fourni en l'état, sans garantie."), secondary: true),
            label(L("Inspiré de The Unarchiver, sans lien avec ses auteurs. Utilise libarchive et 7-Zip."), secondary: true),
        ]
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(6, after: views[1])
        stack.setCustomSpacing(18, after: views[2])
        stack.edgeInsets = NSEdgeInsets(top: 28, left: sideMargin, bottom: 28, right: sideMargin)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: textWidth + 2 * sideMargin).isActive = true
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("À propos de ARCHiVES")
        window.isReleasedWhenClosed = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor), stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        content.layoutSubtreeIfNeeded(); content.layoutSubtreeIfNeeded()
        window.setContentSize(content.fittingSize)
        return window
    }
}
