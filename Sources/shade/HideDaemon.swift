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

    @objc private func activeAppChanged(_ note: Notification) {
        guard let active = note.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else { return }
        hideOthers(except: active)
    }

    private func hideOthers(except active: NSRunningApplication) {
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue } // skip agents/menu-bar apps
            if app.processIdentifier == active.processIdentifier { continue }
            if let id = app.bundleIdentifier, exclusions.contains(id) { continue }
            app.hide()
        }
    }

    private func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write(Data("[\(stamp)] \(message)\n".utf8))
    }
}
