import UIKit

/// Small editing boundary; UIKit's proxy remains the production implementation.
protocol NepTypeDocumentEditing: AnyObject {
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

private final class ProxyEditor: NepTypeDocumentEditing {
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
    private var manualShift: Bool?
    private var shifted: Bool {
        get { manualShift ?? automaticShift }
        set { manualShift = newValue }
    }
    var testAutoCapitalization: UITextAutocapitalizationType?
    private var automaticShift: Bool {
        guard !session.isComposing, let context = editor.contextBefore else { return false }
        switch testAutoCapitalization ?? textDocumentProxy.autocapitalizationType {
        case .allCharacters: return true
        case .words: return context.isEmpty || context.last?.isWhitespace == true
        case .sentences:
            if context.isEmpty || context.last == "\n" { return true }
            let preceding = context.trimmingCharacters(in: .whitespaces)
            return preceding.isEmpty || (context.last?.isWhitespace == true && preceding.last.map { ".!?।".contains($0) } == true)
        default: return false
        }
    }
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
        queue.name = "NepType candidate lookup"
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
    private var compositionEditor: NepTypeDocumentEditing?
    // Test hosts can inject a UITextView-backed editor without enabling an IME.
    var testEditor: NepTypeDocumentEditing?
    var testCandidateDelay: TimeInterval = 0
    var testHasComposition: Bool { session.isComposing }
    var testOwnershipPaused: Bool { ownershipPaused }
    // Harness only: models a fresh controller after its old host resolves a mark.
    func testResetAfterHostResolution() { abandonComposition(); ownershipPaused = false; manualShift = nil; if isViewLoaded { render() } }
    // Test host can supply traits without impersonating UIKit's document proxy.
    var testLiteralField: Bool?
    private lazy var proxyEditor: NepTypeDocumentEditing = ProxyEditor(self)
    private var editor: NepTypeDocumentEditing { testEditor ?? proxyEditor }

