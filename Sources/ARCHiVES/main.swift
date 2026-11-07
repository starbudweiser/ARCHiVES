import AppKit
import ArchivesCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settingsWindow: NSWindow?
    private var receivedWork = false
    private var interactive = false

    func applicationDidFinishLaunching(_ n: Notification) {
        I18n.setup()
        Socle.apply()
        Socle.brand("ARCHiVES", color: Socle.C.accentText)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        buildMenu()
        UserDefaults.standard.register(defaults: ["autoUpdate": true])
        UpdateEngine.shared.configure(repo: "ARCHiVES", lang: { I18n.lang })
        UpdateEngine.shared.autoCheck = { UserDefaults.standard.bool(forKey: "autoUpdate") }
        UpdateEngine.shared.start()
        JobCenter.shared.onIdle = { [weak self] in self?.maybeQuit() }
        // Lancé à la main (sans fichier ni Service) : on montre les réglages.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, !self.receivedWork else { return }
            self.showSettings()
        }
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        receivedWork = true
        JobCenter.shared.add(urls.filter(\.isFileURL).map { .extract($0) })
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showSettings() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func maybeQuit() {
        guard !interactive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !JobCenter.shared.isBusy && !self.interactive { NSApp.terminate(nil) }
        }
    }

    // MARK: fenêtres

    @objc func showSettings() {
        interactive = true
        NSApp.setActivationPolicy(.regular)
        if settingsWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            w.title = L("Réglages")
            w.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: SettingsView())
            w.contentView = host
            w.delegate = self
            w.setContentSize(host.fittingSize)
            settingsWindow = w
        }
        settingsWindow?.socleCenter()
        settingsWindow?.present()
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        interactive = false
        DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        maybeQuit()
    }

    @objc func showAbout() { About.show() }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let app = NSMenu()
        app.addItem(withTitle: L("À propos de ARCHiVES"), action: #selector(showAbout), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: L("Réglages…"), action: #selector(showSettings), keyEquivalent: ",")
        app.addItem(.separator())
        app.addItem(withTitle: L("Masquer ARCHiVES"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(.separator())
        app.addItem(withTitle: L("Quitter ARCHiVES"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: L("Édition"))
        edit.addItem(withTitle: L("Couper"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    // MARK: Services du Finder (clic droit › Services)

    private func urls(_ pb: NSPasteboard) -> [URL] {
        (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    @objc func extractService(_ pb: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        receivedWork = true
        let u = urls(pb)
        DispatchQueue.main.async { JobCenter.shared.add(u.map { .extract($0) }) }
    }

    @objc func createService(_ pb: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        receivedWork = true
        let u = urls(pb)
        DispatchQueue.main.async { if !u.isEmpty { JobCenter.shared.add([.create(u, Prefs.load().defaultFormat, nil)]) } }
    }

    @objc func createProtectedService(_ pb: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        receivedWork = true
        let u = urls(pb)
        DispatchQueue.main.async {
            guard !u.isEmpty else { self.maybeQuit(); return }
            if let (fmt, pw) = Prompts.askCreate(defaultFormat: Prefs.load().defaultFormat) {
                JobCenter.shared.add([.create(u, fmt, pw)])
            } else { self.maybeQuit() }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
