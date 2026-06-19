import Foundation

/// A small terminal welcome animation shown on `install`.
/// The logo fades in "out of the shade" (dark grey -> white), fitting the name.
enum Banner {
    private static let logo = [
        "  ███████ ██   ██  █████  ██████  ███████ ",
        "  ██      ██   ██ ██   ██ ██   ██ ██      ",
        "  ███████ ███████ ███████ ██   ██ █████   ",
        "       ██ ██   ██ ██   ██ ██   ██ ██      ",
        "  ███████ ██   ██ ██   ██ ██████  ███████ ",
    ]

    private static var isTTY: Bool { isatty(fileno(stdout)) != 0 }

    private static func emit(_ s: String) {
        fputs(s, stdout)
        fflush(stdout)
    }

    /// Plays the welcome animation. Falls back to plain static text when output
    /// isn't an interactive terminal (piped, redirected, etc.).
    static func play() {
        guard isTTY else {
            print("")
            logo.forEach { print($0) }
            print("\n  shade — the windows you're not using, drawn into shade.\n")
            return
        }

        emit("\n\u{1B}[?25l") // blank line + hide cursor

        // Fade the logo in from darkness (256-colour greyscale ramp) to white.
        let ramp = [234, 236, 238, 240, 243, 246, 249, 252, 255, 231]
        for (i, shade) in ramp.enumerated() {
            if i > 0 { emit("\u{1B}[\(logo.count)A") } // move back up to redraw
            for line in logo {
                emit("\u{1B}[38;5;\(shade)m\(line)\u{1B}[0m\n")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        emit("\u{1B}[?25h\n") // show cursor + spacer
        typewriter("  the windows you're not using, drawn into shade.", color: 244)
        emit("\n")
    }

    /// Prints a "✓ message" line in green (or plain when not a TTY).
    static func ok(_ message: String) {
        if isTTY {
            emit("  \u{1B}[32m✓\u{1B}[0m \(message)\n")
        } else {
            print("  ✓ \(message)")
        }
    }

    /// Prints a dimmed "label: value" detail line.
    static func detail(_ label: String, _ value: String) {
        if isTTY {
            emit("    \u{1B}[2m\(label):\u{1B}[0m \u{1B}[38;5;245m\(value)\u{1B}[0m\n")
        } else {
            print("    \(label): \(value)")
        }
    }

    private static func typewriter(_ text: String, color: Int, delay: Double = 0.012) {
        emit("\u{1B}[38;5;\(color)m")
        for ch in text {
            emit(String(ch))
            Thread.sleep(forTimeInterval: delay)
        }
        emit("\u{1B}[0m\n")
    }
}