    private var preferredHeight: NSLayoutConstraint!
    private var rowsStack: UIStackView!
    private var candidateBarHeight: NSLayoutConstraint!
    private var compactKeyboard = false

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshAppearance()
        view.backgroundColor = KeyboardColors.background
        inputView?.allowsSelfSizing = true
        stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        preferredHeight = view.heightAnchor.constraint(equalToConstant: 271)
        preferredHeight.priority = .init(999)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6.5),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6.5),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            preferredHeight
        ])
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let compact = UIDevice.current.userInterfaceIdiom == .phone && view.bounds.width > 600
        if compactKeyboard != compact {
            compactKeyboard = compact
            preferredHeight.constant = compact ? 218 : 271
            candidateBarHeight?.constant = compact ? 36 : 44
            rowsStack?.spacing = compact ? 6 : 11
            stack.spacing = compact ? 6 : 8
        }
    }

    private func refreshAppearance() {
        switch textDocumentProxy.keyboardAppearance {
        case .dark: overrideUserInterfaceStyle = .dark
        case .light: overrideUserInterfaceStyle = .light
        default: overrideUserInterfaceStyle = .unspecified
        }
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
        // Keep the key grid independent of suggestions so asynchronous lookups
        // cannot change key positions or the size of the spacebar.
        candidatePresentationID &+= 1
        let bar = UIStackView()
        bar.accessibilityIdentifier = "prediction-row"
        bar.axis = .horizontal
        bar.spacing = 0
        candidateBarHeight = bar.heightAnchor.constraint(equalToConstant: compactKeyboard ? 36 : 44)
        candidateBarHeight.isActive = true

        let predictions = UIStackView()
        predictions.axis = .horizontal
        predictions.distribution = .fillEqually
        predictions.tag = candidatePresentationID
        if session.isComposing && !literalField && !ownershipPaused {
            for value in displayedCandidates() {
                let choice = key(value, label: "Choose " + value, action: #selector(chooseCandidate(_:)))
                stylePrediction(choice)
                let isOriginal = value == session.roman
                let selected = isOriginal ? selectedPreview == nil : selectedPreview == value
                choice.accessibilityHint = isOriginal
                    ? "Keep the original Roman text when you press space or return"
                    : "Select this spelling; space or return accepts it. Swipe the suggestions for more spellings."
                if selected {
                    choice.accessibilityValue = isOriginal ? "Original selected" : "Selected preview"
                    choice.accessibilityTraits.insert(.selected)
                    choice.restingFill = KeyboardColors.selectedPrediction
                    choice.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
                }
                predictions.addArrangedSubview(choice)
                addPredictionDivider(to: choice)
            }
            while predictions.arrangedSubviews.count < 3 {
                let empty = UIView()
                addPredictionDivider(to: empty)
                predictions.addArrangedSubview(empty)
            }
            let previous = UISwipeGestureRecognizer(target: self, action: #selector(swipeCandidates(_:)))
            previous.direction = .right
            let next = UISwipeGestureRecognizer(target: self, action: #selector(swipeCandidates(_:)))
            next.direction = .left
            predictions.addGestureRecognizer(previous)
            predictions.addGestureRecognizer(next)
        } else if ownershipPaused {
            let hint = UILabel()
            if retainedTextRevealed && !literalField {
                hint.text = session.roman
                hint.accessibilityLabel = "Retained Roman text: " + session.roman
            } else {
                hint.text = "Input paused · switch keyboards"
            }
            hint.textColor = KeyboardColors.secondaryText
            hint.font = .systemFont(ofSize: 13)
            hint.textAlignment = .center
            hint.adjustsFontSizeToFitWidth = true
            hint.minimumScaleFactor = 0.6
            predictions.addArrangedSubview(hint)
            if session.isComposing && !literalField {
                let reveal = key(retainedTextRevealed ? "Hide" : "Show", label: retainedTextRevealed ? "Hide retained Roman text" : "Show retained Roman text", action: #selector(toggleRetainedText(_:)))
                stylePrediction(reveal)
                reveal.isEnabled = true
                reveal.accessibilityHint = "Shows the retained word for manual recovery without editing the field."
                predictions.addArrangedSubview(reveal)
            }
        } else {
            for index in 0..<3 {
                let cell = UIView()
                if index == 1 {
                    let language = UILabel()
                    language.text = literalField || session.language == .english ? "English" : "नेपाली"
                    language.font = .systemFont(ofSize: 16)
                    language.textColor = KeyboardColors.secondaryText
                    language.textAlignment = .center
                    language.translatesAutoresizingMaskIntoConstraints = false
                    cell.addSubview(language)
                    NSLayoutConstraint.activate([
                        language.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                        language.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                    ])
                }
                addPredictionDivider(to: cell)
                predictions.addArrangedSubview(cell)
            }
        }
        bar.addArrangedSubview(predictions)
        let language = key("अA", label: "Switch language", action: #selector(toggleLanguage(_:)))
        stylePrediction(language)
        language.widthAnchor.constraint(equalToConstant: 44).isActive = true
        language.accessibilityValue = literalField ? "Literal field" : (session.language == .english ? "English" : (session.language == .allNepali ? "All Nepali" : "Nepali"))
        language.accessibilityHint = "Tap to switch Nepali and English. Touch and hold for language, suggestions, and cursor options."
        language.isEnabled = !literalField && !ownershipPaused
        language.menu = optionsMenu(for: language)
        bar.addArrangedSubview(language)
        stack.addArrangedSubview(bar)

        rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = compactKeyboard ? 6 : 11
        rowsStack.distribution = .fillEqually
        let rows: [String]
        if symbolsVisible {
            rows = alternateSymbols ? ["[]{}#%^*+=", "_\\|~<>€£¥", ".,?!'"] : ["1234567890", "-/:;()$&@\"", ".,?!'"]
        } else {
            rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        }
        for (index, letters) in rows.enumerated() {
            var buttons: [UIButton] = []
            if index == 2 {
                if symbolsVisible {
                    let more = key(alternateSymbols ? "123" : "#+=", label: alternateSymbols ? "Basic symbols" : "More symbols", action: #selector(toggleSymbolPage(_:)))
                    more.titleLabel?.font = .systemFont(ofSize: 16)
                    buttons.append(more)
                } else {
                    let shift = key("", label: "Shift", action: #selector(toggleShift(_:)))
                    shift.setImage(UIImage(systemName: shifted ? "shift.fill" : "shift"), for: .normal)
                    shift.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular), forImageIn: .normal)
                    shift.accessibilityValue = shifted ? "On" : "Off"
                    shift.accessibilityHint = "Capitalizes the next letter"
                    buttons.append(shift)
                }
            }
            for letter in letters {
                let value = shifted && !symbolsVisible ? String(letter).uppercased() : String(letter)
                let letterKey = key(value, label: value, action: #selector(typeKey(_:)))
                letterKey.titleLabel?.font = .systemFont(ofSize: symbolsVisible ? 20 : 22)
                buttons.append(letterKey)
            }
            if index == 2 {
                let delete = key("", label: "Delete", action: #selector(deleteKey(_:)))
                delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
                delete.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular), forImageIn: .normal)
                buttons.append(delete)
            }
            let row = NativeKeyRow(buttons: buttons, arrangement: index == 2 ? .third : .characters)
            row.accessibilityIdentifier = "key-row-\(index)"
            rowsStack.addArrangedSubview(row)
        }
        let numbers = key(symbolsVisible ? "ABC" : "123", label: symbolsVisible ? "Letters" : "Numbers and symbols", action: #selector(toggleSymbols(_:)))
        numbers.titleLabel?.font = .systemFont(ofSize: 20)
        var bottom: [UIButton] = [numbers]
        if needsInputModeSwitchKey {
            let globe = key("", label: "Next keyboard", action: nil)
            globe.setImage(UIImage(systemName: "globe"), for: .normal)
            globe.setPreferredSymbolConfiguration(.init(pointSize: 22), forImageIn: .normal)
            globe.isEnabled = true
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            bottom.append(globe)
        }
        let space = key("", label: "Space", action: #selector(spaceKey(_:)))
        let indicator = UILabel()
        indicator.text = literalField || session.language == .english ? "EN" : "ने"
        indicator.font = .systemFont(ofSize: 10)
        indicator.textColor = KeyboardColors.secondaryText
        indicator.isAccessibilityElement = false
        indicator.translatesAutoresizingMaskIntoConstraints = false
        space.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.trailingAnchor.constraint(equalTo: space.trailingAnchor, constant: -6),
            indicator.bottomAnchor.constraint(equalTo: space.bottomAnchor, constant: -4)
        ])
        bottom.append(space)
        let enter = key("", label: "Return", action: #selector(returnKey(_:)))
        enter.setImage(UIImage(systemName: "return"), for: .normal)
        enter.setPreferredSymbolConfiguration(.init(pointSize: 24), forImageIn: .normal)
        bottom.append(enter)
        let bottomRow = NativeKeyRow(buttons: bottom, arrangement: .bottom)
        bottomRow.accessibilityIdentifier = "key-row-bottom"
        rowsStack.addArrangedSubview(bottomRow)
        stack.addArrangedSubview(rowsStack)
    }

    private func stylePrediction(_ button: NativeKeyButton) {
        button.restingFill = .clear
        button.titleLabel?.font = .systemFont(ofSize: 17)
        button.layer.cornerRadius = 5
        button.layer.shadowOpacity = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
    }

    private func addPredictionDivider(to cell: UIView) {
        let line = UIView()
        line.backgroundColor = KeyboardColors.divider
        line.isUserInteractionEnabled = false
        line.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(line)
        NSLayoutConstraint.activate([
            line.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            line.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            line.heightAnchor.constraint(equalTo: cell.heightAnchor, multiplier: 0.65)
        ])
    }

    private func optionsMenu(for button: UIButton) -> UIMenu {
        guard !literalField, !ownershipPaused else { return UIMenu(children: []) }
        var actions: [UIMenuElement] = []
        func action(_ title: String, state: UIMenuElement.State = .off, subtitle: String? = nil, handler: @escaping (UIButton) -> Void) -> UIAction {
            let item = UIAction(title: title, state: state) { [weak button] _ in
                guard let button else { return }
                handler(button)
            }
            item.subtitle = subtitle
            return item
        }
        if !session.isComposing {
            actions.append(action("All Nepali suggestions", state: session.language == .allNepali ? .on : .off) { [weak self] in self?.toggleAllNepali($0) })
            actions.append(action("Move cursor left") { [weak self] in self?.moveCursorLeft($0) })
            actions.append(action("Move cursor right") { [weak self] in self?.moveCursorRight($0) })
        } else if candidatePageCount() > 1 {
            actions.append(action("Previous suggestions", subtitle: "Page \(candidatePage + 1) of \(candidatePageCount())") { [weak self] in self?.previousCandidatePage($0) })
            actions.append(action("More suggestions", subtitle: "Page \(candidatePage + 1) of \(candidatePageCount())") { [weak self] in self?.nextCandidatePage($0) })
        }
        return UIMenu(title: "Keyboard options", children: actions)
    }

    @objc private func swipeCandidates(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.view?.tag == candidatePresentationID else { return }
        changeCandidatePage(by: gesture.direction == .left ? 1 : -1, presentation: candidatePresentationID)
    }

    @objc private func toggleRetainedText(_ sender: UIButton) {
        guard ownershipPaused, session.isComposing, !literalField, sender.tag == candidatePresentationID else { return }
        retainedTextRevealed.toggle()
        render()
    }

    private func candidatePageCount() -> Int {
        let count = presentedCandidates.filter { $0 != session.roman }.count
        return max(1, (count + 1) / 2)
    }

    private func displayedCandidates() -> [String] {
        guard session.isComposing else { return [] }
        let alternatives = presentedCandidates.filter { $0 != session.roman }
        let page = min(candidatePage, candidatePageCount() - 1)
        let start = min(page * 2, alternatives.count)
        return [session.roman] + Array(alternatives.dropFirst(start).prefix(2))
    }

    private func changeCandidatePage(by offset: Int, presentation: Int) {
        guard !ownershipPaused, session.isComposing, !literalField, presentation == candidatePresentationID else { return }
        candidatePage = (candidatePage + offset + candidatePageCount()) % candidatePageCount()
        selectedPreview = nil
        render()
    }
    @objc private func nextCandidatePage(_ sender: UIButton) { changeCandidatePage(by: 1, presentation: sender.tag) }
    @objc private func previousCandidatePage(_ sender: UIButton) { changeCandidatePage(by: -1, presentation: sender.tag) }

    private func key(_ title: String, label: String, action: Selector?) -> NativeKeyButton {
        let button = NativeKeyButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.tag = candidatePresentationID
        button.accessibilityLabel = label
        button.titleLabel?.font = .systemFont(ofSize: 22)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.isEnabled = !ownershipPaused
        button.restingFill = KeyboardColors.key
        button.setTitleColor(KeyboardColors.text, for: .normal)
        button.setTitleColor(KeyboardColors.secondaryText, for: .disabled)
        button.tintColor = KeyboardColors.text
        button.isAccessibilityElement = true
        button.layer.cornerRadius = 9
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0.5
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
        refreshAppearance()
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
        manualShift = nil
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


private enum KeyboardColors {
    static let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 22/255, green: 22/255, blue: 24/255, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1) }
    static let key = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 59/255, alpha: 1) : .white }
    static let text = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    static let secondaryText = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.65, alpha: 1) : UIColor(white: 0.38, alpha: 1) }
    static let divider = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.25, alpha: 1) : UIColor(white: 0.65, alpha: 1) }
    static let selectedPrediction = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.24, alpha: 1) : UIColor(white: 0.94, alpha: 1) }
    static let pressed = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.48, alpha: 1) : UIColor(white: 0.9, alpha: 1) }
}

