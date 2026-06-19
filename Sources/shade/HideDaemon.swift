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

    private var enforcer: Timer?
    private var enforceUntil: Date = .distantPast
    private let enforceInterval: TimeInterval = 0.1
    private let enforceDuration: TimeInterval = 3.0

    /// The app the user actually activated — the one we keep visible. Anchored to
    /// the activation event (NOT live `frontmostApplication`), so the enforcement
    /// burst can't drift onto an app that hiding itself brought to the front.
    private var target: NSRunningApplication?

    @objc private func activeAppChanged(_ note: Notification) {
        guard let active = note.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else { return }
        // Hide immediately for responsiveness, then keep enforcing for a few seconds.
        //
        // When an app with several windows is brought forward, the window server
        // raises its windows over many frames *after* the activation event, briefly
        // revealing background apps in the gaps — and a hide() issued mid-transition
        // often doesn't take (the system is busy reordering windows). Heavier apps
        // (e.g. browsers like Dia with multiple windows) can take well over a second
        // to settle, so a few fixed passes aren't enough. Instead we run a short
        // enforcement burst that re-hides any straggler until things stop moving.
        target = active
        hideOthers()
        startEnforcing()
    }

    /// Runs (or extends) a repeating timer that re-hides background apps every
    /// `enforceInterval` for `enforceDuration`. It's cheap and self-quieting:
    /// `hideOthers` skips apps that are already hidden, so once the screen has
    /// settled each tick does almost nothing.
    private func startEnforcing() {
        enforceUntil = Date().addingTimeInterval(enforceDuration)
        guard enforcer == nil else { return } // already running — just extended the deadline
        let timer = Timer(timeInterval: enforceInterval, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            self.hideOthers()
            if Date() >= self.enforceUntil {
                t.invalidate()
                self.enforcer = nil
            }
        }
        // .common so it keeps firing during window dragging / menu tracking.
        RunLoop.main.add(timer, forMode: .common)
        enforcer = timer
    }

    /// Hides every regular app except the activation `target` and the app that is
    /// *currently* frontmost.
    ///
    /// Skipping the live frontmost is essential: hiding the frontmost app makes
    /// macOS auto-activate the next app in the window stack, which would post a new
    /// activation event and let the burst "walk" onto an unrelated app (e.g. a
    /// hidden Claude getting pulled to the front when you only clicked Dia). By
    /// never hiding whatever is frontmost right now, the burst can't trigger that
    /// cascade.
    private func hideOthers() {
        guard let target else { return }
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue } // skip agents/menu-bar apps
            if app.processIdentifier == target.processIdentifier { continue }
            if app.processIdentifier == frontmostPID { continue } // never hide the active app
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
