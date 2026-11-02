import UIKit

#if !NEPTYPE_CONTAINER_TEST
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = WelcomeViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif

private enum Graphite {
    static let background = UIColor(white: 30/255, alpha: 1)
    static let surface = UIColor(white: 39/255, alpha: 1)
    static let ink = UIColor(white: 232/255, alpha: 1)
    static let muted = UIColor(white: 170/255, alpha: 1)
    static let line = UIColor(white: 61/255, alpha: 1)
    static let accent = UIColor(white: 215/255, alpha: 1)
    static let onAccent = UIColor(white: 34/255, alpha: 1)
}

/// Standalone local typing pad. Keyboard setup is an explicit action in help.
final class WelcomeViewController: UIViewController, UITextViewDelegate {
    private let input = UITextView()
    private let output = UITextView()
    private let candidates = UIStackView()
    private let mode = UISegmentedControl(items: ["Nepali + EN", "All Nepali"])
    private let copy = UIButton(type: .system)
    private let status = UILabel()
    private let sizeValue = UILabel()
    private var composer = Composer()
    private let queue = DispatchQueue(label: "app.neptype.pad.render", qos: .userInitiated)
    private var generation = 0
    private var copyGeneration = 0
    private var syncing = false
    private var points: CGFloat = 18
    private var work: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Graphite.background
        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "typing-pad-scroll"
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.alwaysBounceVertical = true
        let brand = label("NepType", size: 18, color: Graphite.ink)
        brand.adjustsFontSizeToFitWidth = true
        brand.minimumScaleFactor = 0.75
        brand.accessibilityLabel = "NepType"
        mode.selectedSegmentIndex = 0
        mode.accessibilityLabel = "Output mode"
        mode.accessibilityIdentifier = "language-switch"
        mode.selectedSegmentTintColor = Graphite.line
        mode.setTitleTextAttributes([.foregroundColor: Graphite.muted, .font: UIFont.systemFont(ofSize: 11)], for: .normal)
        mode.setTitleTextAttributes([.foregroundColor: Graphite.ink], for: .selected)
        mode.widthAnchor.constraint(equalToConstant: 166).isActive = true
        mode.heightAnchor.constraint(equalToConstant: 36).isActive = true
        mode.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        let help = icon("questionmark.circle", label: "Typing settings and help", action: #selector(showHelp))
        help.accessibilityIdentifier = "typing-help"
        let toolbar = row([brand, UIView(), mode, help], spacing: 8)
        toolbar.accessibilityIdentifier = "typing-toolbar"
        toolbar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        configure(input, editable: true)
        input.accessibilityLabel = "Roman input"
        input.accessibilityIdentifier = "roman-input"
        input.delegate = self
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        input.smartQuotesType = .no
        input.smartDashesType = .no
        input.keyboardAppearance = .dark
        input.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        let clear = UIButton(type: .system)
        clear.setTitle("Clear", for: .normal)
        clear.titleLabel?.font = .systemFont(ofSize: 12)
        clear.tintColor = Graphite.muted
        clear.accessibilityIdentifier = "clear"
        clear.widthAnchor.constraint(equalToConstant: 44).isActive = true
        clear.heightAnchor.constraint(equalToConstant: 44).isActive = true
        clear.addTarget(self, action: #selector(clearText), for: .touchUpInside)
        let source = panel(input, heading: "Roman input", action: clear)
        let dock = UIView()
        dock.accessibilityIdentifier = "suggestion-dock"
        dock.backgroundColor = Graphite.surface
        dock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dock)
        let dockLine = UIView()
        dockLine.backgroundColor = Graphite.line
        dockLine.translatesAutoresizingMaskIntoConstraints = false
        dock.addSubview(dockLine)
        let candidateScroll = UIScrollView()
        candidateScroll.accessibilityIdentifier = "word-suggestions"
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateScroll.accessibilityLabel = "Word suggestions"
        candidateScroll.translatesAutoresizingMaskIntoConstraints = false
        dock.addSubview(candidateScroll)
        candidates.axis = .horizontal
        candidates.spacing = 8
        candidates.distribution = .fillEqually
        candidates.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidates)
        NSLayoutConstraint.activate([
            candidates.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor, constant: 4),
            candidates.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor, constant: -4),
            candidates.widthAnchor.constraint(greaterThanOrEqualTo: candidateScroll.frameLayoutGuide.widthAnchor, constant: -8),
            candidates.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor, constant: 4),
            candidates.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor, constant: -4),
            candidates.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor, constant: -8)
        ])
        configure(output, editable: false)
        output.accessibilityLabel = "Nepali output"
        output.accessibilityIdentifier = "nepali-output"
        output.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
        copy.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copy.tintColor = Graphite.muted
        copy.accessibilityLabel = "Copy text"
        copy.accessibilityIdentifier = "copy-output"
        copy.widthAnchor.constraint(equalToConstant: 44).isActive = true
        copy.heightAnchor.constraint(equalToConstant: 44).isActive = true
        copy.contentHorizontalAlignment = .center
        copy.contentVerticalAlignment = .center
        copy.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .regular), forImageIn: .normal)
        copy.addTarget(self, action: #selector(copyText), for: .touchUpInside)
        status.font = .preferredFont(forTextStyle: .caption1)
        status.textColor = Graphite.muted
        status.accessibilityIdentifier = "status"
        status.isHidden = true
        let result = panel(output, heading: "नेपाली", action: copy, feedback: status)
        let content = UIStackView(arrangedSubviews: [source, result])
        content.accessibilityIdentifier = "document-stack"
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        let canvas = UIView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(canvas)
        canvas.addSubview(content)
        let toolbarWidth = toolbar.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32)
        toolbarWidth.priority = .init(999)
        let contentWidth = content.widthAnchor.constraint(equalTo: canvas.widthAnchor, constant: -32)
        contentWidth.priority = .init(999)
        let dockWidth = candidateScroll.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -16)
        dockWidth.priority = .init(999)
        let preferredCanvasHeight = canvas.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        preferredCanvasHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            toolbar.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            toolbar.widthAnchor.constraint(lessThanOrEqualToConstant: 392), toolbarWidth,
            toolbar.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            // UIKit moves this edge with the software keyboard, including
            // interactive dismissal. The candidate strip never overlays it.
            dock.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            dock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dock.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dock.heightAnchor.constraint(equalToConstant: 52),
            dockLine.leadingAnchor.constraint(equalTo: dock.leadingAnchor),
            dockLine.trailingAnchor.constraint(equalTo: dock.trailingAnchor),
            dockLine.topAnchor.constraint(equalTo: dock.topAnchor),
            dockLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            candidateScroll.topAnchor.constraint(equalTo: dock.topAnchor),
            candidateScroll.bottomAnchor.constraint(equalTo: dock.bottomAnchor),
            candidateScroll.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            candidateScroll.widthAnchor.constraint(lessThanOrEqualToConstant: 392), dockWidth,
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: dock.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            canvas.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            canvas.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor), preferredCanvasHeight,
            // Center short documents in the available space. Long documents
            // and large text grow the scroll canvas instead of being clipped.
            content.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 360), contentWidth,
            content.leadingAnchor.constraint(greaterThanOrEqualTo: canvas.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(lessThanOrEqualTo: canvas.trailingAnchor, constant: -16),
            content.topAnchor.constraint(greaterThanOrEqualTo: canvas.topAnchor, constant: 12),
            content.bottomAnchor.constraint(lessThanOrEqualTo: canvas.bottomAnchor, constant: -12)
        ])
        applyFonts()
        input.text = "namaste! ma office janchu."
        composer.setSource(input.text)
        refresh()
    }

    private func configure(_ text: UITextView, editable: Bool) {
        text.isEditable = editable
        text.isSelectable = true
        text.isScrollEnabled = false
        text.backgroundColor = .clear
        text.textColor = Graphite.ink
        text.tintColor = Graphite.accent
        text.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 12, right: 10)
        text.adjustsFontForContentSizeCategory = true
    }
    private func applyFonts() {
        input.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: points, weight: .regular))
        output.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: points + 6))
        sizeValue.text = "\(Int(points)) pt · typing pad only"
    }
    private func label(_ text: String, size: CGFloat, color: UIColor = Graphite.muted) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size))
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
    private func row(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal; row.alignment = .center; row.spacing = spacing
        return row
    }
    private func icon(_ name: String, label: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: name), for: .normal)
        button.tintColor = Graphite.muted
        button.accessibilityLabel = label
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    private func panel(_ text: UITextView, heading: String, action: UIButton, feedback: UILabel? = nil) -> UIView {
        let title = label(heading, size: 12)
        title.numberOfLines = 1
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        var views: [UIView] = [title, UIView()]
        if let feedback { views.append(feedback) }
        views.append(action)
        let header = row(views, spacing: 8)
        header.heightAnchor.constraint(equalToConstant: 44).isActive = true
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 6)
        let divider = UIView()
        divider.backgroundColor = Graphite.line
        divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        let panel = UIStackView(arrangedSubviews: [header, divider, text])
        panel.axis = .vertical
        panel.backgroundColor = Graphite.surface
        panel.layer.cornerRadius = 9
        panel.layer.borderWidth = 1
        panel.layer.borderColor = Graphite.line.cgColor
        panel.clipsToBounds = true
        return panel
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !syncing, textView === input else { return }
        composer.setSource(input.text)
        refresh()
    }
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !syncing, textView === input else { return }
        refresh()
    }
    @objc private func modeChanged() {
        composer.setLanguage(mode.selectedSegmentIndex == 0 ? .nepali : .allNepali)
        refresh()
    }
    private func refresh() {
        generation &+= 1
        let current = generation
        work?.cancel()
        copyGeneration &+= 1
        copy.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copy.accessibilityValue = nil
        copy.isEnabled = false
        for view in candidates.arrangedSubviews { candidates.removeArrangedSubview(view); view.removeFromSuperview() }
        let snapshot = composer
        let caret = input.selectedRange.location
        status.text = nil
        status.isHidden = true
        let task = DispatchWorkItem { [weak self] in
            let result = snapshot.output
            let token = snapshot.engine.activeToken(in: snapshot.state.source, caret: caret)
            let context = snapshot.engine.contextChoices(in: snapshot.state.source, language: snapshot.state.language).first { $0.token == token }
            let choices = context.map { snapshot.engine.contextualCandidates(for: $0) } ?? token.map { snapshot.engine.candidates(for: $0.text) } ?? []
            DispatchQueue.main.async {
                guard let self, self.generation == current else { return }
                self.output.text = result
                self.copy.isEnabled = !result.isEmpty
                if let token {
                    let alternatives = choices.filter { $0 != token.text }
                    // Horizontal scrolling keeps every choice reachable on iPhone.
                    let visible = alternatives + [token.text]
                    let selected = snapshot.state.overrides[token.range.location] ?? context?.preferred ?? choices.first
                    for (index, value) in visible.enumerated() {
                        var config = UIButton.Configuration.plain()
                        config.title = value
                        config.baseForegroundColor = value == selected ? Graphite.onAccent : Graphite.ink
                        config.background.backgroundColor = value == selected ? Graphite.accent : Graphite.surface
                        config.background.cornerRadius = 6
                        config.background.strokeColor = Graphite.line
                        config.background.strokeWidth = 1
                        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                        let button = UIButton(configuration: config)
                        button.accessibilityIdentifier = "candidate-\(index)"
                        button.accessibilityLabel = value == token.text ? "Keep original word \(value)" : "Choose suggestion \(value)"
                        button.accessibilityValue = value == selected ? "Selected" : "Not selected"
                        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                        button.addAction(UIAction { [weak self] _ in
                            guard let self, self.generation == current, self.composer.state.source == snapshot.state.source else { return }
                            self.composer.choose(value, for: token)
                            self.refresh()
                        }, for: .touchUpInside)
                        self.candidates.addArrangedSubview(button)
                    }
                }
            }
        }
        work = task
        queue.async(execute: task)
    }
    @objc private func clearText() {
        syncing = true
        input.text = ""
        composer.setSource("")
        syncing = false
        refresh()
    }
    @objc private func copyText() {
        guard copy.isEnabled, !output.text.isEmpty else { return }
        UIPasteboard.general.string = output.text
        copyGeneration &+= 1
        let current = copyGeneration
        copy.setImage(UIImage(systemName: "checkmark"), for: .normal)
        copy.accessibilityValue = "Copied"
        status.text = "Copied"
        status.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.copyGeneration == current else { return }
            self.copy.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            self.copy.accessibilityValue = nil
            self.status.text = nil
            self.status.isHidden = true
        }
    }
    @objc private func showHelp() {
        let help = UIViewController()
        help.overrideUserInterfaceStyle = .dark
        help.view.backgroundColor = Graphite.background
        let guidance = label("Use NepType in other apps\n\n1. Open iPhone Settings → General → Keyboard → Keyboards.\n2. Tap Add New Keyboard and choose NepType.\n3. Hold the globe key to choose NepType.\n\nIn the keyboard, tap a suggestion to preview it. Space or Return accepts; Delete restores the Roman word before commit.\n\nThe keyboard is experimental. It does not request Full Access or send typing to a service.", size: 14, color: Graphite.ink)
        let slider = UISlider()
        slider.minimumValue = 16; slider.maximumValue = 28; slider.value = Float(points)
        slider.tintColor = Graphite.accent
        slider.accessibilityLabel = "Typing pad text size"
        slider.accessibilityHint = "Changes this typing pad only, not the keyboard extension."
        slider.addTarget(self, action: #selector(changeSize(_:)), for: .valueChanged)
        sizeValue.font = .preferredFont(forTextStyle: .caption1)
        sizeValue.textColor = Graphite.muted
        let open = UIButton(type: .system)
        open.setTitle("Open NepType settings", for: .normal)
        open.tintColor = Graphite.accent
        open.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        let content = UIStackView(arrangedSubviews: [guidance, sizeValue, slider, open])
        content.axis = .vertical; content.spacing = 14; content.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        help.view.addSubview(scroll); scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: help.view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: help.view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: help.view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: help.view.safeAreaLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        help.modalPresentationStyle = .pageSheet
        help.sheetPresentationController?.detents = [.medium(), .large()]
        present(help, animated: true)
    }
    @objc private func changeSize(_ sender: UISlider) { points = CGFloat(sender.value.rounded()); applyFonts() }
    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
