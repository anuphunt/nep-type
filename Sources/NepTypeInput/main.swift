import AppKit
import InputMethodKit
import CryptoKit
import NepaliCore

enum SharedPanel {
    nonisolated(unsafe) static var instance: IMKCandidates?
    static func show() { DispatchQueue.main.async { instance?.update(); instance?.show(kIMKLocateCandidatesBelowHint) } }
    static func hide() { DispatchQueue.main.async { instance?.hide() } }
}

/// Local backing is injectable so persistence can be verified without writing
/// user preferences during tests. Only hashed bundle IDs and modes are stored.
protocol ModeBacking: AnyObject {
    func read() -> Data?
    func write(_ value: Data?)
}
final class DefaultsModeBacking: ModeBacking {
    private let defaults: UserDefaults
    private let key = "NepType.PerAppModes.v1"
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    func read() -> Data? { defaults.data(forKey: key) }
    func write(_ value: Data?) {
        if let value { defaults.set(value, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }
}
private struct PersistedModes: Codable {
    let version: Int
    let enabled: Bool
    let entries: [String: String]
    let order: [String]
}
/// Bounded manual language choices. Persistence is explicit opt-in and stores
/// hashed app IDs and language only, never input, document or website content.
final class ModeMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: TypingLanguage] = [:]
    private var order: [String] = []
    private var diskEntries: [String: String] = [:]
    private var diskOrder: [String] = []
    private var enabled = false
    private let backing: ModeBacking?
    private let limit = 64
    init(backing: ModeBacking? = nil) {
        self.backing = backing
        guard let data = backing?.read(), data.count <= 32768,
              let saved = try? JSONDecoder().decode(PersistedModes.self, from: data),
              saved.version == 1, saved.enabled,
              saved.order.count <= limit, saved.entries.count <= limit,
              saved.order.count == Set(saved.order).count,
              Set(saved.order) == Set(saved.entries.keys),
              saved.entries.allSatisfy({ key, value in
                  key.utf8.count == 64 && key.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } && TypingLanguage(rawValue: value) != nil
              }) else { return }
        enabled = true; diskEntries = saved.entries; diskOrder = saved.order
    }
    private func digest(_ id: String) -> String {
        SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func saveLocked() {
        guard enabled else { backing?.write(nil); return }
        let value = PersistedModes(version: 1, enabled: true, entries: diskEntries, order: diskOrder)
        if let encoded = try? JSONEncoder().encode(value) { backing?.write(encoded) }
    }
    var persistenceEnabled: Bool { lock.lock(); defer { lock.unlock() }; return enabled }
    func setPersistence(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard enabled != value else { return }
        enabled = value
        // Opting in does not retroactively persist earlier session choices.
        diskEntries.removeAll(); diskOrder.removeAll(); saveLocked()
    }
    func get(_ id: String) -> TypingLanguage? {
        lock.lock(); defer { lock.unlock() }
        if let value = entries[id] {
            order.removeAll { $0 == id }; order.append(id)
            return value
        }
        guard enabled, let raw = diskEntries[digest(id)] else { return nil }
        return TypingLanguage(rawValue: raw)
    }
    func set(_ value: TypingLanguage, for id: String) {
        guard !id.isEmpty, id.utf8.count <= 255 else { return }
        lock.lock(); defer { lock.unlock() }
        order.removeAll { $0 == id }; order.append(id); entries[id] = value
        if order.count > limit { entries.removeValue(forKey: order.removeFirst()) }
        if enabled {
            let key = digest(id)
            diskOrder.removeAll { $0 == key }; diskOrder.append(key); diskEntries[key] = value.rawValue
            if diskOrder.count > limit { diskEntries.removeValue(forKey: diskOrder.removeFirst()) }
            saveLocked()
        }
    }
}
enum SharedModeMemory { static let instance = ModeMemory(backing: DefaultsModeBacking()) }

