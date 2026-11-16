import Foundation
#if !NEPTYPE_CONTAINER_TEST
import PostHog
import MetricKit
#endif

/// Companion-app events only. This file is never compiled into the keyboard extension.
/// Call sites accept enums, never text, candidates, clipboard values or host context.
final class AppAnalytics {
    enum Event: String, CaseIterable {
        case appOpened = "neptype_ios_app_opened"
        case padUsed = "neptype_ios_pad_used"
        case outputCopied = "neptype_ios_output_copied"
        case suggestionSelected = "neptype_ios_suggestion_selected"
        case modeChanged = "neptype_ios_mode_changed"
        case helpOpened = "neptype_ios_help_opened"
        case keyboardSettingsOpened = "neptype_ios_keyboard_settings_opened"
        case setupGuideOpened = "neptype_ios_setup_guide_opened"
        case practiceStarted = "neptype_ios_practice_started"
        case practiceCompleted = "neptype_ios_practice_completed"
        case shareOpened = "neptype_ios_share_opened"
        case feedbackOpened = "neptype_ios_feedback_opened"
        case conversionMeasured = "neptype_ios_conversion_measured"
        case diagnosticReceived = "neptype_ios_diagnostic_received"
        case exitHealthReceived = "neptype_ios_exit_health_received"
    }
    enum Mode: String { case mixed = "nepali_en", allNepali = "all_nepali" }
    enum Choice: String { case original, suggestion }
    enum ContentOrigin: String { case example, edited }

    static let shared = AppAnalytics()
    private static let preferenceKey = "neptype.usageAnalyticsEnabled"
    private let defaults: UserDefaults
    private let now: () -> Date
    private var send: ((String, [String: Any]) -> Void)?
    private var sdkStarted = false
    private var activityDay: Int?
    private var padDay: Int?
    private var conversionCount = 0

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         send: ((String, [String: Any]) -> Void)? = nil) {
        self.defaults = defaults
        self.now = now
        self.send = send
    }

    var isEnabled: Bool { defaults.object(forKey: Self.preferenceKey) as? Bool ?? true }

    func start() {
        guard isEnabled, !sdkStarted else { return }
        #if !NEPTYPE_CONTAINER_TEST
        guard let key = Bundle.main.object(forInfoDictionaryKey: "NepTypePostHogKey") as? String,
              key.hasPrefix("phc_"),
              let host = Bundle.main.object(forInfoDictionaryKey: "NepTypePostHogHost") as? String,
              let url = URL(string: host), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return }
        let config = PostHogConfig(projectToken: key, host: host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.enableSwizzling = false
        config.sessionReplay = false
        config.surveys = false
        config.errorTrackingConfig.autoCapture = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.personProfiles = .never
        config.setDefaultPersonProperties = false
        config.maxQueueSize = 250
        config.setBeforeSend { event in
            guard let properties = Self.sanitized(event: event.event, properties: event.properties) else { return nil }
            event.properties = properties
            return event
        }
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.optIn()
        sdkStarted = true
        send = { PostHogSDK.shared.capture($0, properties: $1) }
        AppHealthMonitor.shared.start()
        #endif
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.preferenceKey)
        activityDay = nil
        padDay = nil
        if enabled {
            start()
            becameActive()
        } else {
            #if !NEPTYPE_CONTAINER_TEST
            if sdkStarted {
                PostHogSDK.shared.optOut()
                PostHogSDK.shared.close()
                sdkStarted = false
                send = nil
                AppHealthMonitor.shared.stop()
            }
            #endif
        }
    }

    func becameActive() {
        activityDay = utcDay
        padDay = nil
        capture(.appOpened)
    }

    func backgrounded() {
        #if !NEPTYPE_CONTAINER_TEST
        if isEnabled, sdkStarted { PostHogSDK.shared.flush() }
        #endif
    }

    /// At most one editing event per foreground/day, regardless of keystroke count.
    func usedPad(mode: Mode) {
        guard isEnabled, send != nil else { return }
        ensureActiveDay()
        guard padDay != utcDay else { return }
        padDay = utcDay
        capture(.padUsed, mode: mode)
    }

    func capture(_ event: Event, mode: Mode? = nil, choice: Choice? = nil, origin: ContentOrigin? = nil, measurements: [String:Int] = [:], latencyBucket: String? = nil) {
        guard isEnabled, let send else { return }
        if event != .appOpened { ensureActiveDay() }
        var properties: [String: Any] = [
            "app": "neptype", "platform": "ios", "surface": "companion_app", "schema_version": 1,
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "app_build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        ]
        #if targetEnvironment(simulator) || DEBUG || NEPTYPE_CONTAINER_TEST
        properties["is_test"] = true
        #else
        properties["is_test"] = false
        #endif
        if let mode { properties["mode"] = mode.rawValue }
        if let choice { properties["choice_kind"] = choice.rawValue }
        if let origin { properties["content_origin"] = origin.rawValue }
        for (key,value) in measurements where Self.measurementKeys.contains(key) && (0...1_000_000_000).contains(value) { properties[key] = value }
        if let latencyBucket { properties["latency_bucket"] = latencyBucket }
        send(event.rawValue, properties)
    }
    private static let measurementKeys: Set<String> = ["crash_count","hang_count","normal_exits","crash_exits","watchdog_exits","memory_exits"]
    func conversionCompleted(milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds >= 0 else { return }
        conversionCount += 1
        guard conversionCount % 20 == 1 else { return }
        let bucket = milliseconds < 16 ? "under_16ms" : milliseconds < 50 ? "16_to_49ms" : milliseconds < 150 ? "50_to_149ms" : "150ms_plus"
        capture(.conversionMeasured, latencyBucket: bucket)
    }

    private var utcDay: Int { Int(floor(now().timeIntervalSince1970 / 86_400)) }

    private func ensureActiveDay() {
        guard activityDay != utcDay else { return }
        activityDay = utcDay
        capture(.appOpened)
    }

    /// A second boundary strips SDK enrichment and rejects unexpected events/values before disk/network.
    static func sanitized(event: String, properties: [String: Any]) -> [String: Any]? {
        guard Event(rawValue: event) != nil else { return nil }
        var safe: [String: Any] = ["app": "neptype", "platform": "ios", "surface": "companion_app",
                                   "schema_version": 1, "$process_person_profile": false,
                                   "$geoip_disable": true, "$ip": ""]
        for key in ["app_version", "app_build"] {
            if let value = properties[key] as? String,
               value.range(of: "^[0-9]+([.][0-9]+)*$", options: .regularExpression) != nil {
                safe[key] = value
            }
        }
        safe["is_test"] = properties["is_test"] as? Bool ?? true
        if let value = properties["mode"] as? String, Mode(rawValue: value) != nil { safe["mode"] = value }
        if let value = properties["choice_kind"] as? String, Choice(rawValue: value) != nil { safe["choice_kind"] = value }
        if let value = properties["content_origin"] as? String, ContentOrigin(rawValue: value) != nil { safe["content_origin"] = value }
        if let value = properties["latency_bucket"] as? String, ["under_16ms","16_to_49ms","50_to_149ms","150ms_plus"].contains(value) { safe["latency_bucket"] = value }
        for key in measurementKeys {
            if let value = properties[key] as? Int, (0...1_000_000_000).contains(value) { safe[key] = value }
        }
        return safe
    }
}

