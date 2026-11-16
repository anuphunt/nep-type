import UIKit

#if !NEPTYPE_CONTAINER_TEST
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppAnalytics.shared.start()
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// iOS 27 requires UIScene lifecycle adoption; apps that create their window
/// in the app delegate are terminated at launch.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = WelcomeViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
    func sceneDidBecomeActive(_ scene: UIScene) { AppAnalytics.shared.becameActive() }
    func sceneDidEnterBackground(_ scene: UIScene) {
        (window?.rootViewController as? WelcomeViewController)?.flushDraft()
        AppAnalytics.shared.backgrounded()
    }
}
#endif

/// The device being set up, so iPad users are not told to open iPhone settings.
enum DeviceCopy {
    static var name: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }
}

private enum Graphite {
    static let background = UIColor(white: 30/255, alpha: 1)
    static let surface = UIColor(white: 39/255, alpha: 1)
    static let ink = UIColor(white: 232/255, alpha: 1)
    static let muted = UIColor(white: 170/255, alpha: 1)
    static let line = UIColor(white: 61/255, alpha: 1)
    static let accent = UIColor(white: 215/255, alpha: 1)
    static let onAccent = UIColor(white: 34/255, alpha: 1)
}

/// Standalone local typing pad with a first-launch keyboard setup guide.
final class WelcomeViewController: UIViewController, UITextViewDelegate {
    private static let setupPresentedKey = "neptype.keyboardSetupPresented.v1"
    private let setupDefaults: UserDefaults
    private let experience: LocalExperience
    private var draftSave: DispatchWorkItem?
    private var practicing = false
    private var shareButton: UIButton?
    private let input = UITextView()
    private let inputHint = UILabel()
    private let output = UITextView()
    private let candidates = UIStackView()
    private let mode = UISegmentedControl(items: ["Nepali + EN", "All Nepali"])
    private let copy = UIButton(type: .system)
    private let status = UILabel()
    private let sizeValue = UILabel()
    private var brandWordmark: UILabel?
    private var composer = Composer()
    private let queue = DispatchQueue(label: "app.neptype.pad.render", qos: .userInitiated)
    private var generation = 0
    private var copyGeneration = 0
    private var syncing = false
    private var points: CGFloat = 18
    private var work: DispatchWorkItem?
    private var userEditedPad = false
    private var analyticsMode: AppAnalytics.Mode { mode.selectedSegmentIndex == 0 ? .mixed : .allNepali }

