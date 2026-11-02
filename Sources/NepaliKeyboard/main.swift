import AppKit
import NepaliCore

let appMainStarted = DispatchTime.now().uptimeNanoseconds

/// Buttons retain their generation and choice, so a queued action cannot
/// select a different word or page after the candidate row is rebuilt.
final class CandidateChoiceButton: NSButton {
    var candidateGeneration = 0
    var candidateWord: WordToken?
    var candidateValue = ""
    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + 18, height: 32)
    }
}
/// Selectable output with a transient, non-editing hover highlight.
final class InteractiveOutputTextView: NSTextView {
    var mappedWords: [RenderedWord] = [] { didSet { updateHover(nil) } }
    var onWordClick: ((RenderedWord) -> Void)?
    private var hoverTracking: NSTrackingArea?
    private var hoverWord: RenderedWord?
    private var hoverLayer: CAShapeLayer?
    var hoverHighlightIsVisible: Bool { hoverLayer?.path?.isEmpty == false && hoverLayer?.animation(forKey: "hoverFade") != nil }

    override func updateTrackingAreas() {
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area); hoverTracking = area
        super.updateTrackingAreas()
    }

    func word(at point: NSPoint) -> RenderedWord? {
        guard let layoutManager, let textContainer, layoutManager.numberOfGlyphs > 0 else { return nil }
        let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layoutManager.glyphIndex(for: local, in: textContainer)
        guard glyph < layoutManager.numberOfGlyphs else { return nil }
        let char = layoutManager.characterIndexForGlyph(at: glyph)
        guard let word = mappedWords.first(where: { NSLocationInRange(char, $0.outputRange) }) else { return nil }
        let glyphs = layoutManager.glyphRange(forCharacterRange: word.outputRange, actualCharacterRange: nil)
        var withinWord = false
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { rect, _ in
            if rect.contains(local) { withinWord = true }
        }
        return withinWord ? word : nil
    }

    override func mouseMoved(with event: NSEvent) { updateHover(word(at: convert(event.locationInWindow, from: nil))) }
    override func mouseExited(with event: NSEvent) { updateHover(nil) }
    override func mouseDown(with event: NSEvent) {
        let hit = event.clickCount == 1 ? word(at: convert(event.locationInWindow, from: nil)) : nil
        super.mouseDown(with: event)
        // Preserve native drag and double-click selection; only a plain click
        // on a mapped word selects the corresponding source token.
        if let hit, selectedRange().length == 0 { onWordClick?(hit) }
    }
    private func updateHover(_ word: RenderedWord?) {
        guard hoverWord != word else { return }
        hoverWord = word
        hoverLayer?.removeFromSuperlayer(); hoverLayer = nil
        guard let word, let layoutManager, let textContainer else { return }
        let glyphs = layoutManager.glyphRange(forCharacterRange: word.outputRange, actualCharacterRange: nil)
        let path = CGMutablePath()
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { rect, _ in
            let r = rect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y).insetBy(dx: -2, dy: -1)
            path.addRoundedRect(in: r, cornerWidth: 4, cornerHeight: 4)
        }
        wantsLayer = true
        let highlight = CAShapeLayer(); highlight.frame = bounds; highlight.path = path
        highlight.fillColor = NSColor(srgbRed: 215/255, green: 215/255, blue: 215/255, alpha: 0.14).cgColor
        highlight.isGeometryFlipped = false
        layer?.addSublayer(highlight); hoverLayer = highlight
        let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.15
        highlight.add(fade, forKey: "hoverFade")
    }
}

