pub mod core;
pub mod dictionary;
mod ffi;
use core::*;
use dictionary::Dictionaries;
use serde_json::{json, Value};
use std::collections::HashMap;

fn mode(v: &Value) -> u8 {
    v.get("mode").and_then(Value::as_u64).unwrap_or(0).min(2) as u8
}
fn text<'a>(v: &'a Value, key: &str) -> &'a str {
    v.get(key).and_then(Value::as_str).unwrap_or("")
}
pub fn dispatch(request: &Value) -> Result<Value, String> {
    let s = text(request, "source");
    let m = mode(request);
    let d = Dictionaries::shared();
    let overrides: HashMap<usize, String> = request
        .get("overrides")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();
    let op = text(request, "op");
    Ok(match op {
        "info" => {
            json!({"dictionary":serde_json::from_str::<Value>(dictionary::MANIFEST).unwrap(),"engine":"rust","version":env!("CARGO_PKG_VERSION")})
        }
        "analyze" => {
            json!({"tokens":tokens(s),"context":context(s,m),"candidates":candidates(s),"experimental":experimental(s),"aksharantar":aksharantar(s),"phonetic":phonetic(s),"known":d.known(&s.to_lowercase()),"usesAksharantar":uses_aksh(s),"output":render(s,m,&overrides).text})
        }
        "tokens" => json!(tokens(s)),
        "phonetic" => json!(phonetic(s)),
        "known" => json!(d.known(&s.to_lowercase())),
        "candidates" => json!(candidates(s)),
        "experimental" => json!(experimental(s)),
        "aksharantar" => json!(aksharantar(s)), // legacy protocol name
        "dictionaryCandidates" => json!(Dictionaries::shared().intentional(&s.to_lowercase())),
        "typoCandidates" => json!(Dictionaries::shared().typos(&s.to_lowercase())),
        "usesAksharantar" => json!(uses_aksh(s)),
        "context" => json!(context(s, m)),
        "contextualCandidates" => json!(contextual_candidates(
            &serde_json::from_value(request["choice"].clone()).map_err(|e| e.to_string())?
        )),
        "render" => json!(render(s, m, &overrides)),
        "pad" | "composer" => {
            let mut composer: Composer = request
                .get("state")
                .and_then(|v| serde_json::from_value(v.clone()).ok())
                .unwrap_or_default();
            let mut value = composer_update(&mut composer, request)?;
            value["state"] = serde_json::to_value(&composer).map_err(|e| e.to_string())?;
            value
        }
        "retainChoices" => {
            let choices: HashMap<usize, String> =
                serde_json::from_value(request.get("choices").cloned().unwrap_or(json!({})))
                    .map_err(|e| e.to_string())?;
            json!(retain_choices(text(request, "old"), s, &choices))
        }
        "session" => {
            let mut session: Session = request
                .get("state")
                .and_then(|v| serde_json::from_value(v.clone()).ok())
                .unwrap_or(Session {
                    mode: m,
                    ..Default::default()
                });
            let actions = request
                .get("actions")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default();
            let mut trace = Vec::new();
            for action in actions {
                let mut accepted = None;
                let mut result = None;
                match text(&action, "op") {
                    "append" => accepted = Some(session.append(text(&action, "text"))),
                    "backspace" => accepted = Some(session.backspace()),
                    "cycle" => session.cycle(action["delta"].as_i64().unwrap_or(1)),
                    "select" => accepted = Some(session.select(text(&action, "text"))),
                    "commit" => {
                        result = session.commit(
                            action["keepContext"].as_bool().unwrap_or(false),
                            action["keepLiteralState"].as_bool().unwrap_or(false),
                        )
                    }
                    "cancel" => result = session.cancel(),
                    "reset" => session.reset(),
                    "setMode" => {
                        session.reset();
                        session.mode = mode(&action);
                    }
                    _ => return Err("Unknown session operation".into()),
                }
                trace.push(json!({"roman":session.roman,"context":session.context,"selection":session.selection,"candidates":session.candidates(),"markedText":session.marked(),"accepted":accepted,"result":result}));
            }
            json!({"state":session,"candidates":session.candidates(),"markedText":session.marked(),"trace":trace})
        }
        _ => return Err("Unknown engine operation".into()),
    })
}
// Stateful adapters keep history in Rust. Only the current view crosses the ABI.
pub fn composer_update(c: &mut Composer, request: &Value) -> Result<Value, String> {
    if let Some(values) = request.get("preferences") {
        c.set_preferences(serde_json::from_value(values.clone()).map_err(|e| e.to_string())?);
    }
    if text(request, "op") == "pad" {
        let source = text(request, "source");
        if source.len() > 1_048_576 {
            return Err("Document is too large".into());
        }
        match text(request, "operation") {
            "undo" => c.undo(),
            "redo" => c.redo(),
            _ => {
                c.set_source(source.into());
                c.set_mode(mode(request));
                if let Some(value) = request.get("choice").and_then(Value::as_str) {
                    let token: Token = serde_json::from_value(request["token"].clone())
                        .map_err(|e| e.to_string())?;
                    c.choose(&token, value.into());
                }
            }
        }
    } else if text(request, "op") == "composer" {
        if let Some(actions) = request.get("actions").and_then(Value::as_array) {
            for action in actions {
                match text(action, "op") {
                    "source" => c.set_source(text(action, "text").into()),
                    "mode" => c.set_mode(mode(action)),
                    "choose" => {
                        let token: Token = serde_json::from_value(action["token"].clone())
                            .map_err(|e| e.to_string())?;
                        c.choose(&token, text(action, "value").into());
                    }
                    "undo" => c.undo(),
                    "redo" => c.redo(),
                    "preferences" => c.set_preferences(
                        serde_json::from_value(action["values"].clone())
                            .map_err(|e| e.to_string())?,
                    ),
                    _ => return Err("Unknown composer operation".into()),
                }
            }
        }
    } else {
        return Err("Unknown composer request".into());
    }
    if let Some(values) = request.get("restoreChoices").and_then(Value::as_object) {
        let source = c.current.source.clone();
        for token in tokens(&source).into_iter().filter(|t| !t.literal) {
            if let Some(value) = values.get(&token.start.to_string()).and_then(Value::as_str) {
                c.choose(&token, value.into());
            }
        }
    }
    let mut value = json!({"state":{"current":c.current},"canUndo":!c.past.is_empty(),"canRedo":!c.future.is_empty()});
    if request["deferRender"].as_bool() != Some(true) {
        value["rendered"] = json!(c.rendered());
    }
    if text(request, "op") == "pad" {
        let caret = request["caret"].as_u64().unwrap_or(0) as usize;
        let token = if c.current.mode == 1 {
            None
        } else {
            active(&c.current.source, caret)
        };
        let mut candidates = token
            .as_ref()
            .and_then(|token| {
                context(&c.current.source, c.current.mode)
                    .into_iter()
                    .find(|v| v.token == *token)
            })
            .map(|v| contextual_candidates(&v))
            .unwrap_or_default();
        if let Some(ref token) = token {
            c.order_preferences(&token.text, &mut candidates);
        }
        value["source"] = json!(c.current.source);
        value["mode"] = json!(c.current.mode);
        value["active"] = json!(token);
        value["candidates"] = json!(candidates);
    }
    Ok(value)
}
pub fn query(request: &str) -> Result<String, String> {
    if request.len() > 8 * 1024 * 1024 {
        return Err("Request is too large".into());
    }
    let value: Value = serde_json::from_str(request).map_err(|e| e.to_string())?;
    serde_json::to_string(&dispatch(&value)?).map_err(|e| e.to_string())
}
#[cfg(target_arch = "wasm32")]
mod wasm {
    use wasm_bindgen::prelude::*;
    #[wasm_bindgen(js_name=query)]
    pub fn query(request: &str) -> Result<String, JsValue> {
        super::query(request).map_err(|e| JsValue::from_str(&e))
    }
    #[wasm_bindgen]
    pub struct PadEngine {
        composer: super::Composer,
    }
    impl Default for PadEngine {
        fn default() -> Self {
            Self::new()
        }
    }
    #[wasm_bindgen]
    impl PadEngine {
        #[wasm_bindgen(constructor)]
        pub fn new() -> Self {
            Self {
                composer: super::Composer::default(),
            }
        }
        pub fn request(&mut self, request: &str) -> Result<String, JsValue> {
            let value: super::Value =
                serde_json::from_str(request).map_err(|e| JsValue::from_str(&e.to_string()))?;
            let result = super::composer_update(&mut self.composer, &value)
                .map_err(|e| JsValue::from_str(&e))?;
            serde_json::to_string(&result).map_err(|e| JsValue::from_str(&e.to_string()))
        }
    }
    #[wasm_bindgen(js_name=dictionaryId)]
    pub fn dictionary_id() -> String {
        super::Dictionaries::shared().id()
    }
}