    init(setupDefaults: UserDefaults = .standard) {
        self.setupDefaults = setupDefaults
        #if NEPTYPE_CONTAINER_TEST
        experience = LocalExperience(defaults: setupDefaults, persistent: false)
        #else
        experience = LocalExperience(defaults: setupDefaults)
        #endif
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        setupDefaults = .standard
        experience = LocalExperience()
        super.init(coder: coder)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !setupDefaults.bool(forKey: Self.setupPresentedKey), presentedViewController == nil else { return }
        showKeyboardSetup()
    }

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
        let mark = UIImageView(image: UIImage(named: "NepTypeMark"))
        mark.contentMode = .scaleAspectFit
        mark.widthAnchor.constraint(equalToConstant: 32).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let wordmark = label("NepType", size: 15, color: Graphite.ink)
        wordmark.numberOfLines = 1
        brandWordmark = wordmark
        let brand = row([mark, wordmark], spacing: 6)
        brand.isAccessibilityElement = true
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
        let share = icon("square.and.arrow.up", label: "Share output", action: #selector(shareOutput(_:)))
        shareButton = share
        share.accessibilityIdentifier = "share-output"
        let toolbar = row([brand, UIView(), mode, share, help], spacing: 8)
        toolbar.accessibilityIdentifier = "typing-toolbar"
        toolbar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        let setup = UIButton(type: .system)
        var setupStyle = UIButton.Configuration.plain()
        setupStyle.title = "Add NepType to your \(DeviceCopy.name) keyboard"
        setupStyle.titleLineBreakMode = .byWordWrapping
        setupStyle.image = UIImage(systemName: "keyboard")
        setupStyle.imagePadding = 7
        setupStyle.baseForegroundColor = Graphite.muted
        setupStyle.contentInsets = .zero
        setup.titleLabel?.adjustsFontForContentSizeCategory = true
        setupStyle.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .footnote)
            return attributes
        }
        setup.configuration = setupStyle
        setup.titleLabel?.numberOfLines = 0
        setup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setup.contentHorizontalAlignment = .trailing
        setup.accessibilityIdentifier = "keyboard-setup-link"
        setup.accessibilityHint = "Shows instructions for adding and choosing the NepType keyboard."
        setup.addTarget(self, action: #selector(showKeyboardSetup), for: .touchUpInside)
        let setupInfo = icon("info.circle", label: "How to add NepType to your \(DeviceCopy.name) keyboard", action: #selector(showKeyboardSetup))
        setupInfo.accessibilityIdentifier = "keyboard-setup-info"
        setupInfo.accessibilityHint = "Opens the step-by-step keyboard setup guide."
        let setupBanner = row([setup, setupInfo], spacing: 4)
        setupBanner.accessibilityIdentifier = "keyboard-setup-banner"
        setupBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(setupBanner)
        configure(input, editable: true)
        input.accessibilityLabel = "Roman input"
        input.accessibilityIdentifier = "roman-input"
        input.delegate = self
        inputHint.text = "Type Roman Nepali, e.g. ma office janchu"
        inputHint.font = .preferredFont(forTextStyle: .body)
        inputHint.textColor = Graphite.muted
        inputHint.numberOfLines = 0
        inputHint.isUserInteractionEnabled = false
        inputHint.isAccessibilityElement = false
        inputHint.translatesAutoresizingMaskIntoConstraints = false
        input.addSubview(inputHint)
        NSLayoutConstraint.activate([
            inputHint.topAnchor.constraint(equalTo: input.frameLayoutGuide.topAnchor, constant: 10),
            inputHint.leadingAnchor.constraint(equalTo: input.frameLayoutGuide.leadingAnchor, constant: 15),
            inputHint.trailingAnchor.constraint(equalTo: input.frameLayoutGuide.trailingAnchor, constant: -15)
        ])
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        input.smartQuotesType = .no
        input.smartDashesType = .no
        input.keyboardAppearance = .dark
        input.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
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
        output.heightAnchor.constraint(greaterThanOrEqualToConstant: 114).isActive = true
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
            setupBanner.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            setupBanner.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            setupBanner.widthAnchor.constraint(equalTo: toolbar.widthAnchor),
            setup.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            scroll.topAnchor.constraint(equalTo: setupBanner.bottomAnchor),
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
        input.text = ""
        composer.setSource(input.text)
        if experience.restore(into: &composer) {
            input.text = composer.state.source
            input.selectedRange = NSRange(location: (input.text as NSString).length, length: 0)
            mode.selectedSegmentIndex = composer.state.language == .allNepali ? 1 : 0
            userEditedPad = true
        }
        inputHint.isHidden = !input.text.isEmpty
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
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the output-mode and help controls usable on narrow phones.
        brandWordmark?.isHidden = view.safeAreaLayoutGuide.layoutFrame.width < 430
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
    private func panel(_ text: UITextView, heading: String, action: UIView, feedback: UILabel? = nil) -> UIView {
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

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard textView === input else { return }
        inputHint.isHidden = true
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        guard textView === input else { return }
        inputHint.isHidden = !input.text.isEmpty
    }
    func textViewDidChange(_ textView: UITextView) {
        guard !syncing, textView === input else { return }
        userEditedPad = true
        if !input.text.isEmpty { AppAnalytics.shared.usedPad(mode: analyticsMode) }
        composer.setSource(input.text)
        scheduleDraftSave()
        if practicing, !input.text.isEmpty {
            practicing = false
            AppAnalytics.shared.capture(.practiceCompleted)
        }
        refresh()
    }
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !syncing, textView === input else { return }
        refresh()
    }
    @objc private func modeChanged() {
        AppAnalytics.shared.capture(.modeChanged, mode: analyticsMode)
        composer.setLanguage(mode.selectedSegmentIndex == 0 ? .nepali : .allNepali)
        scheduleDraftSave()
        refresh()
    }
    private func refresh() {
        inputHint.isHidden = input.isFirstResponder || !input.text.isEmpty
        generation &+= 1
        let current = generation
        work?.cancel()
        copyGeneration &+= 1
        copy.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copy.accessibilityValue = nil
        copy.isEnabled = false
        shareButton?.isEnabled = false
        for view in candidates.arrangedSubviews { candidates.removeArrangedSubview(view); view.removeFromSuperview() }
        let snapshot = composer
        let caret = input.selectedRange.location
        status.text = nil
        status.isHidden = true
        let task = DispatchWorkItem { [weak self] in
            let started = DispatchTime.now().uptimeNanoseconds
            let rendered = snapshot.renderedText
            let result = rendered.text
            let token = snapshot.engine.activeToken(in: snapshot.state.source, caret: caret)
            let context = snapshot.engine.contextChoices(in: snapshot.state.source, language: snapshot.state.language).first { $0.token == token }
            let baseChoices = context.map { snapshot.engine.contextualCandidates(for: $0) } ?? token.map { snapshot.engine.candidates(for: $0.text) } ?? []
            let choices = snapshot.orderedCandidates(baseChoices, for: token?.text ?? "")
            DispatchQueue.main.async {
                guard let self, self.generation == current else { return }
                self.output.text = result
                if self.userEditedPad { AppAnalytics.shared.conversionCompleted(milliseconds: Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000) }
                self.copy.isEnabled = !result.isEmpty
                self.shareButton?.isEnabled = !result.isEmpty
                if let token {
                    let alternatives = choices.filter { $0 != token.text }
                    // Horizontal scrolling keeps every choice reachable on iPhone.
                    let visible = alternatives + [token.text]
                    let selected = rendered.words.first { $0.source == token }
                        .map { (result as NSString).substring(with: $0.outputRange) }
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
                            self.experience.remember(token.text, value: value, candidates: baseChoices + [token.text])
                            self.composer.setPreferredSpellings(self.experience.spellings)
                            self.scheduleDraftSave()
                            AppAnalytics.shared.capture(.suggestionSelected, mode: self.analyticsMode,
                                                        choice: value == token.text ? .original : .suggestion)
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
        userEditedPad = true
        syncing = true
        input.text = ""
        composer.setSource("")
        draftSave?.cancel()
        if !experience.clearDraft() { status.text = "Draft could not be deleted. Try Clear again."; status.isHidden = false }
        syncing = false
        refresh()
    }
    private func scheduleDraftSave() {
        draftSave?.cancel()
        let state = composer.state
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.experience.saveDraft(state) {
                self.status.text = "Draft could not be saved. Copy text you want to keep."
                self.status.isHidden = false
            }
        }
        draftSave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }
    func flushDraft() {
        draftSave?.cancel()
        _ = experience.saveDraft(composer.state)
    }
    private func startPractice() {
        input.becomeFirstResponder()
    }
    @objc private func copyText() {
        guard copy.isEnabled, !output.text.isEmpty else { return }
        UIPasteboard.general.string = output.text
        AppAnalytics.shared.capture(.outputCopied, mode: analyticsMode, origin: userEditedPad ? .edited : .example)
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
    @objc private func showKeyboardSetup() {
        guard presentedViewController == nil else { return }
        view.endEditing(true)
        AppAnalytics.shared.capture(.setupGuideOpened)
        let guide = KeyboardSetupViewController(openSettings: { [weak self] in self?.openSettings() }, practice: { [weak self] in self?.startPractice() })
        present(guide, animated: true)
        // This records that the guide was shown, never that the keyboard was enabled.
        setupDefaults.set(true, forKey: Self.setupPresentedKey)
    }

    @objc private func showHelp() {
        AppAnalytics.shared.capture(.helpOpened)
        let help = UIViewController()
        help.overrideUserInterfaceStyle = .dark
        help.view.backgroundColor = Graphite.background
        let guidance = label("Use NepType in other apps\n\n1. Open \(DeviceCopy.name) Settings → General → Keyboard → Keyboards.\n2. Tap Add New Keyboard and choose NepType.\n3. Hold the globe key to choose NepType.\n\nIn the keyboard, tap a suggestion to preview it. Space or Return accepts; Delete restores the Roman word before commit.\n\nThe keyboard works offline and does not need Full Access.", size: 14, color: Graphite.ink)
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
        let analytics = UISwitch()
        analytics.isOn = AppAnalytics.shared.isEnabled
        analytics.accessibilityLabel = "Share anonymous usage analytics"
        analytics.accessibilityIdentifier = "usage-analytics"
        analytics.addTarget(self, action: #selector(analyticsChanged(_:)), for: .valueChanged)
        let analyticsRow = row([label("Share anonymous usage analytics", size: 14, color: Graphite.ink), UIView(), analytics], spacing: 12)
        let privacy = label("PostHog counts app opens, typing-pad actions, coarse conversion timing and numeric OS health reports with a random installation ID. Your typed text, suggestions, and clipboard contents are never sent. The keyboard in other apps stays offline. Turn this off to stop collecting usage events.", size: 12)
        let practice = UIButton(type: .system)
        practice.setTitle("Try typing a message", for: .normal)
        practice.addAction(UIAction { [weak self] _ in
            self?.presentedViewController?.dismiss(animated: true) { self?.startPractice() }
        }, for: .touchUpInside)
        let feedback = UIButton(type: .system)
        feedback.setTitle("Report a typing problem", for: .normal)
        feedback.addAction(UIAction { [weak self] _ in self?.openFeedback() }, for: .touchUpInside)
        let content = UIStackView(arrangedSubviews: [guidance, practice, sizeValue, slider, open,
            label("Your draft is saved locally as you edit. Clear deletes it. Your spelling choices are saved locally in this pad.", size: 12),
            feedback, analyticsRow, privacy])
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
    @objc private func analyticsChanged(_ sender: UISwitch) { AppAnalytics.shared.setEnabled(sender.isOn) }
    @objc private func shareOutput(_ sender: UIButton) {
        guard copy.isEnabled, !output.text.isEmpty else { return }
        let sheet = UIActivityViewController(activityItems: [output.text ?? ""], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = sender
        sheet.popoverPresentationController?.sourceRect = sender.bounds
        present(sheet, animated: true)
        AppAnalytics.shared.capture(.shareOpened)
    }
    private func openFeedback() {
        AppAnalytics.shared.capture(.feedbackOpened)
        // No editor text or example is put into the URL. Users choose what to submit.
        if let url = URL(string: "https://github.com/anuphunt/nep-type/issues/new?template=typing-problem.yml") { UIApplication.shared.open(url) }
    }
    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url) { opened in
            if opened { AppAnalytics.shared.capture(.keyboardSettingsOpened) }
        }
    }
}

/// Uses only the public app-settings URL. iOS owns keyboard installation and selection.
final class KeyboardSetupViewController: UIViewController {
    private let openSettings: () -> Void
    private let practice: (() -> Void)?

    init(openSettings: @escaping () -> Void, practice: (() -> Void)? = nil) {
        self.openSettings = openSettings
        self.practice = practice
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.detents = [.large()]
        sheetPresentationController?.prefersGrabberVisible = true
    }
    required init?(coder: NSCoder) { fatalError("Use init(openSettings:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Graphite.background
        view.accessibilityIdentifier = "keyboard-setup-guide"

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .preferredFont(forTextStyle: .body)
        done.titleLabel?.adjustsFontForContentSizeCategory = true
        done.tintColor = Graphite.ink
        done.accessibilityIdentifier = "keyboard-setup-done"
        done.addTarget(self, action: #selector(closeGuide), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(done)

        let title = text("Add NepType to your \(DeviceCopy.name) keyboard", style: .largeTitle, color: Graphite.ink)
        title.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
        title.accessibilityTraits.insert(.header)
        let subtitle = text("Type Nepali in Messages and your other apps.", style: .body)
        let steps = UIStackView(arrangedSubviews: [
            step(1, title: "Open keyboard settings", detail: "On your \(DeviceCopy.name), go to Settings → General → Keyboard → Keyboards."),
            step(2, title: "Add NepType", detail: "Tap Add New Keyboard… and choose NepType under Third-Party Keyboards."),
            step(3, title: "Switch to NepType", detail: "In any text field, touch and hold the globe key, then choose NepType.")
        ])
        steps.axis = .vertical
        steps.spacing = 24
        let privacy = text("Works offline. No Full Access needed.", style: .footnote)
        let fallback = text("The button below opens NepType’s settings. If you don’t see a Keyboards option there, follow the Settings path above.", style: .footnote)
        let tryTyping = UIButton(type: .system)
        tryTyping.setTitle("Try typing a message", for: .normal)
        tryTyping.accessibilityIdentifier = "keyboard-setup-practice"
        tryTyping.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        tryTyping.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { self.practice?() }
        }, for: .touchUpInside)
        let content = UIStackView(arrangedSubviews: [title, subtitle, steps, privacy, fallback, tryTyping])
        content.axis = .vertical
        content.spacing = 18
        content.setCustomSpacing(28, after: subtitle)
        content.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "keyboard-setup-scroll"
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(content)

        let open = UIButton(type: .system)
        var style = UIButton.Configuration.filled()
        style.title = "Open Settings"
        style.image = UIImage(systemName: "gearshape")
        style.imagePadding = 8
        style.baseBackgroundColor = Graphite.accent
        style.baseForegroundColor = Graphite.onAccent
        style.cornerStyle = .medium
        style.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        open.configuration = style
        open.titleLabel?.adjustsFontForContentSizeCategory = true
        open.accessibilityIdentifier = "keyboard-setup-settings"
        open.addAction(UIAction { [weak self] _ in self?.openSettings() }, for: .touchUpInside)
        open.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(open)

        let preferredWidth = content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        preferredWidth.priority = .init(999)
        NSLayoutConstraint.activate([
            done.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            done.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            done.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            done.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            scroll.topAnchor.constraint(equalTo: done.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: open.topAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            content.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480), preferredWidth,
            open.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            open.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            open.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            open.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    private func text(_ value: String, style: UIFont.TextStyle, color: UIColor = Graphite.muted) -> UILabel {
        let label = UILabel()
        label.text = value
        label.font = .preferredFont(forTextStyle: style)
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
    private func step(_ number: Int, title: String, detail: String) -> UIStackView {
        let badge = text(String(number), style: .headline, color: Graphite.ink)
        badge.textAlignment = .center
        badge.backgroundColor = Graphite.line
        badge.layer.cornerRadius = 17
        badge.clipsToBounds = true
        badge.isAccessibilityElement = false
        badge.widthAnchor.constraint(equalToConstant: 34).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let heading = text(title, style: .headline, color: Graphite.ink)
        heading.accessibilityTraits.insert(.header)
        let body = UIStackView(arrangedSubviews: [heading, text(detail, style: .body)])
        body.axis = .vertical
        body.spacing = 6
        let row = UIStackView(arrangedSubviews: [badge, body])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 14
        return row
    }
    @objc private func closeGuide() { dismiss(animated: true) }
}
