import AppKit
import ArchivesCore
import SwiftUI

enum JobKind {
    case extract(URL)
    case create([URL], ArchiveFormat, String?)
}

@MainActor
final class ProgressModel: ObservableObject {
    @Published var title = ""
    @Published var step = ""
    @Published var fraction = 0.0
    var cancel = CancelFlag()
}

/// File de travaux : un seul à la fois (peu de CPU et de mémoire). Fenêtre de progression discrète, seulement si c'est long.
@MainActor
final class JobCenter {
    static let shared = JobCenter()
    private var queue: [JobKind] = []
    private var total = 0, doneCount = 0
    private var running = false
    private var failures: [(String, String)] = []
    private var revealed: [URL] = []
    private let model = ProgressModel()
    private var panel: NSPanel?
    private var panelTimer: Timer?
    var onIdle: (() -> Void)?
    var isBusy: Bool { running || !queue.isEmpty }

    func add(_ jobs: [JobKind]) {
        var seen = Set<String>(), unique: [JobKind] = []
        for j in jobs {
            if case .extract(let u) = j {
                let f = Volumes.first(of: u)
                guard seen.insert(f.path).inserted else { continue }
                unique.append(.extract(f))
            } else { unique.append(j) }
        }
        queue += unique; total += unique.count
        if !running { next() }
    }

    private func next() {
        guard !queue.isEmpty else { finish(); return }
        running = true
        let job = queue.removeFirst()
        doneCount += 1
        model.cancel = CancelFlag()
        model.fraction = 0
        let cancel = model.cancel
        let prefs = Prefs.load()
        let name: String
        switch job {
        case .extract(let u): name = u.lastPathComponent; model.title = L("Extraction de {name}", ["name": name])
        case .create(let s, let f, _): name = Compressor.outputURL(for: s, format: f, multiName: L("Archive")).lastPathComponent
            model.title = L("Compression de {name}", ["name": name])
        }
        model.step = total > 1 ? L("{i} sur {n}", ["i": doneCount, "n": total]) : ""
        panelTimer?.invalidate()
        panelTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.showPanel() }
        }
        let progress: (Double) -> Void = { [weak model] f in DispatchQueue.main.async { model?.fraction = f } }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var failure: (String, String)?
            var created: URL?
            do {
                switch job {
                case .extract(let url):
                    created = try Self.runExtract(url, prefs: prefs, cancel: cancel, progress: progress)
                case .create(let sources, let fmt, let pw):
                    let out = Compressor.outputURL(for: sources, format: fmt, multiName: L("Archive"))
                    try Compressor.create(sources, at: out, format: fmt, password: pw, cancel: cancel, progress: progress)
                    created = out
                }
            } catch ArchiveError.cancelled {
            } catch {
                let isExtract: Bool = { if case .extract = job { return true } else { return false } }()
                let msg = (error as? ArchiveError)?.errorDescription ?? error.localizedDescription
                failure = (isExtract ? L("Impossible d'extraire « {name} »", ["name": name]) : L("Impossible de créer l'archive"),
                           msg + "\n" + L("Vérifiez que l'archive n'est pas corrompue et que le dossier est modifiable."))
            }
            DispatchQueue.main.async {
                if let failure { self?.failures.append(failure) }
                if let created, case .extract(let url) = job {
                    if prefs.trashAfter { for v in Volumes.all(from: url) { try? FileManager.default.trashItem(at: v, resultingItemURL: nil) } }
                    if prefs.revealAfter { self?.revealed.append(created) }
                }
                self?.running = false
                self?.next()
            }
        }
    }

    /// Boucle mot de passe : demande tant que l'archive refuse, jusqu'à annulation.
    nonisolated private static func runExtract(_ url: URL, prefs: Prefs, cancel: CancelFlag, progress: @escaping (Double) -> Void) throws -> URL {
        var password: String?
        var retry = false
        while true {
            do {
                return try Extractor.extract(url, into: url.deletingLastPathComponent(), prefs: prefs, password: password, cancel: cancel, progress: progress)
            } catch let e as ArchiveError where e == .needsPassword || e == .wrongPassword {
                retry = (e == .wrongPassword)
                var answer: String?
                DispatchQueue.main.sync { answer = MainActor.assumeIsolated { Prompts.askExtractPassword(name: url.lastPathComponent, retry: retry) } }
                guard let answer else { throw ArchiveError.cancelled }
                password = answer
            }
        }
    }

    private func finish() {
        panelTimer?.invalidate(); panel?.orderOut(nil); panel = nil
        total = 0; doneCount = 0
        if !revealed.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(revealed); revealed = [] }
        if !failures.isEmpty {
            let f = failures; failures = []
            Prompts.error(f[0].0, f.map { $0.0 == f[0].0 ? $0.1 : "\($0.0)\n\($0.1)" }.joined(separator: "\n\n"))
        }
        onIdle?()
    }

    /// Petit panneau flottant qui ne prend pas le focus.
    private func showPanel() {
        guard running, panel == nil else { return }
        let view = ProgressView_(model: model) { [weak self] in self?.model.cancel.set() }
        let host = NSHostingView(rootView: view)
        host.setFrameSize(NSSize(width: 360, height: 96))
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: host.frame.size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.contentView = host
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.socleCenter()
        p.orderFrontRegardless()
        panel = p
    }
}

struct ProgressView_: View {
    @ObservedObject var model: ProgressModel
    let cancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space2) {
            HStack {
                Text(model.title).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong).lineLimit(1).truncationMode(.middle)
                Spacer()
                if !model.step.isEmpty { Text(model.step).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted) }
            }
            ProgressView(value: model.fraction).tint(Socle.C.accent)
            HStack {
                Text("\(Int(model.fraction * 100)) %").socle(Socle.T.monoSm).foregroundStyle(Socle.C.accentText)
                Spacer()
                Button(L("ANNULER"), action: cancel).buttonStyle(SocleButtonStyle(.secondary, height: 24)).fixedSize()
            }
        }
        .padding(Socle.M.space4)
        .frame(width: 360)
        .background(Socle.C.surfaceRaised, in: RoundedRectangle(cornerRadius: Socle.M.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Socle.M.radiusLg).stroke(Socle.C.border, lineWidth: 1))
    }
}
