import Foundation
import NepTypePortableCore

// Line-based adapter is an executable conformance harness, not an OS keyboard
// or a stable in-process ABI. Sessions are process-local and never see host text.
struct Request: Decodable {
    var id: String
    var op: String
    var text: String?
    var delta: Int?
    var keepContext: Bool?
    var keepLiteralState: Bool?
    var language: String?
}
struct State: Encodable {
    var roman: String
    var candidates: [String]
    var markedText: String
    var composing: Bool
    var language: String
}
struct Response: Encodable {
    var id: String
    var ok: Bool
    var error: String?
    var accepted: Bool?
    var result: String?
    var state: State?
}
func state(_ session: InputSession) -> State {
    State(roman: session.roman, candidates: session.candidates,
          markedText: session.markedText, composing: session.isComposing,
          language: session.language.rawValue)
}
let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
var sessions: [String: InputSession] = [:]
while let line = readLine() {
    var response = Response(id: "", ok: false)
    do {
        let request = try decoder.decode(Request.self, from: Data(line.utf8))
        response.id = request.id
        if request.id.isEmpty { response.error = "empty session id" }
        else if request.op == "create" {
            if sessions[request.id] != nil { response.error = "session already exists" }
            else { let value = InputSession(); sessions[request.id] = value; response.ok = true; response.state = state(value) }
        } else if request.op == "destroy" {
            if let value = sessions[request.id] {
                if value.isComposing { response.error = "composition must be committed or cancelled"; response.state = state(value) }
                else { sessions.removeValue(forKey: request.id); response.ok = true }
            } else { response.error = "unknown session" }
        } else if var session = sessions[request.id] {
            switch request.op {
            case "state": response.ok = true
            case "append":
                if let text = request.text { response.accepted = session.append(text); response.ok = true }
                else { response.error = "text required" }
            case "backspace": response.accepted = session.backspace(); response.ok = true
            case "cycle":
                if let delta = request.delta { session.cycle(delta); response.ok = true }
                else { response.error = "delta required" }
            case "select":
                if let text = request.text { response.accepted = session.select(text); response.ok = true }
                else { response.error = "text required" }
            case "commit": response.result = session.commit(keepContext: request.keepContext ?? false, keepLiteralState: request.keepLiteralState ?? false); response.ok = true
            case "cancel": response.result = session.cancel(); response.ok = true
            case "set_language":
                if let value = request.language, let language = TypingLanguage(rawValue: value) {
                    // Explicitly reject loss of a pending word; caller commits or cancels first.
                    if session.isComposing { response.error = "composition must be committed or cancelled" }
                    else { session.setLanguage(language); response.ok = true }
                } else { response.error = "invalid language" }
            case "reset":
                if session.isComposing { response.error = "composition must be committed or cancelled" }
                else { session.reset(); response.ok = true }
            default: response.error = "unknown operation"
            }
            sessions[request.id] = session
            response.state = state(session)
        } else { response.error = "unknown session" }
    } catch { response.error = "invalid request" }
    if var data = try? encoder.encode(response) {
        // Write the line immediately; stdio print may remain buffered over a pipe.
        data.append(0x0A)
        FileHandle.standardOutput.write(data)
    }
}
