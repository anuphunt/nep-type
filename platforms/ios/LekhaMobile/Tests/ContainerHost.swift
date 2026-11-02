import UIKit

@main
final class ContainerHost: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var checks: [String: Bool] = [:]
    private var controller: WelcomeViewController!
    private var savedClipboard: [[String: Any]] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        controller = WelcomeViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        savedClipboard = UIPasteboard.general.items
        waitFor("initial_local_conversion", { self.field("nepali-output")?.text == "नमस्ते! म office जान्छु।" }) { self.checkTyping() }
        return true
    }
    func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    func field(_ id: String) -> UITextView? { descendants(controller.view).first { $0.accessibilityIdentifier == id } as? UITextView }
    func button(_ id: String) -> UIButton? { descendants(controller.view).first { $0.accessibilityIdentifier == id } as? UIButton }
    func waitFor(_ name: String, _ condition: @escaping () -> Bool, then next: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(12)
        func poll() {
            if condition() { self.checks[name] = true; next(); return }
            if Date() >= deadline { self.checks[name] = false; self.finish(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: poll)
        }
        DispatchQueue.main.async(execute: poll)
    }
    func write(_ text: String) {
        guard let source = field("roman-input") else { return }
        source.text = text
        source.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        controller.textViewDidChange(source)
    }
    func checkTyping() {
        let root = controller.view!
        checks["graphite_dark_appearance"] = controller.overrideUserInterfaceStyle == .dark && root.backgroundColor == UIColor(white: 30/255, alpha: 1)
        checks["separate_source_and_result"] = field("roman-input")?.isEditable == true && field("nepali-output")?.isEditable == false
        checks["copy_is_accessible_icon"] = button("copy-output")?.accessibilityLabel == "Copy text" && button("copy-output")?.currentImage != nil && button("copy-output")?.currentTitle == nil
        let labels = descendants(root).compactMap { ($0 as? UILabel)?.text }
        checks["removed_decorative_copy"] = !labels.contains { $0.contains("Suggestions for") || $0.contains("little space") || $0.contains("always preserved") || $0.contains("Try example") }
        write("👋 ma pani")
        waitFor("typing_updates_result", { self.field("nepali-output")?.text == "👋 म पनि" }) {
            let buttons = self.descendants(root).compactMap { $0 as? UIButton }
            guard let candidate = buttons.first(where: { $0.accessibilityLabel == "Choose suggestion पानी" }) else {
                self.checks["candidate_available"] = false; self.finish(); return
            }
            self.checks["candidate_touch_target"] = candidate.bounds.width >= 44 && candidate.bounds.height >= 44
            candidate.sendActions(for: .touchUpInside)
            self.waitFor("candidate_updates_result", { self.field("nepali-output")?.text == "👋 म पानी" }) {
                self.checks["candidate_preserves_original"] = self.field("roman-input")?.text == "👋 ma pani"
                self.button("copy-output")?.sendActions(for: .touchUpInside)
                self.checks["copy_output"] = UIPasteboard.general.string == "👋 म पानी"
                self.checks["copy_feedback"] = self.button("copy-output")?.accessibilityValue == "Copied"
                self.write("ma office janchu")
                candidate.sendActions(for: .touchUpInside)
                self.waitFor("stale_candidate_ignored", { self.field("nepali-output")?.text == "म office जान्छु" }) { self.checkMode() }
            }
        }
    }
    func checkMode() {
        let mode = descendants(controller.view).first { $0.accessibilityIdentifier == "language-switch" } as! UISegmentedControl
        mode.selectedSegmentIndex = 1
        mode.sendActions(for: .valueChanged)
        waitFor("all_nepali_mode", { self.field("nepali-output")?.text == "म ओफ्फिचे जान्छु" }) {
            self.button("clear")?.sendActions(for: .touchUpInside)
            self.waitFor("clear_updates_both_fields", { self.field("roman-input")?.text.isEmpty == true && self.field("nepali-output")?.text.isEmpty == true }) {
                self.checks["empty_copy_disabled"] = self.button("copy-output")?.isEnabled == false
                self.checkLayoutAndHelp()
            }
        }
    }
    func checkLayoutAndHelp() {
        let root = controller.view!
        let original = root.frame
        for (width, height) in [(320, 667), (393, 812), (430, 874), (700, 430)] {
            for inset in [CGFloat(0), CGFloat(300)] {
                root.frame = CGRect(x: 0, y: 0, width: width, height: height)
                controller.additionalSafeAreaInsets.bottom = inset
                root.setNeedsLayout(); root.layoutIfNeeded()
                let all = descendants(root)
                let outer = all.first { $0.accessibilityIdentifier == "typing-pad-scroll" } as! UIScrollView
                let document = all.first { $0.accessibilityIdentifier == "document-stack" }!
                let dock = all.first { $0.accessibilityIdentifier == "suggestion-dock" }!
                let canvas = document.superview!
                let tag = "\(width)x\(height)_inset\(Int(inset))"
                checks["no_horizontal_overflow_" + tag] = outer.contentSize.width <= outer.bounds.width + 1
                checks["document_centered_" + tag] = abs(document.center.x - canvas.bounds.midX) < 1 && abs(document.center.y - canvas.bounds.midY) < 1
                checks["document_width_capped_" + tag] = document.bounds.width <= 360.1
                let dockFrame = dock.convert(dock.bounds, to: root)
                let workspaceFrame = outer.convert(outer.bounds, to: root)
                checks["suggestions_above_keyboard_" + tag] = abs(dockFrame.maxY - root.keyboardLayoutGuide.layoutFrame.minY) <= 1
                checks["workspace_above_suggestions_" + tag] = workspaceFrame.maxY <= dockFrame.minY + 1
                let documentFrame = document.convert(document.bounds, to: outer)
                checks["entire_document_reachable_" + tag] = documentFrame.minY >= -1 && documentFrame.maxY <= outer.contentSize.height + 1
                let copy = button("copy-output")!, clear = button("clear")!
                let copyHeader = copy.superview!, clearHeader = clear.superview!
                checks["copy_aligned_" + tag] = abs(copy.center.y - copyHeader.bounds.midY) <= 1 && abs(copy.frame.maxX - clear.frame.maxX) <= 1 && abs(clear.center.y - clearHeader.bounds.midY) <= 1
            }
        }
        controller.additionalSafeAreaInsets = .zero
        root.frame = original; root.setNeedsLayout(); root.layoutIfNeeded()
        button("typing-help")?.sendActions(for: .touchUpInside)
        waitFor("help_available", { self.controller.presentedViewController?.viewIfLoaded != nil }) {
            let help = self.controller.presentedViewController!
            help.view.layoutIfNeeded()
            let all = self.descendants(help.view)
            let labels = all.compactMap { ($0 as? UILabel)?.text }
            self.checks["setup_guidance_retained"] = labels.contains { $0.contains("Add New Keyboard") && $0.contains("choose Lekha") }
            self.checks["privacy_and_limits_retained"] = labels.contains { $0.contains("experimental") && $0.contains("does not request Full Access") }
            let settings = all.compactMap { $0 as? UIButton }.first { $0.currentTitle == "Open Lekha settings" }
            self.checks["settings_only_on_tap"] = settings?.actions(forTarget: self.controller, forControlEvent: .touchUpInside)?.isEmpty == false
            let slider = all.compactMap { $0 as? UISlider }.first
            self.checks["text_size_scope"] = slider?.accessibilityHint?.contains("typing pad only") == true
            slider?.value = 26; slider?.sendActions(for: .valueChanged)
            self.checks["text_size_changes_both_panes"] = self.field("roman-input")?.font?.pointSize == 26 && self.field("nepali-output")?.font?.pointSize == 32
            slider?.value = 18; slider?.sendActions(for: .valueChanged)
            help.dismiss(animated: false) {
                let mode = self.descendants(self.controller.view).first { $0.accessibilityIdentifier == "language-switch" } as! UISegmentedControl
                mode.selectedSegmentIndex = 0; mode.sendActions(for: .valueChanged)
                self.write("namaste! ma office janchu.\nbholi meeting pachi bhetau.")
                self.waitFor("multiline_result", { self.field("nepali-output")?.text == "नमस्ते! म office जान्छु।\nभोलि meeting पछि भेटौँ।" }) {
                    if let source = self.field("roman-input") {
                        let word = (source.text as NSString).range(of: "bhetau")
                        source.selectedRange = NSRange(location: word.location + 2, length: 0)
                        self.controller.textViewDidChangeSelection(source)
                    }
                    self.waitFor("suggestions_in_final_view", { self.button("candidate-0") != nil }) { self.checkSoftwareKeyboard() }
                }
            }
        }
    }
    func checkSoftwareKeyboard() {
        field("roman-input")?.becomeFirstResponder()
        waitFor("software_keyboard_visible", { self.controller.view.keyboardLayoutGuide.layoutFrame.height > 150 }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let root = self.controller.view!
                root.layoutIfNeeded()
                let all = self.descendants(root)
                let dock = all.first { $0.accessibilityIdentifier == "suggestion-dock" }!
                let document = all.first { $0.accessibilityIdentifier == "document-stack" }!
                let outer = all.first { $0.accessibilityIdentifier == "typing-pad-scroll" } as! UIScrollView
                let dockFrame = dock.convert(dock.bounds, to: root)
                let documentFrame = document.convert(document.bounds, to: root)
                let workspaceFrame = outer.convert(outer.bounds, to: root)
                self.checks["live_suggestions_touch_keyboard_edge"] = abs(dockFrame.maxY - root.keyboardLayoutGuide.layoutFrame.minY) < 1
                self.checks["live_document_above_keyboard"] = documentFrame.maxY <= dockFrame.minY
                self.checks["live_document_centered"] = abs(documentFrame.midY - workspaceFrame.midY) < 1
                self.finish()
            }
        }
    }
    func finish() {
        UIPasteboard.general.items = savedClipboard
        let root = controller.view!
        root.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: root.bounds.size)
        let snapshot = renderer.image { _ in root.drawHierarchy(in: root.bounds, afterScreenUpdates: true) }
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
        try? snapshot.pngData()?.write(to: temp.appendingPathComponent("lekha-iphone-graphite.png"))
        let payload: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "note": "Standalone simulator typing pad; no keyboard extension enabled"]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: temp.appendingPathComponent("lekha-container-check.json"))
            print(String(data: data, encoding: .utf8)!)
        }
        fflush(stdout)
        // Leave the live keyboard on screen briefly for the runner's full-display capture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            exit(self.checks.values.allSatisfy { $0 } ? 0 : 1)
        }
    }
}
