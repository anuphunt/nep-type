import Foundation

@main
enum AnalyticsTests {
    static func main() {
        let suite = "app.neptype.analytics-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = ISO8601DateFormatter().date(from: "2026-11-02T23:59:59Z")!
        var events: [(String, [String: Any])] = []
        let analytics = AppAnalytics(defaults: defaults, now: { date }, send: { events.append(($0, $1)) })
        analytics.becameActive()
        // Displaying the prefilled example must never activate the editing metric.
        precondition(events.map(\.0) == [AppAnalytics.Event.appOpened.rawValue])
        for _ in 0..<100 { analytics.usedPad(mode: .mixed) }
        precondition(events.filter { $0.0 == AppAnalytics.Event.padUsed.rawValue }.count == 1)
        date = date.addingTimeInterval(2)
        analytics.usedPad(mode: .allNepali)
        precondition(events.filter { $0.0 == AppAnalytics.Event.appOpened.rawValue }.count == 2)
        precondition(events.filter { $0.0 == AppAnalytics.Event.padUsed.rawValue }.count == 2)
        analytics.setEnabled(false)
        let count = events.count
        analytics.becameActive()
        analytics.usedPad(mode: .mixed)
        analytics.capture(.outputCopied, mode: .mixed, origin: .edited)
        precondition(events.count == count)
        precondition(!AppAnalytics(defaults: defaults).isEnabled)
        analytics.setEnabled(true)
        precondition(events.count == count + 1)

        let text = "private typing नमस्ते email@example.com"
        let hostile: [String: Any] = ["text": text, "clipboard": text, "$set": ["email": text],
                                    "$device_id": text, "$session_id": text, "mode": text,
                                    "choice_kind": text, "content_origin": text,
                                    "app_version": text, "app_build": "3", "is_test": true]
        let safe = AppAnalytics.sanitized(event: AppAnalytics.Event.outputCopied.rawValue, properties: hostile)!
        precondition(!String(describing: safe).contains(text))
        precondition(safe["$geoip_disable"] as? Bool == true && safe["$ip"] as? String == "")
        precondition(safe["app_build"] as? String == "3" && safe["app_version"] == nil)
        precondition(AppAnalytics.sanitized(event: "$screen", properties: hostile) == nil)
        precondition(AppAnalytics.sanitized(event: "$snapshot", properties: hostile) == nil)
        let health = AppAnalytics.sanitized(event: AppAnalytics.Event.diagnosticReceived.rawValue,
            properties: ["crash_count": 2, "hang_count": -1, "stack_trace": text, "latency_bucket": text])!
        precondition(health["crash_count"] as? Int == 2 && health["hang_count"] == nil)
        precondition(health["stack_trace"] == nil && health["latency_bucket"] == nil)
        for event in AppAnalytics.Event.allCases {
            precondition(AppAnalytics.sanitized(event: event.rawValue, properties: ["mode": "all_nepali", "choice_kind": "original", "content_origin": "edited"]) != nil)
        }
        print("Analytics checks passed: edit throttling, UTC rollover, persistent opt-out, example exclusion, property redaction, automatic-event rejection.")
    }
}
