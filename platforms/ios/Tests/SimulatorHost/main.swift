import UIKit

final class ViewEditor: LekhaDocumentEditing {
    let view: UITextView
    var markedWrites = 0
    var hideContext = false
    var contextBefore: String? { hideContext ? nil : (view.text as NSString).substring(to: view.selectedRange.location) }
    var contextAfter: String? { if hideContext { return nil }; let s = view.text as NSString; return s.substring(from: NSMaxRange(view.selectedRange)) }
    let documentIdentifier: UUID?
    init(_ view: UITextView, documentIdentifier: UUID? = UUID()) { self.view = view; self.documentIdentifier = documentIdentifier }
    func ownsSelectionSource(_ input: UITextInput?) -> Bool { (input as AnyObject?) === view }
    func setMarkedText(_ text: String, selectedRange: NSRange) { markedWrites += 1; view.setMarkedText(text, selectedRange: selectedRange) }
    func unmarkText() { view.unmarkText() }
    func insertText(_ text: String) { view.insertText(text) }
    func deleteBackward() { view.deleteBackward() }
    func adjustTextPosition(byCharacterOffset offset: Int) {
        guard let current = view.selectedTextRange?.end,
              let target = view.position(from: current, offset: offset),
              let selection = view.textRange(from: target, to: target) else { return }
        view.selectedTextRange = selection
    }
}

