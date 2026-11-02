import UIKit

/// Small editing boundary; UIKit's proxy remains the production implementation.
protocol LekhaDocumentEditing: AnyObject {
    var documentIdentifier: UUID? { get }
    var contextBefore: String? { get }
    var contextAfter: String? { get }
    func ownsSelectionSource(_ input: UITextInput?) -> Bool
    func setMarkedText(_ text: String, selectedRange: NSRange)
    func unmarkText()
    func insertText(_ text: String)
    func deleteBackward()
    func adjustTextPosition(byCharacterOffset offset: Int)
}

private final class ProxyEditor: LekhaDocumentEditing {
    private weak var owner: UIInputViewController?
    init(_ owner: UIInputViewController) { self.owner = owner }
    var documentIdentifier: UUID? { owner?.textDocumentProxy.documentIdentifier }
    var contextBefore: String? { owner?.textDocumentProxy.documentContextBeforeInput }
    var contextAfter: String? { owner?.textDocumentProxy.documentContextAfterInput }
    // The proxy exposes no stable identity of the selected field.
    func ownsSelectionSource(_ input: UITextInput?) -> Bool { false }
    func setMarkedText(_ text: String, selectedRange: NSRange) { owner?.textDocumentProxy.setMarkedText(text, selectedRange: selectedRange) }
    func unmarkText() { owner?.textDocumentProxy.unmarkText() }
    func insertText(_ text: String) { owner?.textDocumentProxy.insertText(text) }
    func deleteBackward() { owner?.textDocumentProxy.deleteBackward() }
    func adjustTextPosition(byCharacterOffset offset: Int) { owner?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset) }
}