/// Copy button owns its cursor and feedback so it remains distinct from the
/// text view underneath it, even as that view scrolls.
final class CopyIconButton: NSButton {
    private var hoverTracking: NSTrackingArea?
    weak var feedbackLabel: NSTextField?
    private var feedbackGeneration = 0
    private var restingImage: NSImage?
    private var restingToolTip: String?
    override func updateTrackingAreas() {
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking); hoverTracking = tracking
        super.updateTrackingAreas()
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }
    override func cursorUpdate(with event: NSEvent) { (isEnabled ? NSCursor.pointingHand : NSCursor.arrow).set() }
    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        wantsLayer = true; layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        NSCursor.pointingHand.set()
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
        NSCursor.arrow.set()
    }
    func resetFeedback() {
        feedbackGeneration &+= 1
        if let restingImage { image = restingImage; toolTip = restingToolTip }
        feedbackLabel?.isHidden = true
        setAccessibilityValue(nil)
    }
    func showCopied() {
        if restingImage == nil { restingImage = image; restingToolTip = toolTip }
        feedbackGeneration &+= 1
        let generation = feedbackGeneration
        image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        toolTip = "Copied"
        feedbackLabel?.isHidden = false
        setAccessibilityValue("Copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.feedbackGeneration == generation else { return }
            self.image = self.restingImage
            self.toolTip = self.restingToolTip
            self.feedbackLabel?.isHidden = true
            self.setAccessibilityValue(nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, NSWindowDelegate, NSSearchFieldDelegate {
    var window: NSWindow!
    var settingsMode: NSSegmentedControl?
    var modeInfo: NSButton?
    var modeInfoPopover: NSPopover?
    var modePersistence: UserDefaults? = .standard
    var lastObservedMode: TypingLanguage?
    var settingsTextSize: NSSlider?
    var settingsReset: NSButton?
    var statusItem: NSStatusItem?
    var statusLanguageItem: NSMenuItem?
    var input: NSTextView!
    var output: InteractiveOutputTextView!
    var selectedOutputSource: WordToken?
    var suppressCandidateSuggestions = false
    var mode: NSSegmentedControl!
    var candidateRow: NSStackView!
    var candidateTitle: NSTextField!
    var candidatePageLabel: NSTextField!
    var candidatePrevious: NSButton!
    var candidateNext: NSButton!
    var candidatePage = 0
    var candidatePageWord: WordToken?
    var candidateGeneration = 0
    var status: NSTextField!
    var copyButton: CopyIconButton!
    var composer = Composer()
    var active: WordToken?
    var choices: [String] = []
    var refreshing = false
    var padTextSize: CGFloat = 18
    // Graphite: neutral gray surfaces and silver controls, without colored chrome.
    let ink = NSColor(srgbRed: 232/255, green: 232/255, blue: 232/255, alpha: 1)
    let muted = NSColor(srgbRed: 170/255, green: 170/255, blue: 170/255, alpha: 1)
    let accent = NSColor(srgbRed: 215/255, green: 215/255, blue: 215/255, alpha: 1)
    let onAccent = NSColor(srgbRed: 34/255, green: 34/255, blue: 34/255, alpha: 1)
    let background = NSColor(srgbRed: 30/255, green: 30/255, blue: 30/255, alpha: 1)
    let surface = NSColor(srgbRed: 39/255, green: 39/255, blue: 39/255, alpha: 1)
    let hairline = NSColor(srgbRed: 61/255, green: 61/255, blue: 61/255, alpha: 1)

    // Calculate WCAG relative contrast in sRGB for the app's opaque colors.
    func contrastRatio(_ foreground: NSColor, _ background: NSColor) -> CGFloat {
        guard let a = foreground.usingColorSpace(.sRGB), let b = background.usingColorSpace(.sRGB) else { return 0 }
        func luminance(_ color: NSColor) -> CGFloat {
            func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
        }
        let first = luminance(a), second = luminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu()
        makeWindow()
        makeStatusMenu()
        // Preview/test runs stay deterministic and do not alter preferences.
        if CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--benchmark-startup") { modePersistence = nil }
        let startupMode = modePersistence.map { preferredStartupLanguage($0) } ?? .nepali
        composer.setLanguage(startupMode)
        composer.setSource("namaste! ma office janchu.")
        refresh(syncInput: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(input)
        input.setSelectedRange(NSRange(location: 0, length: (input.string as NSString).length))
        if CommandLine.arguments.contains("--benchmark-startup") {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - appMainStarted) / 1_000_000
            print(String(format: "App main to first window ready: %.3f ms", elapsed))
            fflush(stdout)
            NSApp.terminate(nil)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--smoke-test"), CommandLine.arguments.count > index + 1 {
            let destination = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.smokeTest(destination: destination) }
        }
    }

    // Keep the menu-bar controls available when the user closes a window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showPad(nil) }
        return true
    }

    func label(_ value: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor? = nil) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color ?? ink
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        return field
    }

    func stack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = 12) -> NSStackView {
        let result = NSStackView(views: views)
        result.orientation = vertical ? .vertical : .horizontal
        result.alignment = vertical ? .leading : .centerY
        result.spacing = spacing
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }

    func button(_ title: String, action: Selector, id: String? = nil) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .rounded
        result.controlSize = .large
        if let id { result.setAccessibilityIdentifier(id) }
        return result
    }

    func flexible() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    func preferredPadTextSize(_ defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.double(forKey: "lekhaPadTextSize")
        return (16...30).contains(stored) ? stored : 18
    }

    func preferredStartupLanguage(_ defaults: UserDefaults = .standard) -> TypingLanguage {
        guard let stored = defaults.string(forKey: "lekhaPadStartupLanguage"),
              let language = TypingLanguage(rawValue: stored), language != .english else { return .nepali }
        return language
    }

    func storeStartupLanguage(_ language: TypingLanguage, defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: "lekhaPadStartupLanguage")
    }

    func pin(_ view: NSView, inside parent: NSView, inset: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }

    func textArea(editable: Bool, id: String) -> (NSScrollView, NSTextView) {
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = surface
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        // Match the scroll view's initial content width before attaching the
        // autoresizing document view. Starting at a fixed 650 points adds that
        // width again when Auto Layout sizes the initially empty scroll view.
        let frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 140)
        let text: NSTextView = editable ? NSTextView(frame: frame) : InteractiveOutputTextView(frame: frame)
        text.isEditable = editable
        text.isSelectable = true
        text.isRichText = false
        text.allowsUndo = false
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.isContinuousSpellCheckingEnabled = false
        text.font = NSFont.systemFont(ofSize: editable ? 18 : 24)
        text.textColor = ink
        text.backgroundColor = surface
        text.insertionPointColor = accent
        text.textContainerInset = NSSize(width: 10, height: 10)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.minSize = NSSize(width: 0, height: 72)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.setAccessibilityLabel(editable ? "Romanized input" : "Nepali output")
        text.setAccessibilityIdentifier(id)
        scroll.documentView = text
        return (scroll, text)
    }

    func copyIcon(action: Selector, label: String, id: String) -> CopyIconButton {
        let image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: label) ?? NSImage()
        let control = CopyIconButton(image: image, target: self, action: action)
        control.isBordered = false
        control.contentTintColor = muted
        control.toolTip = label
        control.setAccessibilityLabel(label)
        control.setAccessibilityIdentifier(id)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 32).isActive = true
        control.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return control
    }

    func editorPanel(_ scroll: NSScrollView, heading: String, action: NSView, primary: Bool = false) -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = surface.cgColor
        panel.layer?.cornerRadius = 9
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = hairline.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        let title = label(heading, size: 11, color: primary ? ink : muted)
        var headerViews: [NSView] = [title, flexible()]
        if primary {
            let feedback = label("Copied", size: 11, color: muted)
            feedback.isHidden = true
            feedback.setAccessibilityIdentifier("copy-feedback")
            copyButton.feedbackLabel = feedback
            headerViews.append(feedback)
        }
        headerViews.append(action)
        let header = stack(headerViews, vertical: false, spacing: 8)
        header.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 10)
        header.heightAnchor.constraint(equalToConstant: 35).isActive = true
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = hairline.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let contents = stack([header, line, scroll], spacing: 0)
        pin(contents, inside: panel, inset: 1)
        for view in [header, line, scroll] { view.widthAnchor.constraint(equalTo: contents.widthAnchor).isActive = true }
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        return panel
    }

    func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Lekha · Typing pad"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 520, height: 398)
        window.delegate = self
        window.center()
        window.backgroundColor = background
        window.appearance = NSAppearance(named: .darkAqua)
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = background.cgColor
        window.contentView = root

        let glyph = label("लेख", size: 25, weight: .medium, color: accent)
        let name = label("Lekha", size: 13, weight: .medium)
        mode = NSSegmentedControl(labels: ["Nepali + EN", "All Nepali"], trackingMode: .selectOne, target: self, action: #selector(modeChanged(_:)))
        mode.controlSize = .small
        mode.segmentStyle = .rounded
        mode.font = NSFont.systemFont(ofSize: 11)
        mode.selectedSegment = 0
        mode.setAccessibilityIdentifier("language-switch")
        mode.setAccessibilityLabel("Output mode")
        mode.setAccessibilityHelp("Nepali plus English keeps recognized English words. All Nepali writes English words in Nepali letters too.")
        settingsMode = mode
        let info = NSButton(image: NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Typing settings and help") ?? NSImage(), target: self, action: #selector(showModeInfo(_:)))
        info.isBordered = false
        info.contentTintColor = muted
        info.toolTip = "Typing settings and help · Nepali + EN keeps recognized English words. All Nepali writes every word in Nepali letters."
        info.setAccessibilityLabel("Typing settings and help")
        info.setAccessibilityHelp(info.toolTip)
        info.setAccessibilityIdentifier("output-mode-info")
        info.widthAnchor.constraint(equalToConstant: 24).isActive = true
        info.heightAnchor.constraint(equalToConstant: 28).isActive = true
        modeInfo = info
        let toolbar = stack([glyph, name, flexible(), mode!, info], vertical: false, spacing: 10)
        toolbar.heightAnchor.constraint(equalToConstant: 32).isActive = true

        // Settings live behind the help control instead of occupying the pad.
        let slider = NSSlider(value: preferredPadTextSize(), minValue: 16, maxValue: 30, target: self, action: #selector(textSizeChanged(_:)))
        slider.setAccessibilityLabel("Typing pad text size")
        settingsTextSize = slider
        let reset = button("Reset text size", action: #selector(resetPadSettings(_:)), id: "reset-pad-settings")
        reset.controlSize = .small
        reset.setAccessibilityHelp("Resets text size; current text and output mode remain unchanged.")
        settingsReset = reset

        let clear = button("Clear", action: #selector(clearAction(_:)), id: "clear")
        clear.isBordered = false
        clear.font = NSFont.systemFont(ofSize: 11)
        clear.contentTintColor = muted
        let (sourceScroll, sourceText) = textArea(editable: true, id: "roman-input")
        input = sourceText
        input.delegate = self
        let sourcePanel = editorPanel(sourceScroll, heading: "Roman input", action: clear)
        sourcePanel.heightAnchor.constraint(equalToConstant: 108).isActive = true

        // The title remains available as accessibility context, without a
        // visible heading line above the suggestion buttons.
        candidateTitle = label("", size: 11, color: muted)
        candidatePrevious = button("‹", action: #selector(previousCandidates(_:)), id: "candidate-previous")
        candidateNext = button("›", action: #selector(nextCandidates(_:)), id: "candidate-next")
        for control in [candidatePrevious!, candidateNext!] {
            control.controlSize = .small
            control.widthAnchor.constraint(equalToConstant: 24).isActive = true
        }
        candidatePrevious.setAccessibilityLabel("Previous suggestion page")
        candidateNext.setAccessibilityLabel("Next suggestion page")
        candidatePageLabel = label("", size: 11, color: muted)
        candidatePageLabel.setAccessibilityLabel("Suggestion page")
        candidateRow = stack([], vertical: false, spacing: 6)
        candidateRow.setContentHuggingPriority(.defaultLow, for: .horizontal)
        candidateRow.setAccessibilityLabel("Word suggestions")
        let suggestions = stack([candidateRow!, candidatePageLabel!, candidatePrevious!, candidateNext!], vertical: false, spacing: 6)
        suggestions.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let (resultScroll, resultText) = textArea(editable: false, id: "nepali-output")
        output = resultText as? InteractiveOutputTextView
        output.delegate = self
        output.selectedTextAttributes = [.backgroundColor: accent.withAlphaComponent(0.2), .foregroundColor: ink]
        output.onWordClick = { [weak self] word in self?.selectOutputWord(word) }
        padTextSize = preferredPadTextSize()
        applyPadFonts()
        copyButton = copyIcon(action: #selector(copyOutput(_:)), label: "Copy text", id: "copy-output")
        let resultPanel = editorPanel(resultScroll, heading: "नेपाली", action: copyButton, primary: true)
        resultPanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 128).isActive = true
        resultPanel.setContentHuggingPriority(.defaultLow, for: .vertical)

        let shield = NSImageView(image: NSImage(systemSymbolName: "checkmark.shield", accessibilityDescription: nil) ?? NSImage())
        shield.contentTintColor = muted
        shield.widthAnchor.constraint(equalToConstant: 13).isActive = true
        shield.heightAnchor.constraint(equalToConstant: 13).isActive = true
        status = label("Local & offline", size: 11, color: muted)
        status.maximumNumberOfLines = 1
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        status.setAccessibilityIdentifier("status")
        let footer = stack([shield, status!], vertical: false, spacing: 6)
        footer.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let main = stack([toolbar, sourcePanel, suggestions, resultPanel, footer], spacing: 11)
        pin(main, inside: root, inset: 16)
        for view in [toolbar, sourcePanel, suggestions, resultPanel, footer] { view.widthAnchor.constraint(equalTo: main.widthAnchor).isActive = true }
    }

    func makeMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Lekha", action: #selector(aboutAction(_:)), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "Getting Started…", action: #selector(guideAction(_:)), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "Typing Settings…", action: #selector(settingsAction(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Lekha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        let undo = edit.addItem(withTitle: "Undo", action: #selector(undoAction(_:)), keyEquivalent: "z"); undo.target = self
        let redo = edit.addItem(withTitle: "Redo", action: #selector(redoAction(_:)), keyEquivalent: "z"); redo.target = self; redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        let copy = edit.addItem(withTitle: "Copy Output", action: #selector(copyOutput(_:)), keyEquivalent: "c")
        copy.target = self; copy.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(withTitle: "Copy Original", action: #selector(copyOriginal(_:)), keyEquivalent: "").target = self
        let typingItem = NSMenuItem()
        menu.addItem(typingItem)
        let typing = NSMenu(title: "Typing")
        typingItem.submenu = typing
        let toggle = typing.addItem(withTitle: "Switch output mode", action: #selector(toggleLanguage(_:)), keyEquivalent: " ")
        toggle.target = self; toggle.keyEquivalentModifierMask = [.command, .shift]
        let keepOriginal = typing.addItem(withTitle: "Keep Original Word", action: #selector(keepOriginalWord(_:)), keyEquivalent: "o")
        keepOriginal.target = self; keepOriginal.keyEquivalentModifierMask = [.command, .shift]
        let previousPage = typing.addItem(withTitle: "Previous Suggestions", action: #selector(previousCandidates(_:)), keyEquivalent: "[")
        previousPage.target = self; previousPage.keyEquivalentModifierMask = [.command, .option]
        let nextPage = typing.addItem(withTitle: "Next Suggestions", action: #selector(nextCandidates(_:)), keyEquivalent: "]")
        nextPage.target = self; nextPage.keyEquivalentModifierMask = [.command, .option]
        for index in 0..<5 {
            let item = typing.addItem(withTitle: "Choose Suggestion \(index + 1)", action: #selector(candidateAction(_:)), keyEquivalent: "\(index + 1)")
            item.target = self; item.tag = index; item.keyEquivalentModifierMask = [.option]
        }
        NSApp.mainMenu = menu
    }

    func makeStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "ले"
        item.button?.setAccessibilityLabel("Lekha typing pad")
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "Open typing pad", action: #selector(showPad(_:)), keyEquivalent: "")
        open.target = self
        let current = menu.addItem(withTitle: "Pad language: Nepali", action: #selector(toggleLanguageFromMenu(_:)), keyEquivalent: "")
        current.target = self
        statusLanguageItem = current
        let settings = menu.addItem(withTitle: "Typing settings…", action: #selector(settingsAction(_:)), keyEquivalent: "")
        settings.target = self
        let guide = menu.addItem(withTitle: "Getting started…", action: #selector(guideAction(_:)), keyEquivalent: "")
        guide.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Lekha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }

    @objc func toggleLanguageFromMenu(_ sender: Any?) {
        mode.selectedSegment = mode.selectedSegment == 0 ? 1 : 0
        composer.setLanguage(mode.selectedSegment == 0 ? .nepali : .allNepali)
        refresh(syncInput: false)
        status.stringValue = composer.state.language == .allNepali ? "All Nepali" : "Nepali + EN"
    }

    @objc func showPad(_ sender: Any?) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func settingsLanguageChanged(_ sender: NSSegmentedControl) {
        mode.selectedSegment = sender.selectedSegment
        composer.setLanguage(mode.selectedSegment == 0 ? .nepali : .allNepali)
        refresh(syncInput: false)
        status.stringValue = composer.state.language == .allNepali ? "All Nepali" : "Nepali + EN"
    }

    @objc func textSizeChanged(_ sender: NSSlider) {
        padTextSize = sender.doubleValue
        applyPadFonts()
        if !CommandLine.arguments.contains("--smoke-test") && !CommandLine.arguments.contains("--benchmark-startup") {
            UserDefaults.standard.set(sender.doubleValue, forKey: "lekhaPadTextSize")
        }
    }

    func resetPadPreferences(_ defaults: UserDefaults = .standard) {
        for key in ["lekhaPadTextSize", "lekhaPadGuideSeen"] { defaults.removeObject(forKey: key) }
    }

    @objc func resetPadSettings(_ sender: Any?) {
        resetPadPreferences()
        settingsTextSize?.doubleValue = 18
        padTextSize = 18
        applyPadFonts()
        status.stringValue = "Pad settings reset · Your text and current language remain unchanged"
    }

    @objc func showModeInfo(_ sender: NSButton) {
        if modeInfoPopover?.isShown == true { modeInfoPopover?.performClose(nil); return }
        if modeInfoPopover == nil {
            let text = label("Nepali + EN keeps recognized English words.\nAll Nepali writes every word in Nepali letters.", size: 12, color: muted)
            text.preferredMaxLayoutWidth = 268
            let content = NSViewController()
            content.view = NSView(frame: NSRect(x: 0, y: 0, width: 304, height: 242))
            content.view.appearance = NSAppearance(named: .darkAqua)
            content.view.wantsLayer = true
            content.view.layer?.backgroundColor = surface.cgColor
            content.view.layer?.cornerRadius = 10
            let guide = button("Quick guide", action: #selector(guideAction(_:)), id: "quick-guide")
            guide.controlSize = .small
            let contents = stack([label("Typing settings", size: 14, weight: .medium), text,
                                  label("Text size", size: 11, color: muted), settingsTextSize!, settingsReset!, guide], spacing: 12)
            pin(contents, inside: content.view, inset: 18)
            for view in [text, settingsTextSize!] { view.widthAnchor.constraint(equalTo: contents.widthAnchor).isActive = true }
            let popover = NSPopover()
            popover.contentViewController = content
            popover.behavior = .transient
            modeInfoPopover = popover
        }
        modeInfoPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    @objc func settingsAction(_ sender: Any?) {
        showPad(sender)
        if modeInfoPopover?.isShown != true, let modeInfo { showModeInfo(modeInfo) }
    }

    @objc func guideAction(_ sender: Any?) {
        let guide = NSAlert()
        guide.messageText = "Get started with Lekha"
        guide.informativeText = "1. Type Romanized Nepali in the typing pad.\n2. Place the cursor in a word and choose a suggestion, or use ⌘⇧O to keep its original spelling.\n3. Copy the result into any app.\n\nChoose Nepali + EN to preserve English words, or All Nepali to write them in Nepali letters. Lekha works offline. The system-wide keyboard is not enabled."
        guide.addButton(withTitle: "Start typing")
        guide.runModal()
        showPad(nil)
    }

    // NSTextView may retain an emoji fallback font as the typing font after
    // inserting an emoji. Reapply the pad font to plain text so subsequent
    // spaces and letters do not inherit emoji glyph metrics. Font fallback
    // remains available for Devanagari and emoji glyphs.
    func applyPadFonts() {
        guard input != nil, output != nil else { return }
        for (view, size) in [(input!, padTextSize), (output!, padTextSize + 6)] {
            let font = view === input ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular) : NSFont.systemFont(ofSize: size)
            if let storage = view.textStorage, storage.length > 0 {
                storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))
            }
            var attributes = view.typingAttributes
            attributes[.font] = font
            view.typingAttributes = attributes
        }
    }

    func textDidChange(_ notification: Notification) {
        guard !refreshing else { return }
        applyPadFonts()
        selectedOutputSource = nil
        suppressCandidateSuggestions = false
        composer.setSource(input.string)
        status.stringValue = "Local & offline"
        refresh(syncInput: false)
        scrollOutputToInputCaret()
    }

    /// Follow edits without moving the output selection or taking keyboard focus.
    /// Word mappings account for Roman and Nepali strings having different lengths;
    /// gaps between words retain their UTF-16 length (including emoji and newlines).
    func scrollOutputToInputCaret() {
        let caret = min(input.selectedRange().location, (input.string as NSString).length)
        var position = caret
        for word in output.mappedWords {
            if caret < word.source.range.location { break }
            if caret < NSMaxRange(word.source.range) {
                position = NSMaxRange(word.outputRange)
                break
            }
            position = NSMaxRange(word.outputRange) + caret - NSMaxRange(word.source.range)
        }
        if let layout = output.layoutManager, let container = output.textContainer {
            layout.ensureLayout(for: container)
        }
        output.scrollRangeToVisible(NSRange(location: min(position, (output.string as NSString).length), length: 0))
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !refreshing, input != nil, candidateRow != nil else { return }
        if notification.object as? NSTextView === input {
            selectedOutputSource = nil
            suppressCandidateSuggestions = false
            refreshCandidates()
        } else if notification.object as? NSTextView === output, window.firstResponder === output {
            let selection = output.selectedRange()
            let mapped = output.mappedWords.first {
                selection.length == 0 ? NSLocationInRange(selection.location, $0.outputRange) : NSEqualRanges(selection, $0.outputRange)
            }
            if let mapped { adoptOutputWord(mapped, selectWord: false) }
            else {
                selectedOutputSource = nil
                suppressCandidateSuggestions = true
                refreshCandidates()
            }
        }
    }

    func selectOutputWord(_ mapped: RenderedWord) { adoptOutputWord(mapped, selectWord: true) }

    private func adoptOutputWord(_ mapped: RenderedWord, selectWord: Bool) {
        guard output.mappedWords.contains(mapped), !mapped.source.isLiteral,
              composer.engine.tokens(in: input.string).contains(mapped.source) else { return }
        refreshing = true
        input.setSelectedRange(NSRange(location: mapped.source.range.location, length: 0))
        if selectWord { output.setSelectedRange(mapped.outputRange) }
        selectedOutputSource = mapped.source
        suppressCandidateSuggestions = false
        refreshing = false
        refreshCandidates()
        window.makeFirstResponder(output)
    }

    func refresh(syncInput: Bool) {
        refreshing = true
        if syncInput {
            let oldCaret = input.selectedRange().location
            input.string = composer.state.source
            input.setSelectedRange(NSRange(location: min(oldCaret, (input.string as NSString).length), length: 0))
        }
        let rendered = composer.engine.renderWithMapping(composer.state.source, language: composer.state.language, overrides: composer.state.overrides)
        if output.string != rendered.text { copyButton?.resetFeedback() }
        output.string = rendered.text
        output.mappedWords = rendered.words
        if let selected = selectedOutputSource,
           let mapped = rendered.words.first(where: { $0.source == selected }) {
            output.setSelectedRange(mapped.outputRange)
        } else { selectedOutputSource = nil }
        applyPadFonts()
        mode.selectedSegment = composer.state.language == .nepali ? 0 : 1
        if lastObservedMode != composer.state.language {
            if let defaults = modePersistence { storeStartupLanguage(composer.state.language, defaults: defaults) }
            lastObservedMode = composer.state.language
        }
        settingsMode?.selectedSegment = mode.selectedSegment
        let languageName = mode.selectedSegment == 0 ? "Nepali + EN" : "All Nepali"
        statusItem?.button?.toolTip = "Lekha typing pad · " + languageName
        statusLanguageItem?.title = "Pad language: " + languageName + " (switch)"
        copyButton.isEnabled = !rendered.text.isEmpty
        refreshing = false
        refreshCandidates()
    }

    func refreshCandidates() {
        candidateGeneration &+= 1
        for view in candidateRow.arrangedSubviews { candidateRow.removeArrangedSubview(view); view.removeFromSuperview() }
        active = composer.engine.activeToken(in: input.string, caret: input.selectedRange().location)
        choices = []
        guard !suppressCandidateSuggestions, composer.state.language != .english, let word = active else {
            candidatePageWord = nil; candidatePage = 0
            candidatePageLabel.stringValue = ""
            candidatePrevious.isEnabled = false; candidateNext.isEnabled = false
            candidatePrevious.isHidden = true; candidateNext.isHidden = true
            candidatePageLabel.isHidden = true
            candidateTitle.stringValue = composer.state.language == .english ? "ORIGINAL MODE" : "WORD SUGGESTIONS"
            candidateRow.addArrangedSubview(label(composer.state.language == .english ? "Original text" : "Select a word for suggestions.", size: 13, color: muted))
            return
        }
        if candidatePageWord != word { candidatePageWord = word; candidatePage = 0 }
        let context = composer.engine.contextChoices(in: input.string, language: composer.state.language).first { $0.token == word }
        let uncertain = context?.uncertain == true && composer.state.overrides[word.range.location] == nil
        candidateTitle.stringValue = (uncertain ? "UNSURE — CHOOSE FOR “" : "SUGGESTIONS FOR “") + word.text.uppercased() + "”"
        candidateRow.setAccessibilityHelp(candidateTitle.stringValue)
        candidateRow.toolTip = candidateTitle.stringValue
        let all = context.map { composer.engine.contextualCandidates(for: $0) } ?? composer.engine.candidates(for: word.text)
        let alternatives = all.filter { $0 != word.text }
        let pageCount = max(1, (alternatives.count + 3) / 4)
        candidatePage = min(candidatePage, pageCount - 1)
        let start = candidatePage * 4
        choices = Array(alternatives.dropFirst(start).prefix(4))
        choices.append(word.text) // original is accessible on every page
        candidatePageLabel.stringValue = pageCount > 1 ? "\(candidatePage + 1) of \(pageCount)" : ""
        candidatePageLabel.setAccessibilityValue(pageCount > 1 ? "Page \(candidatePage + 1) of \(pageCount)" : "One page")
        candidatePrevious.isEnabled = candidatePage > 0
        candidateNext.isEnabled = candidatePage + 1 < pageCount
        candidatePrevious.isHidden = pageCount == 1
        candidateNext.isHidden = pageCount == 1
        candidatePageLabel.isHidden = pageCount == 1
        let selected = composer.state.overrides[word.range.location] ?? context?.preferred ?? all.first
        let experimental = Set(composer.engine.experimentalCandidates(for: word.text))
        let aksharantar = Set(composer.engine.aksharantarCandidates(for: word.text))
        let automaticAksharantar = composer.engine.usesAksharantarAsDefault(for: word.text) && context?.preferred == composer.engine.candidates(for: word.text).first
        for (index, choice) in choices.enumerated() {
            let marker = aksharantar.contains(choice) || (candidatePage == 0 && index == 0 && automaticAksharantar) ? " †" : (experimental.contains(choice) && choice != word.text ? " ·" : "")
            let item = CandidateChoiceButton(title: "\(choice)\(marker)  ⌥\(index + 1)", target: self, action: #selector(candidateAction(_:)))
            item.bezelStyle = .rounded; item.controlSize = .large
            item.isBordered = false
            item.wantsLayer = true
            item.layer?.cornerRadius = 6
            item.layer?.borderWidth = 1
            item.layer?.borderColor = (choice == selected ? accent : hairline).cgColor
            item.layer?.backgroundColor = (choice == selected ? accent : surface).cgColor
            item.heightAnchor.constraint(equalToConstant: 32).isActive = true
            item.cell?.lineBreakMode = .byTruncatingTail
            item.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            item.setAccessibilityIdentifier("candidate-\(index + 1)")
            item.candidateGeneration = candidateGeneration; item.candidateWord = word; item.candidateValue = choice
            item.font = NSFont.systemFont(ofSize: 14, weight: .regular)
            item.attributedTitle = NSAttributedString(string: item.title, attributes: [.font: item.font!, .foregroundColor: choice == selected ? onAccent : ink])
            item.tag = index
            item.contentTintColor = choice == selected ? accent : ink
            let source = marker == " †" ? " · Aksharantar suggestion" : (marker == " ·" ? " · Google suggestion" : "")
            item.toolTip = (choice == word.text ? "Keep original · Option \(index + 1)" : "Choose \(choice) · Option \(index + 1)") + source
            item.setAccessibilityLabel(choice == word.text ? "Keep original word \(choice)" : "Choose suggestion \(choice)")
            item.setAccessibilityValue(choice == selected ? "Selected" : "Not selected")
            item.setAccessibilityHelp((uncertain ? "Spelling uncertain. " : "") + "Option \(index + 1). The choice can be undone.")
            candidateRow.addArrangedSubview(item)
            item.widthAnchor.constraint(lessThanOrEqualTo: candidateRow.widthAnchor, multiplier: 0.18).isActive = true
        }
    }

    @objc func previousCandidates(_ sender: Any?) {
        guard candidatePrevious.isEnabled else { return }
        candidatePage -= 1; refreshCandidates()
    }
    @objc func nextCandidates(_ sender: Any?) {
        guard candidateNext.isEnabled else { return }
        candidatePage += 1; refreshCandidates()
    }

    @objc func candidateAction(_ sender: Any) {
        let index = (sender as? NSButton)?.tag ?? (sender as? NSMenuItem)?.tag ?? -1
        guard !suppressCandidateSuggestions, let word = active, choices.indices.contains(index),
              composer.engine.activeToken(in: input.string, caret: input.selectedRange().location) == word else { return }
        if let button = sender as? CandidateChoiceButton {
            guard button.candidateGeneration == candidateGeneration, button.candidateWord == word,
                  button.candidateValue == choices[index] else { return }
        } else if !(sender is NSMenuItem) { return }
        let chosen = choices[index]
        composer.choose(chosen, for: word)
        refresh(syncInput: false)
        status.stringValue = "Chosen: \(chosen) · ⌘Z to undo"
        window.makeFirstResponder(selectedOutputSource == nil ? input : output)
    }

    @objc func keepOriginalWord(_ sender: Any?) {
        guard !suppressCandidateSuggestions, let word = active, composer.state.language != .english else { return }
        composer.choose(word.text, for: word)
        refresh(syncInput: false)
        status.stringValue = "Original kept: \(word.text) · ⌘Z to undo"
        window.makeFirstResponder(input)
    }

    @objc func modeChanged(_ sender: Any?) {
        composer.setLanguage(mode.selectedSegment == 0 ? .nepali : .allNepali)
        refresh(syncInput: false)
        status.stringValue = composer.state.language == .allNepali ? "All Nepali" : "Nepali + EN"
        window.makeFirstResponder(input)
    }

    @objc func toggleLanguage(_ sender: Any?) {
        mode.selectedSegment = mode.selectedSegment == 0 ? 1 : 0
        modeChanged(sender)
    }

    @objc func undoAction(_ sender: Any?) { composer.undo(); refresh(syncInput: true); status.stringValue = "Undone · ⌘⇧Z to redo" }
    @objc func redoAction(_ sender: Any?) { composer.redo(); refresh(syncInput: true); status.stringValue = "Redone" }
    @objc func clearAction(_ sender: Any?) { composer.setSource(""); refresh(syncInput: true); window.makeFirstResponder(input); status.stringValue = "Start typing · ⌘Z restores your text" }

    @objc func copyOutput(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(composer.output, forType: .string) {
            copyButton.showCopied(); status.stringValue = "Copied"
        } else { status.stringValue = "Copy failed" }
    }

    @objc func copyOriginal(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(composer.state.source, forType: .string) {
            status.stringValue = "Original copied"
        } else { status.stringValue = "Copy failed" }
    }

    @objc func exampleAction(_ sender: NSButton) {
        let examples = ["namaste, tapai sanchai hunuhuncha?", "ma office janchu", "bholi meeting pachi bhetau"]
        composer.setSource(examples[sender.tag])
        composer.setLanguage(.nepali)
        refresh(syncInput: true)
        input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
        window.makeFirstResponder(input)
        status.stringValue = "Example loaded · Type your own words to keep going"
    }

    @objc func aboutAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Lekha · लेख"
        alert.informativeText = "A local Nepali typing prototype. Version 0.1.\n\nUses local word indexes, simple context rules and phonetic fallback. No network requests, accounts, analytics, or global keyboard monitoring.\n\nCompose here and copy into other apps. System-wide input-method integration is not included."
        alert.runModal()
    }

    func smokeTest(destination: String) {
        var checks: [String: Bool] = [:]
        func check(_ name: String, _ value: Bool) { checks[name] = value }
        print("Contrast ratios:", contrastRatio(muted, surface), contrastRatio(muted, background), contrastRatio(accent, surface))
        check("muted_text_contrast_editor", contrastRatio(muted, surface) >= 4.5)
        check("muted_text_contrast_main", contrastRatio(muted, background) >= 4.5)
        check("accent_text_contrast_editor", contrastRatio(accent, surface) >= 4.5)
        check("selected_candidate_contrast", contrastRatio(onAccent, accent) >= 4.5)
        check("larger_default_window", window.contentView!.bounds.width == 720 && window.contentView!.bounds.height == 540)
        check("night_shift_appearance", window.appearance?.name == .darkAqua)
        input.string = "ma office janchu"
        input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        check("typing_updates_preview", output.string == "म office जान्छु")
        check("copy_enabled_for_output", copyButton.isEnabled)
        check("guide_available", NSApp.mainMenu?.items.first?.submenu?.items.contains { $0.action == #selector(guideAction(_:)) } == true)
        toggleLanguage(nil)
        check("english_switch", output.string == "म \(composer.engine.phonetic("office")) जान्छु")
        settingsAction(nil)
        check("settings_reflect_language", settingsMode?.selectedSegment == 1)
        check("settings_popover_controls", settingsMode?.window === window && modeInfo?.window === window && modeInfoPopover?.isShown == true && settingsTextSize?.window != nil && settingsTextSize?.window === settingsReset?.window)
        check("menu_bar_stays_after_window_close", !applicationShouldTerminateAfterLastWindowClosed(NSApp))
        window.contentView?.layoutSubtreeIfNeeded()
        if let reset = settingsReset, let content = modeInfoPopover?.contentViewController?.view {
            check("reset_pad_control_visible", content.bounds.contains(reset.convert(reset.bounds, to: content)))
        } else { check("reset_pad_control_visible", false) }
        check("mode_info_accessible", modeInfo?.toolTip?.contains("All Nepali") == true && modeInfo?.accessibilityLabel() == "Typing settings and help")
        settingsMode?.selectedSegment = 0
        if let settingsMode { settingsLanguageChanged(settingsMode) }
        check("settings_change_language", output.string == "म office जान्छु" && mode.selectedSegment == 0)
        settingsTextSize?.doubleValue = 26
        if let settingsTextSize { textSizeChanged(settingsTextSize) }
        check("settings_text_size", input.font?.pointSize == 26 && output.font?.pointSize == 32)
        let testSuiteName = "local.lekha.pad-test.\(UUID().uuidString)"
        if let testDefaults = UserDefaults(suiteName: testSuiteName) {
            testDefaults.set(27.0, forKey: "lekhaPadTextSize")
            check("settings_saved_size", preferredPadTextSize(testDefaults) == 27)
            testDefaults.set(99.0, forKey: "lekhaPadTextSize")
            check("settings_invalid_size_fallback", preferredPadTextSize(testDefaults) == 18)
            check("startup_language_defaults_nepali", preferredStartupLanguage(testDefaults) == .nepali)
            testDefaults.set("english", forKey: "lekhaPadStartupLanguage")
            check("legacy_original_mode_defaults_to_mixed", preferredStartupLanguage(testDefaults) == .nepali)
            storeStartupLanguage(.allNepali, defaults: testDefaults)
            check("startup_language_saved", preferredStartupLanguage(testDefaults) == .allNepali)
            testDefaults.set("invalid", forKey: "lekhaPadStartupLanguage")
            check("startup_language_invalid_fallback", preferredStartupLanguage(testDefaults) == .nepali)
            modePersistence = testDefaults
            toggleLanguage(nil)
            check("mode_change_persists", preferredStartupLanguage(testDefaults) == .allNepali)
            undoAction(nil)
            check("undo_mode_persists", preferredStartupLanguage(testDefaults) == .nepali)
            redoAction(nil)
            check("redo_mode_persists", preferredStartupLanguage(testDefaults) == .allNepali)
            toggleLanguage(nil)
            check("mode_toggle_back_persists", preferredStartupLanguage(testDefaults) == .nepali)
            modePersistence = nil
            storeStartupLanguage(.allNepali, defaults: testDefaults)
            testDefaults.set(true, forKey: "lekhaPadGuideSeen")
            testDefaults.set("keep", forKey: "unrelatedPreference")
            resetPadPreferences(testDefaults)
            check("reset_pad_owned_preferences", testDefaults.object(forKey: "lekhaPadTextSize") == nil && preferredStartupLanguage(testDefaults) == .allNepali && testDefaults.object(forKey: "lekhaPadGuideSeen") == nil && testDefaults.string(forKey: "unrelatedPreference") == "keep")
            testDefaults.removePersistentDomain(forName: testSuiteName)
        } else {
            check("settings_saved_size", false)
            check("settings_invalid_size_fallback", false)
            check("startup_language_defaults_nepali", false)
            check("legacy_original_mode_defaults_to_mixed", false)
            check("startup_language_saved", false)
            check("startup_language_invalid_fallback", false)
            check("reset_pad_owned_preferences", false)
            check("mode_change_persists", false)
            check("undo_mode_persists", false)
            check("redo_mode_persists", false)
            check("mode_toggle_back_persists", false)
        }
        settingsTextSize?.doubleValue = 18
        if let settingsTextSize { textSizeChanged(settingsTextSize) }
        modeInfoPopover?.performClose(nil)
        check("menu_displays_language", statusLanguageItem?.title.contains("Nepali") == true)
        toggleLanguageFromMenu(nil)
        check("menu_changes_language", output.string == "म \(composer.engine.phonetic("office")) जान्छु" && settingsMode?.selectedSegment == 1)
        toggleLanguageFromMenu(nil)
        settingsMode?.selectedSegment = 1
        if let settingsMode { settingsLanguageChanged(settingsMode) }
        showPad(nil)
        undoAction(nil)
        check("undo_language_switch", output.string == "म office जान्छु")
        redoAction(nil)
        check("redo_language_switch", output.string == "म \(composer.engine.phonetic("office")) जान्छु")
        toggleLanguage(nil)
        input.string = "👋 ma pani"
        input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        if let second = candidateRow.arrangedSubviews.dropFirst().first as? NSButton { second.performClick(nil) }
        check("candidate_button", output.string == "👋 म पानी")
        undoAction(nil)
        check("undo_candidate", output.string == "👋 म पनि")
        redoAction(nil)
        check("redo_candidate", output.string == "👋 म पानी")
        if let selectedButton = candidateRow.arrangedSubviews.first(where: { ($0 as? NSButton)?.accessibilityValue() as? String == "Selected" }) as? NSButton {
            check("candidate_accessibility_state", selectedButton.accessibilityLabel()?.contains("पानी") == true)
        } else { check("candidate_accessibility_state", false) }
        keepOriginalWord(nil)
        check("keep_original_word", output.string == "👋 म pani")
        undoAction(nil)
        check("undo_keep_original_word", output.string == "👋 म पानी")
        // Save and restore the clipboard while verifying our own copy action.
        let saved = NSPasteboard.general.pasteboardItems?.map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } } ?? []
        if let hover = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil) {
            copyButton.mouseEntered(with: hover)
            check("copy_hover_feedback", (copyButton.layer?.backgroundColor?.alpha ?? 0) > 0 && NSCursor.current == NSCursor.pointingHand)
            copyButton.mouseExited(with: hover)
            check("copy_hover_clears", (copyButton.layer?.backgroundColor?.alpha ?? 0) == 0)
        } else { check("copy_hover_feedback", false); check("copy_hover_clears", false) }
        copyOriginal(nil)
        check("copy_input", NSPasteboard.general.string(forType: .string) == "👋 ma pani")
        check("copy_input_feedback", status.stringValue == "Original copied")
        copyButton.performClick(nil)
        check("copy_output", NSPasteboard.general.string(forType: .string) == "👋 म पानी")
        check("copy_output_feedback", copyButton.feedbackLabel?.isHidden == false && copyButton.accessibilityValue() as? String == "Copied")
        NSPasteboard.general.clearContents()
        let restored = saved.map { pairs in let item = NSPasteboardItem(); for (type, data) in pairs { item.setData(data, forType: type) }; return item }
        NSPasteboard.general.writeObjects(restored)
        clearAction(nil)
        check("clear", output.string.isEmpty && input.string.isEmpty)
        check("copy_disabled_after_clear", !copyButton.isEnabled)
        undoAction(nil)
        check("undo_clear", output.string == "👋 म पानी")
        check("copy_reenabled_after_undo", copyButton.isEnabled)
        input.string = "ma pani"
        input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        if let corrected = candidateRow.arrangedSubviews.compactMap({ $0 as? CandidateChoiceButton }).first(where: { $0.candidateValue == "पानी" }) {
            corrected.performClick(nil)
            input.string = "ma pani "
            input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
            textDidChange(Notification(name: NSText.didChangeNotification, object: input))
            check("selected_word_survives_space", output.string == "म पानी ")
            input.string = "ma pani cha."
            input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
            textDidChange(Notification(name: NSText.didChangeNotification, object: input))
            check("selected_word_survives_continued_typing", output.string == "म पानी छ।")
            input.string = "aaja ma pani cha."
            input.setSelectedRange(NSRange(location: 0, length: 0))
            textDidChange(Notification(name: NSText.didChangeNotification, object: input))
            check("selected_word_survives_earlier_edit", output.string == "आज म पानी छ।")
        } else {
            check("selected_word_survives_space", false)
            check("selected_word_survives_continued_typing", false)
            check("selected_word_survives_earlier_edit", false)
        }
        input.string = "bato"
        input.setSelectedRange(NSRange(location: 4, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        let originalPreview = output.string
        if let index = choices.firstIndex(of: "बाटो"), let button = candidateRow.arrangedSubviews[index] as? NSButton {
            check("generated_candidate_marked", button.title.contains("·"))
            button.performClick(nil)
            check("generated_candidate_selection", output.string == "बाटो")
            undoAction(nil)
            check("generated_candidate_undo", output.string == originalPreview)
        } else {
            check("generated_candidate_marked", false)
            check("generated_candidate_selection", false)
            check("generated_candidate_undo", false)
        }
        input.string = "bhaisakeko"
        input.setSelectedRange(NSRange(location: 10, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        check("uncertainty_explained", candidateTitle.stringValue.contains("UNSURE") && output.string == "भैसकेको")
        let oldPreview = output.string
        if let index = choices.firstIndex(of: "भइसकेको"), let button = candidateRow.arrangedSubviews[index] as? NSButton {
            check("aksharantar_candidate_marked", button.title.contains("†"))
            button.performClick(nil)
            check("aksharantar_candidate_selection", output.string == "भइसकेको")
            undoAction(nil)
            check("aksharantar_candidate_undo", output.string == oldPreview)
        } else {
            check("aksharantar_candidate_marked", false)
            check("aksharantar_candidate_selection", false)
            check("aksharantar_candidate_undo", false)
        }
        input.string = "man"
        input.setSelectedRange(NSRange(location: 3, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        let stale = candidateRow.arrangedSubviews.first as? CandidateChoiceButton
        let firstPage = choices
        let beforeStale = output.string
        if candidateNext.isEnabled, let stale {
            nextCandidates(nil)
            check("candidate_page_advances", candidatePage == 1 && choices != firstPage)
            check("candidate_original_on_later_page", choices.last == "man")
            candidateAction(stale)
            check("stale_candidate_action_ignored", output.string == beforeStale)
            previousCandidates(nil)
            check("candidate_page_returns", candidatePage == 0 && choices == firstPage)
        } else {
            check("candidate_page_advances", false)
            check("candidate_original_on_later_page", false)
            check("stale_candidate_action_ignored", false)
            check("candidate_page_returns", false)
        }
        let beforeLongCandidateFrame = window.frame
        window.setContentSize(NSSize(width: 520, height: 398))
        input.string = String(repeating: "a", count: 90)
        input.setSelectedRange(NSRange(location: 90, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        window.contentView?.layoutSubtreeIfNeeded()
        if let content = window.contentView, let source = input.enclosingScrollView, let result = output.enclosingScrollView {
            let sourceFrame = source.convert(source.bounds, to: content)
            let rowFrame = candidateRow.convert(candidateRow.bounds, to: content)
            let resultFrame = result.convert(result.bounds, to: content)
            check("compact_stacked_editors_fit", content.bounds.contains(sourceFrame) && content.bounds.contains(resultFrame) && content.bounds.contains(rowFrame) && sourceFrame.minY > rowFrame.maxY && rowFrame.minY > resultFrame.maxY)
        } else { check("compact_stacked_editors_fit", false) }
        let longButtons = candidateRow.arrangedSubviews.compactMap { $0 as? CandidateChoiceButton }
        check("long_candidates_fit_row", !longButtons.isEmpty && longButtons.allSatisfy { button in
            let frame = button.convert(button.bounds, to: candidateRow)
            // AppKit's rounded button frame includes a ~6-point shadow outside
            // its alignment rectangle; allow that visual margin at each edge.
            return frame.minX >= -8 && frame.maxX <= candidateRow.bounds.width + 8
        })
        check("long_original_accessible", longButtons.contains { $0.candidateValue == input.string && $0.accessibilityLabel()?.contains(input.string) == true })
        window.setFrame(beforeLongCandidateFrame, display: true)
        input.string = "👋 ma pani, ma office."
        input.setSelectedRange(NSRange(location: 0, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        let mappedWords = output.mappedWords
        if mappedWords.count == 4, let layout = output.layoutManager, let container = output.textContainer {
            let target = mappedWords[2]
            layout.ensureLayout(for: container)
            let glyphs = layout.glyphRange(forCharacterRange: target.outputRange, actualCharacterRange: nil)
            var rect = NSRect.zero
            layout.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { r, _ in rect = r }
            let point = NSPoint(x: rect.midX + output.textContainerOrigin.x, y: rect.midY + output.textContainerOrigin.y)
            check("output_word_hit_maps_repeated_word", output.word(at: point) == target)
            selectOutputWord(target)
            check("output_click_selects_exact_source", input.selectedRange().location == target.source.range.location && NSEqualRanges(output.selectedRange(), target.outputRange) && active == target.source)
            check("output_click_shows_suggestions", !choices.isEmpty && candidateTitle.stringValue.contains("MA"))
            let hoverGlyphs = layout.glyphRange(forCharacterRange: mappedWords[1].outputRange, actualCharacterRange: nil)
            var hoverRect = NSRect.zero
            layout.enumerateEnclosingRects(forGlyphRange: hoverGlyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { r, _ in hoverRect = r }
            let hoverPoint = NSPoint(x: hoverRect.midX + output.textContainerOrigin.x, y: hoverRect.midY + output.textContainerOrigin.y)
            if let event = NSEvent.mouseEvent(with: .mouseMoved, location: output.convert(hoverPoint, to: nil), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0) {
                output.mouseMoved(with: event)
                check("output_hover_animation", output.hoverHighlightIsVisible)
            } else { check("output_hover_animation", false) }
            // Capture this isolated fixture for visual review; no user text.
            if let view = window.contentView {
                view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
                try? FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
                if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    if let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("output-selected.png"))
                    }
                }
            }
            if let button = candidateRow.arrangedSubviews.compactMap({ $0 as? CandidateChoiceButton }).first(where: { $0.candidateValue == "मा" }) {
                candidateAction(button)
                let selected = output.selectedRange()
                check("output_choice_preserves_input_and_selects_result", input.string == "👋 ma pani, ma office." && (output.string as NSString).substring(with: selected) == "मा" && window.firstResponder === output)
                let oldButton = candidateRow.arrangedSubviews.first as? CandidateChoiceButton
                output.setSelectedRange(NSRange(location: 0, length: 5))
                textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification, object: output))
                let preservedSelection = output.selectedRange(), before = output.string
                if let oldButton { candidateAction(oldButton) }
                check("output_drag_selection_preserved", NSEqualRanges(output.selectedRange(), preservedSelection) && output.string == before && suppressCandidateSuggestions)
            } else {
                check("output_choice_preserves_input_and_selects_result", false)
                check("output_drag_selection_preserved", false)
            }
            let stale = target
            input.string = "changed"; input.setSelectedRange(NSRange(location: 0, length: 0))
            textDidChange(Notification(name: NSText.didChangeNotification, object: input))
            let before = output.string
            selectOutputWord(stale)
            check("stale_output_mapping_ignored", output.string == before && input.selectedRange().location == 0)
        } else {
            check("output_word_hit_maps_repeated_word", false); check("output_click_selects_exact_source", false)
            check("output_click_shows_suggestions", false); check("stale_output_mapping_ignored", false)
            check("output_hover_animation", false); check("output_choice_preserves_input_and_selects_result", false); check("output_drag_selection_preserved", false)
        }
        input.string = "the man is here"
        input.setSelectedRange(NSRange(location: 6, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        check("context_english_man", output.string == "the man is here")
        input.string = "mero man ramro cha"
        input.setSelectedRange(NSRange(location: 6, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        check("context_nepali_man", output.string == "मेरो मन राम्रो छ")
        input.string = "namaste! ma office janchu.\nbholi meeting pachi bhetau."
        input.setSelectedRange(NSRange(location: 7, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        check("multiline_mixed_text", output.string == "नमस्ते! म office जान्छु।\nभोलि meeting पछि भेटौँ।")
        check("punctuation_input_unchanged", input.string == "namaste! ma office janchu.\nbholi meeting pachi bhetau.")
        let sentence = String(repeating: "namaste ma football khelna man parchha ", count: 20)
        input.string = sentence
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        func inspectWrap(_ view: NSTextView) -> (Int, CGFloat, CGFloat) {
            guard let lm = view.layoutManager, let container = view.textContainer, let scroll = view.enclosingScrollView else { return (0, 0, 0) }
            lm.ensureLayout(for: container)
            var lines = 0
            lm.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: lm.numberOfGlyphs)) { _, _, _, _, _ in lines += 1 }
            return (lines, view.frame.width, scroll.contentView.bounds.width)
        }
        let originalFrame = window.frame
        window.setContentSize(NSSize(width: 520, height: 398))
        window.contentView?.layoutSubtreeIfNeeded()
        let narrowInput = inspectWrap(input), narrowOutput = inspectWrap(output)
        check("input_wrap_narrow", narrowInput.0 > 1 && abs(narrowInput.1 - narrowInput.2) < 2)
        check("output_wrap_narrow", narrowOutput.0 > 1 && abs(narrowOutput.1 - narrowOutput.2) < 2)
        window.setContentSize(NSSize(width: 940, height: 650))
        window.contentView?.layoutSubtreeIfNeeded()
        let wideInput = inspectWrap(input), wideOutput = inspectWrap(output)
        check("input_wrap_resize", wideInput.0 > 1 && wideInput.0 < narrowInput.0 && abs(wideInput.1 - wideInput.2) < 2)
        check("output_wrap_resize", wideOutput.0 > 1 && wideOutput.0 < narrowOutput.0 && abs(wideOutput.1 - wideOutput.2) < 2)
        print("Wrap metrics narrow input=\(narrowInput) output=\(narrowOutput); wide input=\(wideInput) output=\(wideOutput)")
        window.setFrame(originalFrame, display: true)
        window.contentView?.layoutSubtreeIfNeeded()
        window.makeFirstResponder(input)
        input.string = String(repeating: "👋 ma office janchu. ", count: 80)
        input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        func outputEndIsVisible() -> Bool {
            guard let layout = output.layoutManager, let container = output.textContainer,
                  let scroll = output.enclosingScrollView else { return false }
            layout.ensureLayout(for: container)
            let rect: NSRect
            if output.string.hasSuffix("\n") {
                rect = layout.extraLineFragmentRect
            } else {
                let glyph = layout.glyphIndexForCharacter(at: (output.string as NSString).length - 1)
                rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            }
            let point = NSPoint(x: rect.minX + output.textContainerOrigin.x,
                                y: rect.midY + output.textContainerOrigin.y)
            return scroll.documentVisibleRect.contains(point)
        }
        check("long_paragraph_output_follows_end", outputEndIsVisible() && output.visibleRect.minY > 0)
        output.scrollRangeToVisible(NSRange(location: 0, length: 0))
        input.insertText("namaste", replacementRange: input.selectedRange())
        check("typing_scrolls_output_back_to_end", outputEndIsVisible() && window.firstResponder === input)
        input.insertText("\n", replacementRange: input.selectedRange())
        check("trailing_newline_output_visible", outputEndIsVisible())
        if let view = window.contentView {
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("long-paragraph.png"))
                }
            }
        }
        input.setSelectedRange(NSRange(location: 0, length: 0))
        input.insertText("namaste ", replacementRange: input.selectedRange())
        check("editing_start_reveals_start_of_output", output.visibleRect.minY < 1 && window.firstResponder === input)
        input.string = "namaste! ma office janchu.\nbholi meeting pachi bhetau."
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        // Simulate text changes through the same delegate and layout path used
        // by the editor. This excludes OS key event delivery and cold launch.
        func editTimings(words: Int) -> [String: Double] {
            var samples: [Double] = []
            let text = String(repeating: "ma office janchu ", count: words / 3)
            for i in 0..<30 {
                let start = DispatchTime.now().uptimeNanoseconds
                input.string = text + String(i)
                input.setSelectedRange(NSRange(location: (input.string as NSString).length, length: 0))
                textDidChange(Notification(name: NSText.didChangeNotification, object: input))
                window.contentView?.layoutSubtreeIfNeeded()
                window.contentView?.displayIfNeeded()
                samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            }
            samples.sort()
            return ["p50_ms": samples[15], "p95_ms": samples[28], "p99_ms": samples[29], "samples": Double(samples.count)]
        }
        let editPerformance = ["short_9_words": editTimings(words: 9), "long_99_words": editTimings(words: 99)]
        input.string = "namaste! ma office janchu.\nbholi meeting pachi bhetau."
        textDidChange(Notification(name: NSText.didChangeNotification, object: input))
        status.stringValue = "Local & offline"
        if let lm = input.layoutManager, let tc = input.textContainer {
            lm.ensureLayout(for: tc)
            let start = lm.location(forGlyphAt: lm.glyphIndexForCharacter(at: 8)).x
            let end = lm.location(forGlyphAt: lm.glyphIndexForCharacter(at: 9)).x
            check("normal_space_width_after_emoji", end - start < padTextSize * 0.7)
        } else { check("normal_space_width_after_emoji", false) }
        if let lm = output.layoutManager, let tc = output.textContainer {
            lm.ensureLayout(for: tc)
            let index = (output.string as NSString).range(of: " ").location
            if index != NSNotFound && index + 1 < (output.string as NSString).length {
                let start = lm.location(forGlyphAt: lm.glyphIndexForCharacter(at: index)).x
                let end = lm.location(forGlyphAt: lm.glyphIndexForCharacter(at: index + 1)).x
                check("normal_output_space_width_after_emoji", end - start < (padTextSize + 6) * 0.7)
            } else { check("normal_output_space_width_after_emoji", false) }
        } else { check("normal_output_space_width_after_emoji", false) }
        let sampleWord = (input.string as NSString).range(of: "bhetau")
        input.setSelectedRange(NSRange(location: sampleWord.location + 2, length: 0))
        window.makeFirstResponder(input)
        refreshCandidates()
        copyButton.feedbackLabel?.isHidden = true
        window.contentView?.layoutSubtreeIfNeeded()
        do {
            try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
            let view = window.contentView!
            if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("prototype.png"))
                }
            }
            let payload: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "output": output.string, "source": input.string, "edit_timing": editPerformance]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: destination).appendingPathComponent("ui-smoke-test.json"))
            print(String(data: data, encoding: .utf8)!)
        } catch { fputs("UI smoke test failed: \(error)\n", stderr) }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