/// A conservative local identity guard, not proof that a host's selected
/// document or marked range is unchanged. IMK may supply a new proxy for the
/// same client; in that case this deliberately pauses rather than guessing.
private final class CompositionOwner {
    private var owner: AnyObject?
    func bind(_ candidate: AnyObject) { owner = candidate }
    func matches(_ candidate: AnyObject?) -> Bool {
        guard let owner, let candidate else { return false }
        return owner === candidate
    }
    func clear() { owner = nil }
}

@objc(NepTypeInputController)
class NepTypeInputController: IMKInputController {
    private var session = InputSession()
    private var activationBlocked = false
    private let compositionOwner = CompositionOwner()
    private var lastEventClient: AnyObject?
    private let replacement = NSRange(location: NSNotFound, length: 0)

    private func clientID(_ sender: Any?) -> String? {
        guard let client = sender as? IMKTextInput,
              let id = client.bundleIdentifier(), !id.isEmpty, id.utf8.count <= 255 else { return nil }
        return id
    }
    private func rememberMode(for sender: Any?) {
        if let id = clientID(sender) { SharedModeMemory.instance.set(session.language, for: id) }
    }

    private func prepareActivation() -> Bool {
        guard !session.isComposing else {
            // The activation sender is not proven to own the previous marked
            // range. Never insert that text into a possibly different client.
            activationBlocked = true
            SharedPanel.hide()
            return false
        }
        activationBlocked = false
        return true
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        guard prepareActivation() else { return }
        lastEventClient = nil
        // Unknown identity stays in this controller's own session mode.
        // Known clients without a prior explicit choice start in Nepali.
        let selected = clientID(sender).map { SharedModeMemory.instance.get($0) ?? .nepali } ?? session.language
        session.setLanguage(selected)
    }

    private func refresh(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        let text = session.markedText
        client.setMarkedText(text, selectionRange: NSRange(location: (text as NSString).length, length: 0), replacementRange: replacement)
        if session.isComposing {
            SharedPanel.show()
        } else { SharedPanel.hide() }
    }

    private func commit(_ sender: Any!, keepContext: Bool, keepLiteralState: Bool = false) {
        guard session.isComposing, let client = sender as? IMKTextInput, compositionOwner.matches(sender as AnyObject?) else { return }
        if let text = session.commit(keepContext: keepContext, keepLiteralState: keepLiteralState) { client.insertText(text, replacementRange: replacement) }
        compositionOwner.clear()
        SharedPanel.hide()
    }

    // When focus or editing changes mid-token we cannot know whether more
    // characters would have revealed a URL or identifier. Preserve the raw
    // input rather than committing a potentially premature conversion.
    private func commitOriginal(_ sender: Any!) {
        guard session.isComposing, let client = sender as? IMKTextInput, compositionOwner.matches(sender as AnyObject?) else { return }
        if let original = session.cancel() { client.insertText(original, replacementRange: replacement) }
        compositionOwner.clear()
        SharedPanel.hide()
    }