private final class NativeKeyButton: UIButton {
    var restingFill: UIColor = .clear { didSet { if !isHighlighted { backgroundColor = restingFill } } }
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? KeyboardColors.pressed : restingFill }
    }
}

/// Fixed QWERTY pitches preserve the same stagger on each row. This avoids
/// UIStackView stretching nine home-row keys across the width of ten top-row keys.
private final class NativeKeyRow: UIView {
    enum Arrangement { case characters, third, bottom }
    let buttons: [UIButton]
    let arrangement: Arrangement
    init(buttons: [UIButton], arrangement: Arrangement) {
        self.buttons = buttons
        self.arrangement = arrangement
        super.init(frame: .zero)
        buttons.forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let gap: CGFloat = 6
        let keyWidth = max(1, (bounds.width - 9 * gap) / 10)
        func place(_ button: UIButton, x: CGFloat, width: CGFloat) {
            button.frame = CGRect(x: x, y: 0, width: max(1, width), height: bounds.height)
        }
        switch arrangement {
        case .characters:
            let total = CGFloat(buttons.count) * keyWidth + CGFloat(buttons.count - 1) * gap
            let start = (bounds.width - total) / 2
            for (index, button) in buttons.enumerated() { place(button, x: start + CGFloat(index) * (keyWidth + gap), width: keyWidth) }
        case .third:
            guard let first = buttons.first, let last = buttons.last else { return }
            let functionWidth = keyWidth * 1.35
            place(first, x: 0, width: functionWidth)
            place(last, x: bounds.width - functionWidth, width: functionWidth)
            let middle = Array(buttons.dropFirst().dropLast())
            let middleWidth = 7 * keyWidth + 6 * gap
            let width = (middleWidth - CGFloat(middle.count - 1) * gap) / CGFloat(middle.count)
            let start = (bounds.width - middleWidth) / 2
            for (index, button) in middle.enumerated() { place(button, x: start + CGFloat(index) * (width + gap), width: width) }
        case .bottom:
            guard let first = buttons.first, let last = buttons.last, buttons.count >= 3 else { return }
            let endWidth = bounds.width * 0.24
            place(first, x: 0, width: buttons.count == 4 ? (endWidth - gap) / 2 : endWidth)
            if buttons.count == 4 { place(buttons[1], x: (endWidth - gap) / 2 + gap, width: (endWidth - gap) / 2) }
            place(last, x: bounds.width - endWidth, width: endWidth)
            place(buttons[buttons.count - 2], x: endWidth + gap, width: bounds.width - 2 * endWidth - 2 * gap)
        }
    }
}
