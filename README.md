# shade

A tiny macOS CLI that automatically hides apps you're not using.

The moment you switch to an app, **shade** hides every other app — like pressing
<kbd>⌥⌘H</kbd> automatically on every app switch ("Auto Hide Others"). Only the app you're
focused on stays visible, keeping your screen clear and distraction-free.

- Hides whole apps via the native macOS *Hide* mechanism (<kbd>⌘H</kbd>).
- **No Accessibility or Automation permission required.**
- Runs invisibly in the background (no Dock icon, no menu-bar item).
- Auto-starts at login via a LaunchAgent.

## Requirements

- macOS 13 or later
- Swift toolchain (`swift --version`) — ships with the Xcode Command Line Tools

## Build & install

```sh
swift build -c release
.build/release/shade install
```

`install` copies the binary to `~/.local/bin/shade`, writes a LaunchAgent to
`~/Library/LaunchAgents/com.shade.agent.plist`, and starts it. shade is now running and
will start automatically every time you log in.

> Tip: add `~/.local/bin` to your `PATH` so you can just type `shade`.

## Usage

```
shade install              Install + start (auto-runs at login)
shade uninstall            Stop and remove everything (keeps your exclusions)
shade start                Start / restart the background agent
shade stop                 Stop the background agent
shade status               Is it running? Show current exclusions
shade run                  Run in the foreground (used by the LaunchAgent; handy for testing)

shade exclude add <id>     Never hide this app (by bundle id)
shade exclude remove <id>  Stop excluding an app
shade exclude list         Show excluded apps
```

## Keeping some apps visible

Add an app's bundle identifier to the exclusion list so shade never hides it. A common
choice is keeping Finder around:

```sh
shade exclude add com.apple.finder
```

Find any app's bundle id with:

```sh
osascript -e 'id of app "Music"'
```

Exclusions live in `~/.config/shade/exclusions.txt` (one bundle id per line). Changes take
effect immediately — the running agent reloads them automatically.

## How it works

shade runs as a background *accessory* app (`NSApplication` with `.accessory` activation
policy, so no Dock icon). It observes
`NSWorkspace.didActivateApplicationNotification`; on each app switch it calls
`hide()` on every other regular application that isn't excluded.

The `.accessory` policy matters: a fully `.prohibited` process can receive the
notifications but lacks the window-server connection needed to hide other apps, so
`.accessory` is used instead.

## Uninstall

```sh
shade uninstall
```

This stops the agent and removes the LaunchAgent plist and the installed binary. Your
exclusion config under `~/.config/shade` is left intact.