#if !NEPTYPE_CONTAINER_TEST
/// Numeric OS reports only. Stack traces, exception messages and diagnostic JSON never leave the device.
private final class AppHealthMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = AppHealthMonitor()
    private var enabled = false
    private let defaults = UserDefaults.standard
    func start() {
        guard !enabled else { return }; enabled = true
        if defaults.object(forKey: "neptype.health.enabledSince") == nil { defaults.set(Date(),forKey:"neptype.health.enabledSince") }
        MXMetricManager.shared.add(self)
    }
    func stop() {
        enabled = false; MXMetricManager.shared.remove(self)
        defaults.removeObject(forKey: "neptype.health.enabledSince")
    }
    private func accepts(_ begin: Date, _ end: Date, kind: String) -> Bool {
        guard enabled, AppAnalytics.shared.isEnabled,
              let since = defaults.object(forKey: "neptype.health.enabledSince") as? Date, begin >= since else { return false }
        let key = "\(kind):\(begin.timeIntervalSince1970):\(end.timeIntervalSince1970)"
        var seen = defaults.stringArray(forKey:"neptype.health.receipts") ?? []
        guard !seen.contains(key) else { return false }
        seen.append(key); defaults.set(Array(seen.suffix(128)),forKey:"neptype.health.receipts")
        return true
    }
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        DispatchQueue.main.async {
            for payload in payloads where self.accepts(payload.timeStampBegin,payload.timeStampEnd,kind:"diagnostic") {
                AppAnalytics.shared.capture(.diagnosticReceived, measurements:["crash_count":payload.crashDiagnostics?.count ?? 0,"hang_count":payload.hangDiagnostics?.count ?? 0])
            }
        }
    }
    func didReceive(_ payloads: [MXMetricPayload]) {
        DispatchQueue.main.async {
            for payload in payloads {
                guard let exits = payload.applicationExitMetrics?.foregroundExitData,
                      self.accepts(payload.timeStampBegin,payload.timeStampEnd,kind:"exits") else { continue }
                AppAnalytics.shared.capture(.exitHealthReceived, measurements:[
                    "normal_exits":exits.cumulativeNormalAppExitCount,
                    "crash_exits":exits.cumulativeAbnormalExitCount + exits.cumulativeBadAccessExitCount + exits.cumulativeIllegalInstructionExitCount,
                    "watchdog_exits":exits.cumulativeAppWatchdogExitCount,
                    "memory_exits":exits.cumulativeMemoryResourceLimitExitCount])
            }
        }
    }
}
#endif