@main final class HostApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIViewController(); host.view.backgroundColor = .white
        let text = UITextView(frame: CGRect(x: 20, y: 90, width: 340, height: 180)); text.font = .systemFont(ofSize: 24)
        host.view.addSubview(text)
        let keyboard = KeyboardViewController(); keyboard.testEditor = ViewEditor(text)
        host.addChild(keyboard); keyboard.view.frame = CGRect(x: 0, y: 340, width: 380, height: 300); host.view.addSubview(keyboard.view); keyboard.didMove(toParent: host)
        window.rootViewController = host; window.makeKeyAndVisible(); self.window = window
        text.becomeFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.run(keyboard, text) }
        return true
    }
    func run(_ keyboard: KeyboardViewController, _ text: UITextView) {
        var results: [String: Bool] = [:]
        func find(_ label: String, in view: UIView) -> UIButton? {
            if let b = view as? UIButton, b.accessibilityLabel == label { return b }
            return view.subviews.lazy.compactMap { find(label, in: $0) }.first
        }
        func press(_ label: String) {
            guard let button = find(label, in: keyboard.view) else { results["missing_" + label] = false; return }
            button.sendActions(for: .touchUpInside)
        }
        func write(_ string: String) { for char in string { press(String(char)) } }
        func textIs(_ name: String, _ expected: String) { results[name] = text.text == expected }
        // A queued key from a prior render must not affect the current word.
        if let staleSpace = find("Space", in: keyboard.view) {
            press("m")
            staleSpace.sendActions(for: .touchUpInside)
            textIs("stale_space_does_not_commit_new_word", "m")
            press("Delete")
        } else { results["stale_space_does_not_commit_new_word"] = false }

        results["language_accessibility_state_nepali"] = find("Switch language", in: keyboard.view)?.accessibilityValue == "Nepali"
        results["shift_accessibility_state_off"] = find("Shift", in: keyboard.view)?.accessibilityValue == "Off"
        press("Shift")
        results["shift_accessibility_state_on"] = find("Shift", in: keyboard.view)?.accessibilityValue == "On"
        press("Shift")
        func buttonsFit(_ width: CGFloat) -> Bool {
            keyboard.view.frame = CGRect(x: 0, y: 340, width: width, height: 300)
            keyboard.view.setNeedsLayout(); keyboard.view.layoutIfNeeded()
            func allButtons(_ view: UIView) -> [UIButton] {
                (view as? UIButton).map { [$0] } ?? view.subviews.flatMap(allButtons)
            }
            return allButtons(keyboard.view).allSatisfy { button in
                let rect = button.convert(button.bounds, to: keyboard.view)
                return rect.minX >= -1 && rect.maxX <= width + 1 && rect.width > 0
            }
        }
        results["controls_fit_narrow_width"] = buttonsFit(320)
        results["controls_fit_wide_width"] = buttonsFit(430)
        keyboard.view.frame = CGRect(x: 0, y: 340, width: 380, height: 300)
        write("ma"); textIs("roman_marked", "ma")
        // The live controller now computes candidates away from the UI thread.
        // Poll rather than sleeping for a fixed index load time.
        let deadline = Date().addingTimeInterval(10)
        var staleCheckDone = false
        func continueWhenReady() {
            if find("Choose म", in: keyboard.view) == nil && Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { continueWhenReady() }
                return
            }
            results["async_candidate_arrived"] = find("Choose म", in: keyboard.view) != nil
        if !staleCheckDone {
            let original = find("Choose ma", in: keyboard.view)
            results["original_visibly_selected_by_default"] = original?.backgroundColor == UIColor(white: 215/255, alpha: 1) && original?.accessibilityTraits.contains(.selected) == true && original?.accessibilityValue == "Original selected"
        }
            if !staleCheckDone, let old = find("Choose म", in: keyboard.view) {
                press("n") // change the token before delivering the queued old tap
                old.sendActions(for: .touchUpInside)
                textIs("stale_candidate_tap_does_not_rewrite_new_token", "man")
                let pageDeadline = Date().addingTimeInterval(10)
                func checkPages() {
                    guard let more = find("More suggestions", in: keyboard.view) else {
                        if Date() < pageDeadline { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { checkPages() }; return }
                        results["candidate_page_available"] = false
                        press("Delete"); staleCheckDone = true; continueWhenReady(); return
                    }
                    results["candidate_page_available"] = more.accessibilityValue == "Page 1 of 2"
                    results["paged_controls_fit_narrow_width"] = buttonsFit(320)
                    let pageControls = ["Previous suggestions", "More suggestions", "Choose man", "Choose मन"]
                    results["paged_controls_minimum_width_320"] = pageControls.allSatisfy { label in
                        guard let button = find(label, in: keyboard.view) else { return false }
                        return button.bounds.width >= 44
                    }
                    keyboard.view.frame = CGRect(x: 0, y: 340, width: 380, height: 300)
                    let oldPageChoice = find("Choose मन", in: keyboard.view)
                    press("Choose मन")
                    results["first_page_preview_selected"] = find("Choose मन", in: keyboard.view)?.accessibilityValue == "Selected preview"
                    press("More suggestions")
                    results["candidate_page_advances"] = find("More suggestions", in: keyboard.view)?.accessibilityValue == "Page 2 of 2"
                    results["original_available_on_second_page"] = find("Choose man", in: keyboard.view) != nil
                    results["previous_page_accessibility"] = find("Previous suggestions", in: keyboard.view)?.accessibilityValue == "Page 2 of 2"
                    oldPageChoice?.sendActions(for: .touchUpInside)
                    let oldPrevious = find("Previous suggestions", in: keyboard.view)
                    press("Previous suggestions")
                    results["candidate_page_reverses"] = find("More suggestions", in: keyboard.view)?.accessibilityValue == "Page 1 of 2"
                    oldPrevious?.sendActions(for: .touchUpInside)
                    results["stale_previous_page_tap_ignored"] = find("More suggestions", in: keyboard.view)?.accessibilityValue == "Page 1 of 2"
                    results["page_change_clears_preview_and_stale_tap"] = find("Choose मन", in: keyboard.view)?.accessibilityValue != "Selected preview"
                    press("Delete") // restore ma and let its new candidates arrive
                    staleCheckDone = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { continueWhenReady() }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { checkPages() }
                return
            }
            finishTests()
        }
        func finishTests() {
        press("Choose म"); textIs("candidate_selected_keeps_roman_marked", "ma")
        let selected = find("Choose म", in: keyboard.view)
        results["candidate_preview_accessibility"] = selected?.accessibilityValue == "Selected preview" && selected?.accessibilityTraits.contains(.selected) == true
        results["candidate_preview_visibly_selected"] = selected?.backgroundColor == UIColor(white: 215/255, alpha: 1) && selected?.titleColor(for: .normal) == UIColor(white: 34/255, alpha: 1)
        results["original_deselected_on_preview"] = find("Choose ma", in: keyboard.view)?.accessibilityTraits.contains(.selected) == false
        press("Delete"); textIs("delete_restores_original_preview", "ma")
        results["delete_reselects_original"] = find("Choose ma", in: keyboard.view)?.accessibilityValue == "Original selected"
        press("Choose म"); textIs("candidate_reselected_keeps_roman_marked", "ma")
        let committedCandidateButton = find("Choose म", in: keyboard.view)
        press("Space"); textIs("space_after_candidate", "म ")
        // Once committed, there is no reliable owned range to undo through
        // UITextDocumentProxy. A queued candidate tap must not rewrite it,
        // and Delete must remain an ordinary host deletion rather than
        // pretending it can safely restore the earlier Roman word.
        committedCandidateButton?.sendActions(for: .touchUpInside)
        textIs("stale_tap_after_commit_does_not_rewrite", "म ")
        press("Delete"); textIs("delete_after_commit_is_ordinary", "म")
        press("Space"); textIs("ordinary_delete_keeps_surrounding_text", "म ")
        write("pani"); press("Space"); textIs("space_preserves_original", "म pani ")
        write("ma"); press("Delete"); textIs("delete_during_composition", "म pani m")
        press("Switch language"); textIs("switch_preserves_original", "म pani m")
        results["language_accessibility_state_english"] = find("Switch language", in: keyboard.view)?.accessibilityValue == "English"
        write("hello"); textIs("english_passthrough", "म pani mhello")
        press("Delete"); textIs("english_delete", "म pani mhell")
        press("Numbers and symbols"); press("More symbols"); press("#"); press("+"); press("Letters")
        textIs("additional_symbols_english_literal", "म pani mhell#+")
        press("Delete"); press("Delete")
        // Editing outside the controller, as a user moving the caret, while a word is active.
        press("Switch language"); write("ma")
        keyboard.selectionWillChange(text) // Injected host proves this exact UITextView.
        text.selectedRange = NSRange(location: 0, length: 0)
        let movedLocation = text.selectedRange.location
        results["caret_was_moved"] = movedLocation == 0
        press("Space")
        results["caret_move_does_not_overwrite_existing"] = text.text.contains("pani") && text.text.contains("mhell") && text.text.contains("ma")
        results["space_inserts_at_moved_caret"] = text.text == " म pani mhellma"
        press("Delete"); results["delete_at_moved_caret"] = text.text == "म pani mhellma"
        text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        write("ma")
        let beforeDisappear = text.text
        keyboard.viewWillDisappear(false)
        results["focus_loss_preserves_original"] = keyboard.testOwnershipPaused && text.text == beforeDisappear
        text.unmarkText(); keyboard.testResetAfterHostResolution()
        // Cursor movement only applies when there is no owned marked word.
        keyboard.selectionWillChange(text)
        text.text = "ab"; text.selectedRange = NSRange(location: 2, length: 0)
        press("Switch language") // English uses literal insertion.
        press("Move cursor left"); press("x"); press("Move cursor right"); press("y")
        textIs("cursor_buttons_move_and_insert", "axby")
        results["cursor_controls_fit_narrow_width"] = buttonsFit(320)
        text.text = "a🙂b"; text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        press("Move cursor left"); press("Move cursor left"); press("x")
        textIs("cursor_moves_across_emoji", "ax🙂b")
        text.text = "aकिब"; text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        press("Move cursor left"); press("Move cursor left"); press("x")
        textIs("cursor_moves_across_devanagari_cluster", "axकिब")
        if let viewEditor = keyboard.testEditor as? ViewEditor {
            viewEditor.hideContext = true
            let before = text.selectedRange
            press("Move cursor left")
            results["cursor_missing_context_does_not_move"] = text.selectedRange == before
            viewEditor.hideContext = false
        } else { results["cursor_missing_context_does_not_move"] = false }
        let oldCursor = find("Move cursor left", in: keyboard.view)
        press("Switch language"); write("ma")
        let beforeStaleCursor = text.selectedRange
        oldCursor?.sendActions(for: .touchUpInside)
        results["stale_cursor_ignored_during_composition"] = text.selectedRange == beforeStaleCursor && keyboard.testHasComposition
        press("Space")
        // Number/symbol mode preserves identifiers and returns to letters.
        keyboard.selectionWillChange(text)
        text.text = ""; text.selectedRange = NSRange(location: 0, length: 0)
        press("Numbers and symbols"); press("1"); press("2"); press("@"); press("Letters"); write("ma"); press("Space")
        textIs("symbols_and_identifier_preserved", "12@ma ")
        press("Numbers and symbols")
        let staleMoreSymbols = find("More symbols", in: keyboard.view)
        press("More symbols"); press("#"); press("_"); press("["); press("]"); press("+")
        results["additional_symbols_fit_narrow_width"] = buttonsFit(320)
        staleMoreSymbols?.sendActions(for: .touchUpInside)
        results["stale_symbol_page_control_ignored"] = find("Basic symbols", in: keyboard.view) != nil
        press("Basic symbols"); press("1"); press("Letters"); press("Space")
        textIs("additional_symbols_and_page_switch", "12@ma #_[]+1 ")
        text.text = "12@ma "; text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        press("Shift"); press("A"); press("Space")
        textIs("shift_returns_to_lowercase", "12@ma A ")
        write("ma"); press("Delete"); press("Delete"); press("Space")
        textIs("delete_entire_composition_then_space", "12@ma A  ")
        // Structured/sensitive field traits disable conversion without changing
        // the user's selected language. The host may misdeclare traits.
        results["url_trait_is_literal"] = KeyboardViewController.requiresLiteralInput(secure: false, content: nil, keyboard: .URL)
        results["email_trait_is_literal"] = KeyboardViewController.requiresLiteralInput(secure: false, content: nil, keyboard: .emailAddress)
        results["secure_trait_is_literal"] = KeyboardViewController.requiresLiteralInput(secure: true, content: nil, keyboard: .default)
        results["normal_trait_allows_nepali"] = !KeyboardViewController.requiresLiteralInput(secure: false, content: nil, keyboard: .default)
        keyboard.selectionWillChange(text)
        text.text = ""; text.selectedRange = NSRange(location: 0, length: 0)
        keyboard.testLiteralField = true
        write("ma")
        textIs("literal_field_preserves_roman", "ma")
        results["literal_field_disables_switch"] = find("Switch language", in: keyboard.view)?.isEnabled == false
        results["literal_field_hides_candidates"] = find("Choose म", in: keyboard.view) == nil
        results["literal_field_hides_all_nepali"] = find("All Nepali suggestions", in: keyboard.view) == nil
        keyboard.testLiteralField = false
        press("Space")
        results["language_restored_after_literal_field"] = find("Switch language", in: keyboard.view)?.accessibilityValue == "Nepali"
        // A distinct normal document without callbacks must not receive the
        // prior word or a queued candidate. The old mark is not rewritten.
        keyboard.selectionWillChange(text)
        text.text = ""; text.selectedRange = NSRange(location: 0, length: 0)
        write("ma")
        let oldWordButton = committedCandidateButton
        results["different_document_stale_button_exists"] = oldWordButton != nil
        let otherText = UITextView(frame: CGRect(x: 20, y: 270, width: 340, height: 50))
        text.superview?.addSubview(otherText)
        otherText.text = "target"; otherText.becomeFirstResponder()
        otherText.selectedRange = NSRange(location: 6, length: 0)
        keyboard.testEditor = ViewEditor(otherText)
        oldWordButton?.sendActions(for: .touchUpInside)
        press("Space")
        results["different_document_stale_choice_cannot_rewrite"] = otherText.text == "target" && keyboard.testOwnershipPaused
        results["different_document_leaves_old_mark_roman"] = text.text == "ma" && keyboard.testHasComposition
        text.unmarkText(); keyboard.testResetAfterHostResolution()
        otherText.removeFromSuperview()
        keyboard.testEditor = ViewEditor(text)
        text.becomeFirstResponder()
        // Two text fields may share a document identifier. A selection callback
        // delivered after the active proxy changes must never copy the old word
        // into the new field, even when that coarse identifier matches.
        keyboard.selectionWillChange(text)
        text.text = ""; text.selectedRange = NSRange(location: 0, length: 0)
        let sharedDocument = UUID()
        keyboard.testEditor = ViewEditor(text, documentIdentifier: sharedDocument)
        write("ma")
        results["same_document_test_has_active_mark"] = text.markedTextRange != nil
        let sameDocumentField = UITextView(frame: CGRect(x: 20, y: 270, width: 340, height: 50))
        text.superview?.addSubview(sameDocumentField)
        sameDocumentField.text = "target"
        sameDocumentField.selectedRange = NSRange(location: 6, length: 0)
        let sameDocumentEditor = ViewEditor(sameDocumentField, documentIdentifier: sharedDocument)
        keyboard.testEditor = sameDocumentEditor
        results["same_document_test_session_active_before_callback"] = keyboard.testHasComposition
        keyboard.selectionWillChange(sameDocumentField)
        results["same_document_other_field_callback_does_not_write"] = sameDocumentEditor.markedWrites == 0
        results["same_document_other_field_callback_does_not_copy_old_word"] = sameDocumentField.text == "target"
        results["same_document_old_field_not_rewritten"] = text.text == "ma"
        results["same_document_change_pauses_input"] = keyboard.testOwnershipPaused
        func hasAccessibilityLabel(_ label: String, in view: UIView) -> Bool {
            view.accessibilityLabel == label || view.subviews.contains { hasAccessibilityLabel(label, in: $0) }
        }
        let staleReveal = find("Show retained Roman text", in: keyboard.view)
        results["recovery_hidden_by_default"] = !hasAccessibilityLabel("Retained Roman text: ma", in: keyboard.view)
        press("Show retained Roman text")
        results["recovery_explicit_reveal"] = hasAccessibilityLabel("Retained Roman text: ma", in: keyboard.view)
        results["recovery_reveal_does_not_edit_host"] = sameDocumentField.text == "target" && sameDocumentEditor.markedWrites == 0
        press("Hide retained Roman text")
        results["recovery_hide"] = !hasAccessibilityLabel("Retained Roman text: ma", in: keyboard.view)
        staleReveal?.sendActions(for: .touchUpInside)
        results["recovery_stale_button_ignored"] = !hasAccessibilityLabel("Retained Roman text: ma", in: keyboard.view)
        keyboard.testLiteralField = true
        keyboard.textDidChange(sameDocumentField)
        results["recovery_not_offered_in_literal_field"] = find("Show retained Roman text", in: keyboard.view) == nil && !hasAccessibilityLabel("Retained Roman text: ma", in: keyboard.view)
        keyboard.testLiteralField = false
        keyboard.textDidChange(sameDocumentField)
        results["recovery_stays_hidden_after_trait_change"] = !hasAccessibilityLabel("Retained Roman text: ma", in: keyboard.view)
        let beforeRepeatedCallback = sameDocumentEditor.markedWrites
        keyboard.selectionWillChange(sameDocumentField)
        results["same_document_repeated_callback_remains_paused"] = keyboard.testOwnershipPaused && sameDocumentEditor.markedWrites == beforeRepeatedCallback
        let fieldBeforePausedKey = sameDocumentField.text
        press("Space")
        results["same_document_paused_key_does_not_edit_new_field"] = sameDocumentField.text == fieldBeforePausedKey
        text.unmarkText(); keyboard.testResetAfterHostResolution()
        sameDocumentField.removeFromSuperview()
        keyboard.testEditor = ViewEditor(text)
        text.becomeFirstResponder()
        text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        // Simulate the proxy being replaced by a sensitive field without an
        // intervening selection callback. The old Roman composition must not
        // be inserted into the new field when the user types a boundary.
        write("ma")
        let protectedText = UITextView(frame: CGRect(x: 20, y: 270, width: 340, height: 50))
        text.superview?.addSubview(protectedText)
        protectedText.text = "secret"
        protectedText.becomeFirstResponder()
        protectedText.selectedRange = NSRange(location: 6, length: 0)
        keyboard.testEditor = ViewEditor(protectedText)
        keyboard.testLiteralField = true
        press("Space")
        results["literal_transition_does_not_insert_previous_token"] = protectedText.text == "secret" && keyboard.testOwnershipPaused
        results["literal_transition_does_not_modify_old_text"] = text.text.hasSuffix("ma")
        text.unmarkText(); keyboard.testResetAfterHostResolution()
        keyboard.testEditor = ViewEditor(text)
        keyboard.testLiteralField = false
        text.becomeFirstResponder()
        text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        write("ma")
        protectedText.text = "secret"
        protectedText.becomeFirstResponder()
        protectedText.selectedRange = NSRange(location: 6, length: 0)
        keyboard.testEditor = ViewEditor(protectedText)
        keyboard.testLiteralField = true
        press("Delete")
        results["literal_transition_delete_targets_new_field"] = protectedText.text == "secret" && keyboard.testOwnershipPaused
        text.unmarkText(); keyboard.testResetAfterHostResolution()
        keyboard.testEditor = ViewEditor(text)
        keyboard.testLiteralField = false
        text.becomeFirstResponder()
        text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        write("ma")
        protectedText.text = "secret"
        protectedText.becomeFirstResponder()
        protectedText.selectedRange = NSRange(location: 6, length: 0)
        keyboard.testEditor = ViewEditor(protectedText)
        keyboard.testLiteralField = true
        keyboard.textDidChange(protectedText)
        results["literal_transition_callback_does_not_mutate_new_field"] = protectedText.text == "secret"
        results["literal_transition_callback_refreshes_ui"] = find("Switch language", in: keyboard.view)?.isEnabled == false
        text.unmarkText(); keyboard.testResetAfterHostResolution()
        protectedText.removeFromSuperview()
        text.becomeFirstResponder()
        text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
        keyboard.testEditor = ViewEditor(text)
        keyboard.testLiteralField = false
        // Keep one lookup in flight while its word is committed. A late result
        // must not appear in the following, empty composition.
        keyboard.testCandidateDelay = 0.3
        write("ma")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            press("Space")
            let textAfterCommit = text.text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                results["late_result_does_not_change_text"] = text.text == textAfterCommit
                results["late_result_does_not_show_stale_candidate"] = find("Choose म", in: keyboard.view) == nil
                keyboard.testCandidateDelay = 0
                text.text = ""; text.selectedRange = NSRange(location: 0, length: 0)
                let staleAll = find("All Nepali suggestions", in: keyboard.view)
                press("All Nepali suggestions")
                results["all_nepali_mode_enabled"] = find("All Nepali suggestions", in: keyboard.view)?.accessibilityValue == "On"
                results["all_nepali_mode_fits_narrow"] = buttonsFit(320)
                write("office")
                staleAll?.sendActions(for: .touchUpInside)
                results["all_nepali_stale_control_ignored"] = find("Switch language", in: keyboard.view)?.accessibilityValue == "All Nepali" && text.text == "office"
                var expectedSession = InputSession(); expectedSession.setLanguage(.allNepali); _ = expectedSession.append("office")
                let expected = expectedSession.candidates.first ?? ""
                let allDeadline = Date().addingTimeInterval(10)
                func finishAllNepali() {
                    if find("Choose " + expected, in: keyboard.view) == nil && Date() < allDeadline {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finishAllNepali() }; return
                    }
                    results["all_nepali_candidate_offered"] = !expected.isEmpty && expected != "office" && find("Choose " + expected, in: keyboard.view) != nil
                    results["all_nepali_original_available"] = find("Choose office", in: keyboard.view) != nil
                    if !expected.isEmpty, find("Choose " + expected, in: keyboard.view) != nil {
                        press("Choose " + expected)
                        results["all_nepali_preview_preserves_mark"] = text.text == "office"
                        press("Space")
                        results["all_nepali_choice_commits"] = text.text == expected + " "
                    } else {
                        results["all_nepali_preview_preserves_mark"] = false
                        results["all_nepali_choice_commits"] = false
                    }
                    press("Switch language")
                    results["all_nepali_can_switch_to_english"] = find("Switch language", in: keyboard.view)?.accessibilityValue == "English"
                    let path = ProcessInfo.processInfo.environment["LEKHA_TEST_RESULT"] ?? NSTemporaryDirectory() + "lekha-simulator-host.json"
                    let payload: [String: Any] = ["checks": results, "passed": results.values.allSatisfy { $0 }, "final_text": text.text ?? "", "note": "UITextView-backed injected editor; not a system keyboard extension host"]
                    do { let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]); try data.write(to: URL(fileURLWithPath: path)); print(String(decoding: data, as: UTF8.self)) } catch { print("RESULT ERROR: \(error)") }
                    exit(results.values.allSatisfy { $0 } ? 0 : 1)
                }
                finishAllNepali()
            }
        }
        }
        continueWhenReady()
    }
}