/// Experimental offline IME. Real-host composition behavior is not yet verified.
final class KeyboardViewController: UIInputViewController {
    private var stack: UIStackView!
    private var shifted = false
    private var symbolsVisible = false
    private var alternateSymbols = false
    private var editingDocument = false
    // An external selection/focus event cannot establish which field owns the
    // mark. Keep the original in memory and reject host edits until teardown.
    private var ownershipPaused = false
    private var retainedTextRevealed = false
    private var session = InputSession()
    private let candidateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Lekha candidate lookup"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var candidateGeneration = 0
    private var presentedCandidates: [String] = []
    private var candidatePage = 0
    private var candidatePresentationID = 0
    // Preview stays marked until a boundary so it can be reverted without editing committed host text.
    private var selectedPreview: String?
    // Coarse document binding; not proof that a marked range is still owned.
    private var compositionDocumentID: UUID?
    private var compositionEditor: LekhaDocumentEditing?
    // Test hosts can inject a UITextView-backed editor without enabling an IME.
    var testEditor: LekhaDocumentEditing?
    var testCandidateDelay: TimeInterval = 0
    var testHasComposition: Bool { session.isComposing }
    var testOwnershipPaused: Bool { ownershipPaused }
    // Harness only: models a fresh controller after its old host resolves a mark.
    func testResetAfterHostResolution() { abandonComposition(); ownershipPaused = false; if isViewLoaded { render() } }
    // Test host can supply traits without impersonating UIKit's document proxy.
    var testLiteralField: Bool?
    private lazy var proxyEditor: LekhaDocumentEditing = ProxyEditor(self)
    private var editor: LekhaDocumentEditing { testEditor ?? proxyEditor }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(white: 30/255, alpha: 1)
        stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 5; stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])
        render()
    }

    /// Sensitive or structured host fields use literal input. Host traits can
    /// be absent or misdeclared, so this is a guard, not a security guarantee.
    private var literalField: Bool {
        if let testLiteralField { return testLiteralField }
        let proxy = textDocumentProxy
        return Self.requiresLiteralInput(secure: proxy.isSecureTextEntry == true,
                                         content: proxy.textContentType,
                                         keyboard: proxy.keyboardType)
    }

    static func requiresLiteralInput(secure: Bool, content: UITextContentType?, keyboard: UIKeyboardType?) -> Bool {
        if secure { return true }
        if let content, [.password, .newPassword, .oneTimeCode].contains(content) { return true }
        switch keyboard {
        case .URL, .emailAddress, .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad: return true
        default: return false
        }
    }

    private func render() {
        for child in stack.arrangedSubviews { stack.removeArrangedSubview(child); child.removeFromSuperview() }
        let candidates = UIStackView(); candidates.axis = .horizontal; candidates.spacing = 3; candidates.distribution = .fillEqually
        // Every re-render invalidates previously queued touches, including a
        // button from a different page of the same composition.
        candidatePresentationID &+= 1
        if session.isComposing && !literalField && !ownershipPaused {
            for value in displayedCandidates() {
                let choice = key(value, label: "Choose " + value, action: #selector(chooseCandidate(_:)))
                // Events queued for a previous word must not select a later one.
                choice.tag = candidatePresentationID
                let isOriginal = value == session.roman
                let isSelected = isOriginal ? selectedPreview == nil : selectedPreview == value
                choice.accessibilityHint = isOriginal
                    ? "Keep the original Roman text when you press space or return"
                    : "Select this spelling; the text stays Roman until you press space or return. Delete clears the selection."
                if isSelected {
                    choice.accessibilityValue = isOriginal ? "Original selected" : "Selected preview"
                    choice.accessibilityTraits.insert(.selected)
                    choice.backgroundColor = UIColor(white: 215/255, alpha: 1)
                    choice.setTitleColor(UIColor(white: 34/255, alpha: 1), for: .normal)
                }
                candidates.addArrangedSubview(choice)
            }
            let pageCount = candidatePageCount()
            if pageCount > 1 {
                let previous = key("◀", label: "Previous suggestions", action: #selector(previousCandidatePage(_:)))
                previous.tag = candidatePresentationID
                previous.accessibilityValue = "Page \(candidatePage + 1) of \(pageCount)"
                previous.accessibilityHint = "Show the previous page of candidate spellings"
                candidates.addArrangedSubview(previous)
                let more = key("▶", label: "More suggestions", action: #selector(nextCandidatePage(_:)))
                more.tag = candidatePresentationID
                more.accessibilityValue = "Page \(candidatePage + 1) of \(pageCount)"
                more.accessibilityHint = "Show the next page of candidate spellings"
                candidates.addArrangedSubview(more)
            }
        } else {
            let hint = UILabel()
            if ownershipPaused && retainedTextRevealed && !literalField {
                // Revealed only after the user's explicit action; never inserted
                // into the current host, copied, logged or persisted.
                hint.text = session.roman
                hint.accessibilityLabel = "Retained Roman text: " + session.roman
            } else {
                hint.text = ownershipPaused ? "Input paused · Text may be unresolved" : (literalField ? "Literal input for this field" : (session.language == .english ? "English · literal typing" : (session.language == .allNepali ? "All Nepali · choose a suggestion" : "Type Nepali using Roman letters")))
            }
            hint.textColor = UIColor(white: 170/255, alpha: 1)
            hint.textAlignment = .center; hint.font = .preferredFont(forTextStyle: .caption1)
            hint.adjustsFontSizeToFitWidth = true; hint.minimumScaleFactor = 0.5
            if !ownershipPaused && !session.isComposing {
                let left = key("←", label: "Move cursor left", action: #selector(moveCursorLeft(_:)))
                left.accessibilityHint = "Move the insertion point left"
                candidates.addArrangedSubview(left)
            }
            candidates.addArrangedSubview(hint)
            if !ownershipPaused && !session.isComposing && !literalField {
                let all = key(session.language == .allNepali ? "All ✓" : "All", label: "All Nepali suggestions", action: #selector(toggleAllNepali(_:)))
                all.accessibilityValue = session.language == .allNepali ? "On" : "Off"
                all.accessibilityHint = "Show Nepali spellings for English words. Select a suggestion before pressing space."
                candidates.addArrangedSubview(all)
            }
            if !ownershipPaused && !session.isComposing {
                let right = key("→", label: "Move cursor right", action: #selector(moveCursorRight(_:)))
                right.accessibilityHint = "Move the insertion point right"
                candidates.addArrangedSubview(right)
            }
            if ownershipPaused && session.isComposing && !literalField {
                let reveal = key(retainedTextRevealed ? "Hide" : "Show", label: retainedTextRevealed ? "Hide retained Roman text" : "Show retained Roman text", action: #selector(toggleRetainedText(_:)))
                reveal.isEnabled = true
                reveal.accessibilityHint = "Shows the retained word on screen for manual recovery. It does not edit the current field."
                candidates.addArrangedSubview(reveal)
            }
        }
        stack.addArrangedSubview(candidates)
        let rows: [String]
        if symbolsVisible {
            rows = alternateSymbols ? ["[]{}#%^*+=", "_\\|~<>€£¥", ".,?!'"] : ["1234567890", "-/:;()$&@\"", ".,?!'"]
        } else {
            rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        }
        for (index, letters) in rows.enumerated() {
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 3; row.distribution = .fillEqually
            if index == 2 && symbolsVisible {
                let more = key(alternateSymbols ? "123" : "#+=", label: alternateSymbols ? "Basic symbols" : "More symbols", action: #selector(toggleSymbolPage(_:)))
                more.accessibilityHint = alternateSymbols ? "Show numbers and basic symbols" : "Show more punctuation and symbols"
                row.addArrangedSubview(more)
            }
            if index == 2 && !symbolsVisible {
                let shift = key(shifted ? "⇧ On" : "⇧", label: "Shift", action: #selector(toggleShift(_:)))
                shift.accessibilityValue = shifted ? "On" : "Off"
                shift.accessibilityHint = "Capitalizes the next letter"
                row.addArrangedSubview(shift)
            }
            for letter in letters {
                let value = shifted && !symbolsVisible ? String(letter).uppercased() : String(letter)
                row.addArrangedSubview(key(value, label: value, action: #selector(typeKey(_:))))
            }
            if index == 2 { row.addArrangedSubview(key("⌫", label: "Delete", action: #selector(deleteKey(_:)))) }
            stack.addArrangedSubview(row)
        }
        let row = UIStackView(); row.axis = .horizontal; row.spacing = 3; row.distribution = .fillProportionally
        if needsInputModeSwitchKey {
            let globe = key("🌐", label: "Next keyboard", action: nil)
            globe.isEnabled = true
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            row.addArrangedSubview(globe)
        }
        let layout = key(symbolsVisible ? "ABC" : "123", label: symbolsVisible ? "Letters" : "Numbers and symbols", action: #selector(toggleSymbols(_:)))
        layout.accessibilityHint = symbolsVisible ? "Show the letter keyboard" : "Show numbers and symbols"
        row.addArrangedSubview(layout)
        let language = key(session.language == .english ? "EN / ने" : "ने / EN", label: "Switch language", action: #selector(toggleLanguage(_:)))
        language.accessibilityValue = literalField ? "Literal field" : (session.language == .english ? "English" : (session.language == .allNepali ? "All Nepali" : "Nepali"))
        language.accessibilityHint = literalField ? "Language switching is unavailable in this field" : "Switch between Nepali candidates and literal English"
        language.isEnabled = !literalField && !ownershipPaused
        row.addArrangedSubview(language)
        row.addArrangedSubview(key(",", label: "Comma", action: #selector(typeKey(_:))))
        let space = key("space", label: "Space", action: #selector(spaceKey(_:)))
        // Leave room for the other controls on narrow phones and with a globe key.
        space.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        row.addArrangedSubview(space)
        row.addArrangedSubview(key(".", label: "Period", action: #selector(typeKey(_:))))
        row.addArrangedSubview(key("↵", label: "Return", action: #selector(returnKey(_:))))
        stack.addArrangedSubview(row)
    }

    @objc private func toggleRetainedText(_ sender: UIButton) {
        guard ownershipPaused, session.isComposing, !literalField, sender.tag == candidatePresentationID else { return }
        retainedTextRevealed.toggle()
        render()
    }

    private func candidatePageCount() -> Int {
        let count = presentedCandidates.filter { $0 != session.roman }.count
        return max(1, (count + 2) / 3)
    }

    private func displayedCandidates() -> [String] {
        guard session.isComposing else { return [] }
        let alternatives = presentedCandidates.filter { $0 != session.roman }
        let page = min(candidatePage, candidatePageCount() - 1)
        let start = min(page * 3, alternatives.count)
        return Array(alternatives.dropFirst(start).prefix(3)) + [session.roman]
    }

    @objc private func nextCandidatePage(_ sender: UIButton) {
        guard !ownershipPaused, session.isComposing, !literalField, sender.tag == candidatePresentationID else { return }
        candidatePage = (candidatePage + 1) % candidatePageCount()
        // Never keep a selection active when its button becomes invisible.
        selectedPreview = nil
        render()
    }

    @objc private func previousCandidatePage(_ sender: UIButton) {
        guard !ownershipPaused, session.isComposing, !literalField, sender.tag == candidatePresentationID else { return }
        candidatePage = (candidatePage - 1 + candidatePageCount()) % candidatePageCount()
        // A preview cannot remain active after its button has disappeared.
        selectedPreview = nil
        render()
    }

    private func key(_ title: String, label: String, action: Selector?) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        // Reject queued touches from a layout or document that has since changed.
        button.tag = candidatePresentationID
        button.accessibilityLabel = label
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.isEnabled = !ownershipPaused
        button.backgroundColor = UIColor(white: 39/255, alpha: 1)
        button.setTitleColor(UIColor(white: 232/255, alpha: 1), for: .normal)
        button.setTitleColor(UIColor(white: 120/255, alpha: 1), for: .disabled)
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor(white: 61/255, alpha: 1).cgColor
        button.isAccessibilityElement = true
        button.layer.cornerRadius = 5
        if let action { button.addTarget(self, action: action, for: .touchUpInside) }
        return button
    }

    private func edit(_ operation: () -> Void) {
        let previous = editingDocument
        editingDocument = true
        defer { editingDocument = previous }
        operation()
    }
    // Lookup must never block the UI. Each snapshot is tied to the active word;
    // pending operations are coalesced and stale results cannot change a later word.
    private func updateCandidates() {
        candidateGeneration += 1
        let generation = candidateGeneration
        candidateQueue.cancelAllOperations()
        guard session.isComposing else { presentedCandidates = []; return }
        let snapshot = session
        let original = snapshot.roman
        let delay = testCandidateDelay
        presentedCandidates = [original]
        candidatePage = 0
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            if delay > 0 { Thread.sleep(forTimeInterval: delay) }
            let choices = Array(snapshot.candidates.filter { $0 != original }.prefix(12)) + [original]
            guard !operation.isCancelled else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !operation.isCancelled,
                      self.candidateGeneration == generation, self.session.roman == original,
                      self.session.isComposing, !self.literalField else { return }
                self.ensureSameDocument()
                guard self.session.isComposing else {
                    if self.isViewLoaded { self.render() }
                    return
                }
                self.presentedCandidates = choices
                if self.isViewLoaded { self.render() }
            }
        }
        candidateQueue.addOperation(operation)
    }
    /// Stop tracking an unverified mark without writing to the current host.
    /// Its old host may keep or discard it; this does not guarantee recovery.
    private func abandonComposition() {
        retainedTextRevealed = false
        _ = session.cancel()
        compositionDocumentID = nil
        compositionEditor = nil
        selectedPreview = nil
        updateCandidates()
    }
    private func ensureSameDocument() {
        guard session.isComposing else { compositionDocumentID = nil; return }
        guard let expected = compositionDocumentID, let current = editor.documentIdentifier,
              expected == current else { abandonComposition(); return }
    }
    private func refreshMarked() {
        let text = session.roman
        edit {
            editor.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
            if !session.isComposing { editor.unmarkText() }
        }
    }
    private func commitOriginal() {
        // Traits can change as the host moves to another field. A previously
        // marked token is not proven to belong to the newly protected proxy;
        // discard only our in-memory state instead of writing it there.
        if literalField {
            abandonComposition()
            return
        }
        ensureSameDocument()
        guard let original = session.cancel() else { return }
        compositionDocumentID = nil
        compositionEditor = nil
        selectedPreview = nil
        updateCandidates()
        edit {
            editor.setMarkedText(original, selectedRange: NSRange(location: (original as NSString).length, length: 0))
            editor.unmarkText()
        }
    }
    // External host callbacks do not identify the owner of a marked range.
    // Avoid writing a previous word to whichever field is now active. A host
    // can deliver our own callbacks asynchronously, which may end a word early.
    private func pauseForUnverifiedHostChange() {
        guard session.isComposing else { return }
        retainedTextRevealed = false
        ownershipPaused = true
        candidateGeneration &+= 1
        candidateQueue.cancelAllOperations()
        presentedCandidates = []
        selectedPreview = nil
        if isViewLoaded { render() }
    }
    override func selectionWillChange(_ textInput: UITextInput?) {
        if !editingDocument {
            // The injected simulator editor can prove UITextView identity;
            // the system proxy cannot, so production takes the pause branch.
            if !ownershipPaused, let originalEditor = compositionEditor, editor === originalEditor, editor.ownsSelectionSource(textInput) { commitOriginal() }
            else { pauseForUnverifiedHostChange() }
            if isViewLoaded { render() }
        }
        super.selectionWillChange(textInput)
    }
    override func textWillChange(_ textInput: UITextInput?) {
        if !editingDocument { pauseForUnverifiedHostChange() }
        super.textWillChange(textInput)
    }
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if !editingDocument {
            pauseForUnverifiedHostChange()
            if isViewLoaded { render() }
        }
    }
    @objc private func typeKey(_ sender: UIButton) {
        guard !ownershipPaused, sender.tag == candidatePresentationID, let value = sender.currentTitle else { return }
        ensureSameDocument()
        if literalField { commitOriginal(); edit { editor.insertText(value) } }
        else if !session.isComposing && editor.documentIdentifier == nil {
            // No document identity: literal typing avoids an unbound mark.
            edit { editor.insertText(value) }
        }
        else if session.append(value) {
            if compositionDocumentID == nil { compositionDocumentID = editor.documentIdentifier; compositionEditor = editor }
            selectedPreview = nil; refreshMarked(); updateCandidates()
        }
        else { commitOriginal(); edit { editor.insertText(value) } }
        if shifted { shifted = false }
        render()
    }
    @objc private func chooseCandidate(_ sender: UIButton) {
        guard !ownershipPaused, sender.tag == candidatePresentationID else { return }
        ensureSameDocument()
        guard !literalField, let chosen = sender.currentTitle,
              session.isComposing, displayedCandidates().contains(chosen) else { return }
        // Retain ownership of marked text: the choice is a preview until a
        // boundary. This makes undo possible without rewriting committed text.
        selectedPreview = chosen == session.roman ? nil : chosen
        // Keep the Roman mark unchanged until explicit acceptance. This avoids
        // leaving a converted preview in a host after an unverified focus change.
        render()
    }
    @objc private func toggleLanguage(_ sender: UIButton) {
        guard !ownershipPaused, sender.tag == candidatePresentationID, !literalField else { return }
        commitOriginal()
        session.setLanguage(session.language == .english ? .nepali : .english)
        render()
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: session.language == .nepali ? "Nepali" : "English")
        }
    }
    @objc private func toggleAllNepali(_ sender: UIButton) {
        guard !ownershipPaused, !session.isComposing, !literalField, sender.tag == candidatePresentationID else { return }
        session.setLanguage(session.language == .allNepali ? .nepali : .allNepali)
        render()
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: session.language == .allNepali ? "All Nepali suggestions" : "Nepali suggestions")
        }
    }
    // A stale cursor control must never move the caret during a marked word.
    // In that state the user first commits or restores the original token.
    private func moveCursor(_ sender: UIButton, offset: Int) {
        guard !ownershipPaused, !session.isComposing, sender.tag == candidatePresentationID else { return }
        // Use the adjacent grapheme's UTF-16 length, as required by the
        // injected UITextView host. Real proxy offset behavior and truncated
        // context still require system-extension testing. With no context,
        // do nothing instead of guessing a boundary.
        let adjacent = offset < 0 ? editor.contextBefore?.last : editor.contextAfter?.first
        guard let adjacent else { return }
        let distance = String(adjacent).utf16.count * offset
        edit { editor.adjustTextPosition(byCharacterOffset: distance) }
    }
    @objc private func moveCursorLeft(_ sender: UIButton) { moveCursor(sender, offset: -1) }
    @objc private func moveCursorRight(_ sender: UIButton) { moveCursor(sender, offset: 1) }
    @objc private func toggleShift(_ sender: UIButton) { guard !ownershipPaused, sender.tag == candidatePresentationID else { return }; shifted.toggle(); render() }
    @objc private func toggleSymbols(_ sender: UIButton) { guard !ownershipPaused, sender.tag == candidatePresentationID else { return }; symbolsVisible.toggle(); alternateSymbols = false; shifted = false; render() }
    @objc private func toggleSymbolPage(_ sender: UIButton) { guard !ownershipPaused, symbolsVisible, sender.tag == candidatePresentationID else { return }; alternateSymbols.toggle(); render() }
    @objc private func deleteKey(_ sender: UIButton) {
        guard !ownershipPaused, sender.tag == candidatePresentationID else { return }
        ensureSameDocument()
        // The host may have switched to a literal-only field without a
        // selection callback. Never apply the old composition there.
        if literalField && session.isComposing { commitOriginal() }
        // One Delete after preview restores the exact Roman token. A second
        // Delete edits that token normally; never rewrite committed host text.
        if selectedPreview != nil {
            selectedPreview = nil
            refreshMarked(); render(); return
        }
        if session.backspace() { refreshMarked(); updateCandidates(); render() } else { edit { editor.deleteBackward() } }
    }
    private func commitPreviewOrOriginal() {
        ensureSameDocument()
        if literalField { commitOriginal(); return }
        guard let preview = selectedPreview, session.isComposing else { commitOriginal(); return }
        _ = session.cancel()
        compositionDocumentID = nil
        compositionEditor = nil
        selectedPreview = nil
        updateCandidates()
        edit {
            editor.setMarkedText(preview, selectedRange: NSRange(location: (preview as NSString).length, length: 0))
            editor.unmarkText()
        }
    }
    @objc private func spaceKey(_ sender: UIButton) { guard !ownershipPaused, sender.tag == candidatePresentationID else { return }; commitPreviewOrOriginal(); edit { editor.insertText(" ") }; render() }
    @objc private func returnKey(_ sender: UIButton) { guard !ownershipPaused, sender.tag == candidatePresentationID else { return }; commitPreviewOrOriginal(); edit { editor.insertText("\n") }; render() }

    override func viewWillDisappear(_ animated: Bool) {
        // Disappearance does not establish which field owns the current proxy.
        // Never commit the old token into an unverified current field.
        pauseForUnverifiedHostChange()
        super.viewWillDisappear(animated)
    }
}
