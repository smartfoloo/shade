import Foundation

let usage = """
shade — automatically hide apps you're not using (Auto Hide Others).

USAGE:
  shade <command>

COMMANDS:
  run                  Run the daemon in the foreground (used by the LaunchAgent).
  install              Install the binary + LaunchAgent and start it (auto-runs at login).
  uninstall            Stop and remove the LaunchAgent and installed binary.
  start                Start (or restart) the installed background agent.
  stop                 Stop the installed background agent.
  status               Show whether the agent is running.
  exclude add <id>     Never hide the app with this bundle id (e.g. com.apple.finder).
  exclude remove <id>  Remove a bundle id from the exclusion list.
  exclude list         Show the current exclusion list.
  help                 Show this help.
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())

guard let command = args.first else {
    print(usage)
    exit(0)
}

switch command {
case "run":
    HideDaemon().run()

case "install":
    do { try LaunchAgent.install() } catch { fail("install failed: \(error)") }

case "uninstall":
    do { try LaunchAgent.uninstall() } catch { fail("uninstall failed: \(error)") }

case "start":
    if Launchctl.isLoaded() {
        Launchctl.kickstart()
        print("shade restarted.")
    } else if FileManager.default.fileExists(atPath: Constants.launchAgentURL.path) {
        Launchctl.bootstrap(plist: Constants.launchAgentURL)
        print("shade started.")
    } else {
        fail("not installed — run `shade install` first.")
    }

case "stop":
    Launchctl.bootout()
    print("shade stopped.")

case "status":
    if Launchctl.isLoaded() {
        print("shade is running (\(Constants.label)).")
        let exclusions = Config.load()
        print("exclusions: \(exclusions.isEmpty ? "none" : exclusions.sorted().joined(separator: ", "))")
    } else {
        print("shade is not running.")
    }

case "exclude":
    let sub = args.count > 1 ? args[1] : "list"
    switch sub {
    case "add":
        guard args.count > 2 else { fail("usage: shade exclude add <bundle-id>") }
        do { try Config.add(args[2]); print("Excluded \(args[2]).") }
        catch { fail("\(error)") }
        if Launchctl.isLoaded() { Launchctl.kickstart() }
    case "remove":
        guard args.count > 2 else { fail("usage: shade exclude remove <bundle-id>") }
        do { try Config.remove(args[2]); print("Removed \(args[2]).") }
        catch { fail("\(error)") }
        if Launchctl.isLoaded() { Launchctl.kickstart() }
    case "list":
        let ids = Config.load()
        print(ids.isEmpty ? "(no exclusions)" : ids.sorted().joined(separator: "\n"))
    default:
        fail("unknown exclude subcommand '\(sub)'")
    }

case "help", "-h", "--help":
    print(usage)

default:
    fail("unknown command '\(command)'\n\n\(usage)")
}
