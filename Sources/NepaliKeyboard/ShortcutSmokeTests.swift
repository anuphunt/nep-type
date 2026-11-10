import AppKit
import NepaliCore

@MainActor
extension AppDelegate {
    func runShortcutTests(destination: String) {
        var checks: [String: Bool] = [:]
        shortcutSmokeChecks { checks[$0] = $1 }
        do {
            let data = try JSONSerialization.data(withJSONObject: ["passed": checks.values.allSatisfy { $0 }, "checks": checks], options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: destination))
            print(String(decoding: data, as: UTF8.self))
        } catch { fputs("Shortcut checks failed: \(error)\n", stderr) }
        NSApp.terminate(nil)
    }

    /// Exercise actual AppKit key-event dispatch, including the editor and menu.
    /// Calling candidateAction directly would miss the original Option+2 bug.
    func shortcutSmokeChecks(check: (String, Bool) -> Void) {
        let saved = composer
        let savedSelection = input.selectedRange()
        defer {
            input.unmarkText()
            composer = saved
            selectedOutputSource = nil
            suppressCandidateSuggestions = false
            refresh(syncInput: true)
            input.setSelectedRange(savedSelection)
            window.makeFirstResponder(input)
        }
        // A hosted runner can still have activation/window events queued when
        // the launch timer fires. Establish the same focused key window a real
        // user types into before replacing the document or posting a key.
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(input)
        let readyDeadline = Date().addingTimeInterval(5)
        repeat {
            let turn = min(readyDeadline, Date().addingTimeInterval(0.02))
            while let event = NSApp.nextEvent(matching: .any, until: turn, inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        } while !(NSApp.isActive && window.isKeyWindow && window.firstResponder === input) && Date() < readyDeadline
        check("shortcut_focused_window_ready", NSApp.isActive && window.isKeyWindow && window.firstResponder === input)
        func prepare(_ source: String) {
            input.unmarkText()
            composer = Composer()
            composer.setLanguage(.nepali)
            input.string = source
            input.setSelectedRange(NSRange(location: (source as NSString).length, length: 0))
            window.makeFirstResponder(input)
            textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        }
        var eventSequence = 0
        var drainedEveryPress = true
        func key(_ characters: String, flags: NSEvent.ModifierFlags, code: UInt16,
                 ignoring: String? = nil, repeated: Bool = false) {
            // Activation is asynchronous and can change between cases on a
            // desktop runner. Preserve the tested responder while establishing
            // the active window a physical key press requires.
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            let activationDeadline = Date().addingTimeInterval(5)
            while !(NSApp.isActive && window.isKeyWindow) && Date() < activationDeadline {
                if let pending = NSApp.nextEvent(matching: .any, until: min(activationDeadline, Date().addingTimeInterval(0.02)), inMode: .default, dequeue: true) {
                    NSApp.sendEvent(pending)
                }
            }
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: characters, charactersIgnoringModifiers: ignoring ?? characters,
                isARepeat: repeated, keyCode: code)!
            NSApp.postEvent(event, atStart: false)
            // A complete press includes release. Without it AppKit can retain
            // key-equivalent tracking across independently prepared cases.
            let release = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: characters, charactersIgnoringModifiers: ignoring ?? characters,
                isARepeat: false, keyCode: code)!
            NSApp.postEvent(release, atStart: false)
            eventSequence += 1
            let marker = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, subtype: 231, data1: eventSequence, data2: 0)!
            NSApp.postEvent(marker, atStart: false)
            // Use the application queue, as physical key presses do. Sending
            // events inline skips AppKit's current-event and menu bookkeeping.
            let deadline = Date().addingTimeInterval(2)
            var drained = false
            while !drained && Date() < deadline {
                if let next = NSApp.nextEvent(matching: .any, until: min(deadline, Date().addingTimeInterval(0.02)), inMode: .default, dequeue: true) {
                    // Read AppKit values on this actor before the lazy Boolean
                    // operators; older Swift SDKs otherwise capture NSEvent
                    // across the operators' actor-inferred autoclosures.
                    if next.type == .applicationDefined {
                        let subtype = next.subtype.rawValue
                        let sequence = next.data1
                        if subtype == 231 && sequence == eventSequence {
                            drained = true
                            continue
                        }
                    }
                    NSApp.sendEvent(next)
                }
            }
            drainedEveryPress = drainedEveryPress && drained && NSApp.isActive && window.isKeyWindow
        }
        func command(_ number: Int, repeated: Bool = false) {
            key(String(number), flags: .command, code: [18, 19, 20, 21, 23][number - 1], repeated: repeated)
        }

        prepare("pani")
        command(2)
        if output.string != "पानी" {
            print("Shortcut diagnostic: active=\(NSApp.isActive) keyWindow=\(window.isKeyWindow) responder=\(String(describing: window.firstResponder)) source=\(input.string) output=\(output.string) choices=\(choices)")
        }
        check("shortcut_command_2_at_caret", input.string == "pani" && output.string == "पानी")
        key("z", flags: .command, code: 6)
        check("shortcut_selection_undo", input.string == "pani" && output.string == "पनि")
        // Physical Command-Shift-Z is checked in native UI acceptance. Posting
        // an NSEvent does not establish the hardware's live Shift-key state.

        prepare("pani")
        input.setSelectedRange(NSRange(location: 0, length: 4))
        check("shortcut_selected_word_ready", canChooseCandidate(at: 1) && input.selectedRange() == NSRange(location: 0, length: 4))
        command(2)
        if output.string != "पानी" {
            print("Selected-word shortcut diagnostic: active=\(NSApp.isActive) keyWindow=\(window.isKeyWindow) responder=\(String(describing: window.firstResponder)) source=\(input.string) output=\(output.string) range=\(input.selectedRange()) canChoose=\(canChooseCandidate(at: 1)) choices=\(choices)")
        }
        check("shortcut_command_2_selected_word", input.string == "pani" && output.string == "पानी")

        for number in 1...5 {
            prepare("paani")
            let expected = choices.indices.contains(number - 1) ? choices[number - 1] : nil
            command(number)
            check("shortcut_visible_slot_\(number)", expected != nil && input.string == "paani" && output.string == expected)
        }
        prepare("paani")
        nextCandidates(nil)
        let pageChoice = choices.first
        command(1)
        check("shortcut_current_page", candidatePage > 0 && pageChoice != nil && output.string == pageChoice && input.string == "paani")

        prepare("pani")
        if let word = output.mappedWords.first { selectOutputWord(word) }
        command(2)
        check("shortcut_output_editor", input.string == "pani" && output.string == "पानी")

        prepare("namaste")
        command(5)
        command(2, repeated: true)
        check("shortcut_unavailable_and_repeat_do_not_edit", input.string == "namaste" && output.string == "नमस्ते")
        prepare("pani ")
        command(2)
        check("shortcut_no_active_word_does_not_edit", input.string == "pani " && output.string == "पनि ")
        prepare("pani pani")
        input.setSelectedRange(NSRange(location: 0, length: 9))
        let multipleOutput = output.string
        command(2)
        check("shortcut_multiple_word_selection_ignored", input.string == "pani pani" && output.string == multipleOutput)

        prepare("pani")
        input.string = "mero" // stale view before its change notification arrives
        let oldOutput = output.string
        command(2)
        check("shortcut_stale_document_ignored", input.string == "mero" && output.string == oldOutput)

        prepare("pani")
        let unrelatedField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        window.contentView?.addSubview(unrelatedField)
        window.makeFirstResponder(unrelatedField)
        command(2)
        check("shortcut_does_not_select_from_other_fields", input.string == "pani" && output.string == "पनि")
        unrelatedField.removeFromSuperview()

        prepare("pani")
        input.setMarkedText("pa", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: 0, length: 4))
        let marked = input.string
        command(2)
        check("shortcut_preserves_ime_composition", input.hasMarkedText() && input.string == marked)

        prepare("pani")
        key("a", flags: .command, code: 0)
        check("shortcut_preserves_select_all", input.selectedRange() == NSRange(location: 0, length: 4))
        key("2", flags: [], code: 19)
        check("shortcut_plain_number_is_text", input.string == "2")
        prepare("pani")
        key("™", flags: .option, code: 19, ignoring: "2")
        check("shortcut_option_number_keeps_normal_text_input", input.string == "pani™")
        check("shortcut_event_queue_drained", drainedEveryPress)
    }
}
