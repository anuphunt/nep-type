import AppKit

/// Handle pad commands before NSTextView can interpret them as text or IME input.
/// Only the focused editor owns these commands; settings fields keep normal keys.
class CandidateShortcutTextView: NSTextView {
    var onCandidateShortcut: ((Int) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        guard window?.firstResponder === self, modifiers == .command,
              let characters = event.charactersIgnoringModifiers,
              characters.count == 1, let number = Int(characters), (1...5).contains(number),
              let onCandidateShortcut else { return super.performKeyEquivalent(with: event) }
        // Consume an unavailable command too: it must never change the source.
        if !hasMarkedText(), !event.isARepeat { onCandidateShortcut(number - 1) }
        return true
    }
}