    /// IMK asks for this menu each time macOS draws the input-source menu.
    /// It reports this controller's mode, not a global or per-app preference.
    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "NepType")
        menu.autoenablesItems = false
        let nepali = NSMenuItem(title: "Nepali + EN · NepType session", action: #selector(selectNepali(_:)), keyEquivalent: "")
        nepali.state = session.language == .nepali ? .on : .off
        let english = NSMenuItem(title: "English · NepType session", action: #selector(selectEnglish(_:)), keyEquivalent: "")
        english.state = session.language == .english ? .on : .off
        let allNepali = NSMenuItem(title: "All Nepali · NepType session", action: #selector(selectAllNepali(_:)), keyEquivalent: "")
        allNepali.state = session.language == .allNepali ? .on : .off
        nepali.isEnabled = !activationBlocked
        english.isEnabled = !activationBlocked
        allNepali.isEnabled = !activationBlocked
        menu.addItem(nepali)
        menu.addItem(english)
        menu.addItem(allNepali)
        menu.addItem(.separator())
        let remember = NSMenuItem(title: "Remember app language on this Mac", action: #selector(toggleModePersistence(_:)), keyEquivalent: "")
        remember.target = self
        remember.state = SharedModeMemory.instance.persistenceEnabled ? .on : .off
        menu.addItem(remember)
        let privacy = NSMenuItem(title: "Local hashed app IDs · turning off clears saved choices", action: nil, keyEquivalent: "")
        privacy.isEnabled = false
        menu.addItem(privacy)
        let hint = NSMenuItem(title: activationBlocked ? "Input paused: composition ownership unresolved" : "Option-Z: switch mixed / English · choose All Nepali above", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(hint)
        if !activationBlocked {
            let candidatesHint = NSMenuItem(title: "Tab / Shift-Tab: review choices · Backspace: restore", action: nil, keyEquivalent: "")
            candidatesHint.isEnabled = false
            menu.addItem(candidatesHint)
        }
        if retainedOriginalForRecovery() != nil {
            menu.addItem(.separator())
            let recover = NSMenuItem(title: "Copy retained Roman text", action: #selector(copyRetainedOriginal(_:)), keyEquivalent: "")
            recover.target = self
            menu.addItem(recover)
        }
        return menu
    }

    // Only an explicit user action copies a retained token. Do not put the
    // token itself in the menu, which could expose it to an observer.
    private func retainedOriginalForRecovery() -> String? {
        guard activationBlocked, session.isComposing else { return nil }
        return session.roman
    }

    @objc func copyRetainedOriginal(_ sender: Any?) {
        guard let original = retainedOriginalForRecovery() else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(original, forType: .string)
    }

    private func visibleCandidateList(_ candidates: [String], original: String) -> [String] {
        var list = Array(candidates.prefix(8))
        if !list.contains(original) { list.append(original) }
        return list
    }

    private func visibleCandidates() -> [String] {
        guard session.isComposing else { return [] }
        return visibleCandidateList(session.candidates, original: session.roman)
    }

    private func cycleVisibleCandidate(_ delta: Int) {
        let list = visibleCandidates()
        guard !list.isEmpty else { return }
        let current = list.firstIndex(of: session.markedText) ?? 0
        let step = delta < 0 ? -1 : 1
        _ = session.select(list[(current + step + list.count) % list.count])
    }

    private func restorePreviewOrBackspace() -> Bool {
        guard session.isComposing else { return false }
        if session.selection != 0 && session.markedText != session.roman {
            return session.select(session.roman)
        }
        return session.backspace()
    }

    private func changeLanguage(_ language: TypingLanguage, command: Any?) {
        guard !activationBlocked, session.language != language else { return }
        let info = command as? [AnyHashable: Any]
        let currentClient = info?[kIMKCommandClientName] as? IMKTextInput
        if session.isComposing {
            // IMK passes the current client in the command dictionary. If it
            // is absent, do not discard or rewrite an uncommitted word.
            guard let currentClient else { return }
            commitOriginal(currentClient)
            guard !session.isComposing else { return }
        }
        session.setLanguage(language)
        rememberMode(for: currentClient)
        SharedPanel.hide()
    }

    // Exercised only by --mode-menu-check. No host client is used here.
    func checkMissingClientGuard() -> Bool {
        session.reset()
        session.setLanguage(.nepali)
        guard session.append("ma") else { return false }
        selectAllNepali(nil)
        selectEnglish(nil)
        let preserved = session.isComposing && session.roman == "ma" && session.language == .nepali
        _ = session.cancel()
        return preserved
    }

    func checkAllNepaliComposition() -> Bool {
        session.reset(); activationBlocked = false; session.setLanguage(.nepali)
        selectAllNepali(nil)
        guard session.language == .allNepali, session.append("office") else { return false }
        let safe = session.markedText != "office" && session.candidates.contains("office")
        _ = session.cancel(); session.setLanguage(.nepali)
        return safe
    }

    // Exercises a pending-word activation without using or mutating a client.
    func checkActivationGuard() -> Bool {
        session.reset(); session.setLanguage(.nepali); activationBlocked = false
        guard session.append("ma"), !prepareActivation() else { return false }
        let menu = menu()!
        selectEnglish(nil)
        let preserved = session.roman == "ma" && session.language == .nepali &&
            activationBlocked && !menu.items[0].isEnabled && !menu.items[1].isEnabled && !menu.items[2].isEnabled
        _ = session.cancel(); activationBlocked = false
        return preserved
    }

    // Tests a missing-client deactivation without touching a host.
    func checkDeactivationGuard() -> Bool {
        session.reset(); session.setLanguage(.nepali); activationBlocked = false
        guard session.append("ma") else { return false }
        prepareDeactivation(nil)
        let preserved = activationBlocked && session.roman == "ma" && session.isComposing
        _ = session.cancel(); activationBlocked = false
        return preserved
    }

    func checkOwnerGuard() -> Bool {
        let first = NSObject(), other = NSObject()
        let guardState = CompositionOwner()
        guardState.bind(first)
        let rejectsOther = guardState.matches(first) && !guardState.matches(other) && !guardState.matches(nil)
        guardState.clear()
        return rejectsOther && !guardState.matches(first)
    }

    private func prepareEventClient(_ eventClient: AnyObject) {
        if !session.isComposing, let lastEventClient, lastEventClient !== eventClient {
            // Do not carry context or an open literal span to another proxy.
            session.reset()
        }
        lastEventClient = eventClient
    }

    func checkContextBoundary() -> Bool {
        let first = NSObject(), other = NSObject()
        session.reset(); lastEventClient = nil
        prepareEventClient(first)
        guard session.append("mero"), session.commit(keepContext: true) != nil,
              !session.context.isEmpty else { return false }
        prepareEventClient(other)
        return session.context.isEmpty
    }

    func checkCandidateNavigationAndRecovery() -> Bool {
        session.reset(); activationBlocked = false
        guard session.append("pani") else { return false }
        let initial = session.markedText
        let visible = visibleCandidates()
        guard visible.contains(session.roman), visible.count <= 9, visible.count > 1 else { return false }
        let synthetic = (0..<12).map { "candidate-\($0)" }
        let limited = visibleCandidateList(synthetic, original: "original")
        guard limited.count == 9, limited.last == "original", !limited.contains("candidate-8") else { return false }
        cycleVisibleCandidate(1)
        let selected = session.markedText
        guard visible.contains(selected), selected != initial else { return false }
        guard restorePreviewOrBackspace(), session.roman == "pani" else { return false }
        if selected != "pani" && session.markedText != "pani" { return false }
        activationBlocked = true
        let menu = menu()!
        let recovered = retainedOriginalForRecovery() == "pani" && menu.items.contains { $0.title == "Copy retained Roman text" } && !menu.items.contains { $0.title.contains("pani") }
        _ = session.cancel(); activationBlocked = false
        return recovered
    }

    @objc func toggleModePersistence(_ command: Any?) {
        let memory = SharedModeMemory.instance
        memory.setPersistence(!memory.persistenceEnabled)
    }

    @objc func selectNepali(_ command: Any?) { changeLanguage(.nepali, command: command) }
    @objc func selectAllNepali(_ command: Any?) { changeLanguage(.allNepali, command: command) }
    @objc func selectEnglish(_ command: Any?) { changeLanguage(.english, command: command) }

    override func commitComposition(_ sender: Any!) {
        guard !activationBlocked else { return }
        if session.isComposing && !compositionOwner.matches(sender as AnyObject?) {
            activationBlocked = true
            SharedPanel.hide()
            return
        }
        commitOriginal(sender)
    }
    private func prepareDeactivation(_ sender: Any?) {
        guard !activationBlocked else { return }
        if session.isComposing {
            // A missing/non-client sender cannot own the marked range. Keep
            // the token in memory and stop rather than silently resetting it.
            guard sender is IMKTextInput, compositionOwner.matches(sender as AnyObject?) else {
                activationBlocked = true
                SharedPanel.hide()
                return
            }
            commitOriginal(sender)
            guard !session.isComposing else {
                activationBlocked = true
                SharedPanel.hide()
                return
            }
        }
        session.reset()
        lastEventClient = nil
    }

    override func deactivateServer(_ sender: Any!) {
        prepareDeactivation(sender)
        SharedPanel.hide()
        super.deactivateServer(sender)
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        guard !activationBlocked, session.isComposing else { return [] }
        // The original Roman text remains reachable in the visible list.
        return visibleCandidates()
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        // This callback carries only display text, with no source token or
        // generation. A queued click could select the same string for a newer
        // word. Tab/Shift-Tab select previews in the current event session.
    }

    private func acceptEventSender(_ sender: Any?) -> Bool {
        guard sender is IMKTextInput else {
            // An event without a text client may signal a focus transition.
            // Retain the token, but do not resume it in an unproven field.
            if session.isComposing { activationBlocked = true; SharedPanel.hide() }
            return false
        }
        return true
    }

    func checkInvalidEventSender() -> Bool {
        session.reset(); activationBlocked = false
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0),
              session.append("ma"), !handle(event, client: nil) else { return false }
        let retained = activationBlocked && session.isComposing && session.roman == "ma"
        let rejectsFurtherEvents = !handle(event, client: NSObject()) && !prepareActivation() && session.roman == "ma"
        let recoveredOriginal = retainedOriginalForRecovery() == "ma"
        _ = session.cancel(); activationBlocked = false
        guard !handle(event, client: NSObject()), !activationBlocked else { return false }
        return retained && rejectsFurtherEvents && recoveredOriginal
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard !activationBlocked, let event, event.type == .keyDown, acceptEventSender(sender) else { return false }
        if session.isComposing && !compositionOwner.matches(sender as AnyObject?) {
            // Do not act on an unverified proxy or forget the original word.
            activationBlocked = true
            SharedPanel.hide()
            return false
        }
        let eventClient = sender as AnyObject
        prepareEventClient(eventClient)
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        // An explicit language toggle is handled before passing shortcuts to the host.
        // Commit first: changing language must never silently discard marked text.
        if mods == .option && event.charactersIgnoringModifiers?.lowercased() == "z" {
            commitOriginal(sender)
            session.toggleLanguage()
            rememberMode(for: sender)
            SharedPanel.hide()
            return true
        }
        if !mods.isEmpty {
            // Preserve the raw token before the host handles a shortcut.
            commitOriginal(sender)
            session.reset()
            return false
        }
        if event.keyCode == 51 {
            guard restorePreviewOrBackspace() else { session.reset(); return false }
            if !session.isComposing { compositionOwner.clear() }
            refresh(sender); return true
        }
        if event.keyCode == 53, session.isComposing {
            guard let client = sender as? IMKTextInput else { return false }
            if let original = session.cancel() { client.insertText(original, replacementRange: replacement) }
            compositionOwner.clear()
            SharedPanel.hide(); return true
        }
        if event.keyCode == 48, session.isComposing {
            cycleVisibleCandidate(event.modifierFlags.contains(.shift) ? -1 : 1)
            refresh(sender); return true
        }
        if [123, 124, 125, 126, 115, 119].contains(event.keyCode) {
            commitOriginal(sender); session.reset(); return false
        }
        guard let text = event.characters, !text.isEmpty else { return false }
        let wasComposing = session.isComposing
        if session.append(text) {
            if !wasComposing { compositionOwner.bind(sender as AnyObject) }
            refresh(sender); return true
        }
        // Keep one contiguous token marked until whitespace so punctuation can
        // reveal a URL, email, path or identifier before anything is committed.
        // Backtick state survives whitespace but never survives focus loss.
        let whitespace = text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
        if whitespace {
            commit(sender, keepContext: text == " ", keepLiteralState: true)
        } else {
            commitOriginal(sender)
            session.reset()
        }
        return false
    }
}

// A randomly named UserDefaults suite exercises real cross-process storage.
// No input source or personal preference is changed, and the suite is removed.
if let position = CommandLine.arguments.firstIndex(of: "--preference-probe-child"), CommandLine.arguments.count > position + 2 {
    let suite = CommandLine.arguments[position + 1]
    let expected = CommandLine.arguments[position + 2]
    guard let defaults = UserDefaults(suiteName: suite) else { exit(2) }
    let memory = ModeMemory(backing: DefaultsModeBacking(defaults))
    let actual = memory.get("org.example.preference-test")?.rawValue ?? "none"
    exit(actual == expected ? 0 : 1)
}
if CommandLine.arguments.contains("--preference-persistence-check") {
    let suite = "local.neptype.test." + UUID().uuidString
    guard let defaults = UserDefaults(suiteName: suite) else { exit(2) }
    let memory = ModeMemory(backing: DefaultsModeBacking(defaults))
    memory.setPersistence(true)
    memory.set(.english, for: "org.example.preference-test")
    defaults.synchronize()
    func probe(_ expected: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--preference-probe-child", suite, expected]
        do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 }
        catch { return false }
    }
    let persisted = probe("english")
    memory.setPersistence(false)
    defaults.synchronize()
    let erased = probe("none")
    defaults.removePersistentDomain(forName: suite)
    defaults.synchronize()
    // CFPreferences may leave an empty plist for a removed test domain.
    let testPlist = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences", isDirectory: true)
        .appendingPathComponent(suite + ".plist")
    try? FileManager.default.removeItem(at: testPlist)
    print("Isolated preference suite: cross-process=\(persisted) opt-out-erases=\(erased)")
    exit(persisted && erased ? 0 : 1)
}

let application = NSApplication.shared
let server = IMKServer(name: "NepTypeInput_Connection", bundleIdentifier: Bundle.main.bundleIdentifier!)
if CommandLine.arguments.contains("--mode-menu-check") {
    guard let server else { fputs("IMKServer unavailable\n", stderr); exit(1) }
    guard let controller = NepTypeInputController(server: server, delegate: nil, client: nil) else { fputs("Controller unavailable\n", stderr); exit(1) }
    let initial = controller.menu()!
    let nepaliInitially = initial.items[0].state == .on && initial.items[1].state == .off
    controller.selectEnglish(nil)
    let changed = controller.menu()!
    let englishSelected = changed.items[0].state == .off && changed.items[1].state == .on && changed.items[2].state == .off
    controller.selectAllNepali(nil)
    let allMode = controller.menu()!
    let allSelected = allMode.items[0].state == .off && allMode.items[1].state == .off && allMode.items[2].state == .on
    controller.selectNepali(nil)
    let restored = controller.menu()!
    let nepaliRestored = restored.items[0].state == .on && restored.items[1].state == .off
    let memory = ModeMemory()
    memory.set(.english, for: "org.example.one")
    let isolated = memory.get("org.example.one") == .english && memory.get("org.example.two") == nil
    for index in 0..<65 { memory.set(.nepali, for: "org.example.\(index)") }
    let bounded = memory.get("org.example.one") == nil && memory.get("org.example.64") == .nepali
    final class TestBacking: ModeBacking {
        var data: Data?
        func read() -> Data? { data }
        func write(_ value: Data?) { data = value }
    }
    let backing = TestBacking()
    let first = ModeMemory(backing: backing)
    first.set(.english, for: "org.example.private")
    let defaultOff = backing.data == nil
    first.setPersistence(true)
    let noRetroactive = ModeMemory(backing: backing).get("org.example.private") == nil
    first.set(.english, for: "org.example.private")
    first.set(.allNepali, for: "org.example.all")
    let restoredMemory = ModeMemory(backing: backing)
    let persisted = restoredMemory.persistenceEnabled && restoredMemory.get("org.example.private") == .english && restoredMemory.get("org.example.all") == .allNepali
    let noRawID = !(String(data: backing.data ?? Data(), encoding: .utf8) ?? "").contains("org.example.private")
    restoredMemory.setPersistence(false)
    let erased = backing.data == nil && !ModeMemory(backing: backing).persistenceEnabled
    backing.data = Data("{malformed".utf8)
    let corruptSafe = !ModeMemory(backing: backing).persistenceEnabled
    backing.data = nil
    let boundedStore = ModeMemory(backing: backing)
    boundedStore.setPersistence(true)
    for index in 0..<65 { boundedStore.set(.nepali, for: "org.test.\(index)") }
    let boundedReload = ModeMemory(backing: backing)
    let boundedDisk = boundedReload.get("org.test.0") == nil && boundedReload.get("org.test.64") == .nepali
    DispatchQueue.concurrentPerform(iterations: 200) { index in
        let id = "org.concurrent.\(index)"
        boundedStore.set(index.isMultiple(of: 2) ? .english : .nepali, for: id)
        _ = boundedStore.get(id)
    }
    let concurrentSaved = backing.data.flatMap { try? JSONDecoder().decode(PersistedModes.self, from: $0) }
    let concurrentSafe = concurrentSaved.map { $0.entries.count <= 64 && $0.order.count == $0.entries.count && Set($0.order) == Set($0.entries.keys) } ?? false
    let persistenceSafe = defaultOff && noRetroactive && persisted && noRawID && erased && corruptSafe && boundedDisk && concurrentSafe
    let preserved = controller.checkMissingClientGuard()
    let activationSafe = controller.checkActivationGuard()
    let deactivationSafe = controller.checkDeactivationGuard()
    let ownerSafe = controller.checkOwnerGuard()
    let invalidEventSafe = controller.checkInvalidEventSender()
    let contextSafe = controller.checkContextBoundary()
    let candidateSafe = controller.checkCandidateNavigationAndRecovery()
    let allCompositionSafe = controller.checkAllNepaliComposition()
    print("Mode menu: initial=\(nepaliInitially) english=\(englishSelected) all-nepali=\(allSelected) all-composition=\(allCompositionSafe) restored=\(nepaliRestored) missing-client-preserves=\(preserved) isolated=\(isolated) bounded=\(bounded) activation-blocked=\(activationSafe) deactivation-preserves=\(deactivationSafe) owner-guard=\(ownerSafe) invalid-event-preserves=\(invalidEventSafe) context-boundary=\(contextSafe) candidate-navigation-recovery=\(candidateSafe) persistence=\(persistenceSafe)")
    exit(nepaliInitially && englishSelected && allSelected && nepaliRestored && preserved && isolated && bounded && activationSafe && deactivationSafe && ownerSafe && invalidEventSafe && contextSafe && candidateSafe && allCompositionSafe && persistenceSafe ? 0 : 1)
}
if CommandLine.arguments.contains("--server-check") {
    print(server == nil ? "IMKServer unavailable" : "IMKServer created")
    exit(server == nil ? 1 : 0)
}
if let server {
    let panel = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
    // Candidate actions have no generation token. The controller must receive
    // keys first, and the panel must not use implicit number selection.
    panel?.setAttributes([IMKCandidatesSendServerKeyEventFirst: true])
    panel?.setSelectionKeys([])
    panel?.setDismissesAutomatically(false)
    SharedPanel.instance = panel
}
withExtendedLifetime(server) { application.run() }
