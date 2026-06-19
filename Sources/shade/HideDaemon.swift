import AppKit
import Foundation

/// The background daemon. Listens for application-activation events and hides every other
/// regular app, leaving only the focused app visible (Auto Hide Others).
final class HideDaemon: NSObject, NSApplicationDelegate {
    private var exclusions: Set<String> = []

    // NSApplication.delegate is weak, so keep a strong reference alive for the
    // lifetime of the process.
    private static var retained: HideDaemon?

    func run() {
        HideDaemon.retained = self
        let app = NSApplication.shared
        // .accessory: no Dock icon / menu bar, but (unlike .prohibited) keeps the
        // window-server connection required to hide other applications.
        app.setActivationPolicy(.accessory)
        app.delegate = self
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        reloadConfig()

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // SIGHUP triggers a live reload of the exclusion list without a restart.
        let hup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
        hup.setEventHandler { [weak self] in self?.reloadConfig() }
        hup.resume()
        signal(SIGHUP, SIG_IGN)
        self.sighupSource = hup

        log("shade daemon started (\(exclusions.count) exclusion(s))")
    }

    private var sighupSource: DispatchSourceSignal?

    private func reloadConfig() {
        exclusions = Config.load()
        log("loaded \(exclusions.count) exclusion(s)")
    }

    private var followUps: [DispatchWorkItem] = []

    @objc private func activeAppChanged(_ note: Notification) {
        // Hide immediately for responsiveness, then re-assert a couple of times.
        //
        // When an app with several windows is brought forward, the window server
        // raises its windows a few frames *after* the activation event, briefly
        // revealing background apps in the gaps — and a hide() issued mid-transition
        // sometimes doesn't take (the system is busy reordering windows). The
        // follow-up passes re-hide anything that slipped through once things settle.
        hideOthersFromFrontmost()
        reassert(after: [0.08, 0.2, 0.45])
    }

    private func reassert(after delays: [Double]) {
        followUps.forEach { $0.cancel() }
        followUps = delays.map { delay in
            let work = DispatchWorkItem { [weak self] in self?.hideOthersFromFrontmost() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }

    /// Hides every other regular app, keying off the *current* frontmost app
    /// (not a possibly-stale notification), so rapid app switches stay correct.
    private func hideOthersFromFrontmost() {
        guard let active = NSWorkspace.shared.frontmostApplication else { return }
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue } // skip agents/menu-bar apps
            if app.processIdentifier == active.processIdentifier { continue }
            if app.isHidden { continue } // already hidden — nothing to do
            if let id = app.bundleIdentifier, exclusions.contains(id) { continue }
            app.hide()
        }
    }

    private func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write(Data("[\(stamp)] \(message)\n".utf8))
    }
}
