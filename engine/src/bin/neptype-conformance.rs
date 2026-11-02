//! JSON-lines host adapter. The Linux IBus transport uses this same Rust core.
use neptype_engine::core::Session;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    io::{self, BufRead, Write},
};
fn state(s: &Session) -> Value {
    json!({"roman":s.roman,"candidates":s.candidates(),"markedText":s.marked(),"composing":!s.roman.is_empty(),"language":(["nepali","english","allNepali"][s.mode as usize])})
}
fn main() {
    let mut sessions: HashMap<String, Session> = HashMap::new();
    let mut out = io::BufWriter::new(io::stdout());
    for line in io::stdin().lock().lines() {
        let Ok(line) = line else { break };
        let mut response = json!({"id":"","ok":false});
        if let Ok(r) = serde_json::from_str::<Value>(&line) {
            let id = r["id"].as_str().unwrap_or("");
            let op = r["op"].as_str().unwrap_or("");
            response["id"] = json!(id);
            if id.is_empty() {
                response["error"] = json!("empty session id");
            } else if op == "create" {
                if sessions.contains_key(id) {
                    response["error"] = json!("session already exists");
                } else {
                    let s = Session::default();
                    response["ok"] = json!(true);
                    response["state"] = state(&s);
                    sessions.insert(id.into(), s);
                }
            } else if op == "destroy" {
                if let Some(s) = sessions.get(id) {
                    if !s.roman.is_empty() {
                        response["error"] = json!("composition must be committed or cancelled");
                        response["state"] = state(s);
                    } else {
                        sessions.remove(id);
                        response["ok"] = json!(true);
                    }
                } else {
                    response["error"] = json!("unknown session");
                }
            } else if let Some(s) = sessions.get_mut(id) {
                let mut error = None;
                response["ok"] = json!(true);
                match op {
                    "state" => {}
                    "append" => {
                        if let Some(text) = r["text"].as_str() {
                            response["accepted"] = json!(s.append(text));
                        } else {
                            error = Some("text required")
                        }
                    }
                    "backspace" => response["accepted"] = json!(s.backspace()),
                    "cycle" => {
                        if let Some(delta) = r["delta"].as_i64() {
                            s.cycle(delta)
                        } else {
                            error = Some("delta required")
                        }
                    }
                    "select" => {
                        if let Some(text) = r["text"].as_str() {
                            response["accepted"] = json!(s.select(text));
                        } else {
                            error = Some("text required")
                        }
                    }
                    "commit" => {
                        response["result"] = json!(s.commit(
                            r["keepContext"].as_bool().unwrap_or(false),
                            r["keepLiteralState"].as_bool().unwrap_or(false)
                        ))
                    }
                    "cancel" => response["result"] = json!(s.cancel()),
                    "set_language" => {
                        if let Some(m) = ["nepali", "english", "allNepali"]
                            .iter()
                            .position(|s| Some(*s) == r["language"].as_str())
                        {
                            if s.roman.is_empty() {
                                s.reset();
                                s.mode = m as u8;
                            } else {
                                error = Some("composition must be committed or cancelled")
                            }
                        } else {
                            error = Some("invalid language")
                        }
                    }
                    "reset" => {
                        if s.roman.is_empty() {
                            s.reset()
                        } else {
                            error = Some("composition must be committed or cancelled")
                        }
                    }
                    _ => error = Some("unknown operation"),
                }
                if let Some(e) = error {
                    response["ok"] = json!(false);
                    response["error"] = json!(e);
                }
                response["state"] = state(s);
            } else {
                response["error"] = json!("unknown session");
            }
        } else {
            response["error"] = json!("invalid request");
        }
        if writeln!(out, "{response}")
            .and_then(|_| out.flush())
            .is_err()
        {
            break;
        }
    }
}
