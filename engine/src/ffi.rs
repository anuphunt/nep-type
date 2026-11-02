use crate::{core::*, dictionary::Dictionaries};
use std::{
    ffi::{c_char, c_void, CString},
    sync::Mutex,
};
struct Handle {
    composer: Mutex<Composer>,
}
struct ResultHandle {
    strings: Vec<CString>,
    start: i32,
    length: i32,
}
fn cstring(s: String) -> CString {
    CString::new(s).unwrap_or_default()
}
unsafe fn input<'a>(raw: *const c_char, limit: usize) -> Option<&'a str> {
    if raw.is_null() {
        return None;
    }
    let mut len = 0;
    while len <= limit && *raw.add(len) != 0 {
        len += 1;
    }
    if len > limit {
        return None;
    }
    std::str::from_utf8(std::slice::from_raw_parts(raw.cast(), len)).ok()
}
fn result(
    output: String,
    token: String,
    start: i32,
    length: i32,
    candidates: Vec<String>,
) -> *mut c_void {
    let mut strings = vec![cstring(output), cstring(token)];
    strings.extend(candidates.into_iter().map(cstring));
    Box::into_raw(Box::new(ResultHandle {
        strings,
        start,
        length,
    }))
    .cast()
}
#[no_mangle]
pub extern "C" fn neptype_engine_abi_version() -> u32 {
    2
}
#[no_mangle]
pub unsafe extern "C" fn neptype_engine_create(directory: *const c_char) -> *mut c_void {
    // Dictionaries are embedded byte-for-byte in every target. A nonempty legacy
    // directory must still exist, so accidental bad adapter paths fail visibly.
    if !directory.is_null() {
        let Some(path) = input(directory, 32768) else {
            return std::ptr::null_mut();
        };
        if !path.is_empty() && !std::path::Path::new(path).is_dir() {
            return std::ptr::null_mut();
        }
    }
    let _ = Dictionaries::shared();
    Box::into_raw(Box::new(Handle {
        composer: Mutex::new(Composer::default()),
    }))
    .cast()
}
#[no_mangle]
pub unsafe extern "C" fn neptype_engine_destroy(raw: *mut c_void) {
    if !raw.is_null() {
        drop(Box::from_raw(raw.cast::<Handle>()));
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_engine_candidates(
    raw: *mut c_void,
    roman: *const c_char,
    mode: i32,
) -> *mut c_void {
    if raw.is_null() || !(0..=2).contains(&mode) {
        return std::ptr::null_mut();
    }
    let Some(text) = input(roman, 256) else {
        return std::ptr::null_mut();
    };
    let mut session = Session {
        mode: mode as u8,
        ..Default::default()
    };
    let values = if text.is_empty() {
        vec![]
    } else if session.append(text) {
        session.candidates()
    } else {
        vec![text.into()]
    };
    result(String::new(), text.into(), -1, 0, values)
}
#[no_mangle]
pub unsafe extern "C" fn neptype_engine_document(
    raw: *mut c_void,
    source: *const c_char,
    mode: i32,
    caret: i32,
    choice: *const c_char,
) -> *mut c_void {
    if raw.is_null() || !(0..=2).contains(&mode) {
        return std::ptr::null_mut();
    }
    let Some(text) = input(source, 1_048_576) else {
        return std::ptr::null_mut();
    };
    if caret < 0 || caret as usize > units(text) {
        return std::ptr::null_mut();
    }
    let selected = if choice.is_null() {
        None
    } else {
        let Some(value) = input(choice, 4096) else {
            return std::ptr::null_mut();
        };
        Some(value)
    };
    let handle = &*raw.cast::<Handle>();
    let Ok(mut composer) = handle.composer.lock() else {
        return std::ptr::null_mut();
    };
    composer.set_source(text.into());
    composer.set_mode(mode as u8);
    let token = if mode == 1 {
        None
    } else {
        active(text, caret as usize)
    };
    let mut values = vec![];
    if let Some(ref token) = token {
        if let Some(c) = context(text, mode as u8)
            .into_iter()
            .find(|c| c.token == *token)
        {
            values = contextual_candidates(&c);
        }
        if let Some(value) = selected {
            if !values.iter().any(|v| v == value) {
                return std::ptr::null_mut();
            }
            composer.choose(token, value.into());
        }
    } else if selected.is_some() {
        return std::ptr::null_mut();
    }
    result(
        render(text, mode as u8, &composer.current.overrides).text,
        token.as_ref().map(|t| t.text.clone()).unwrap_or_default(),
        token.as_ref().map(|t| t.start as i32).unwrap_or(-1),
        token.map(|t| (t.end - t.start) as i32).unwrap_or(0),
        values,
    )
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_output(raw: *mut c_void) -> *const c_char {
    if raw.is_null() {
        std::ptr::null()
    } else {
        (&*raw.cast::<ResultHandle>()).strings[0].as_ptr()
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_token(raw: *mut c_void) -> *const c_char {
    if raw.is_null() {
        std::ptr::null()
    } else {
        (&*raw.cast::<ResultHandle>()).strings[1].as_ptr()
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_token_start(raw: *mut c_void) -> i32 {
    if raw.is_null() {
        -1
    } else {
        (&*raw.cast::<ResultHandle>()).start
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_token_length(raw: *mut c_void) -> i32 {
    if raw.is_null() {
        0
    } else {
        (&*raw.cast::<ResultHandle>()).length
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_candidate_count(raw: *mut c_void) -> i32 {
    if raw.is_null() {
        0
    } else {
        ((&*raw.cast::<ResultHandle>()).strings.len() - 2) as i32
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_candidate(raw: *mut c_void, index: i32) -> *const c_char {
    if raw.is_null() || index < 0 {
        return std::ptr::null();
    }
    (&*raw.cast::<ResultHandle>())
        .strings
        .get(index as usize + 2)
        .map(|s| s.as_ptr())
        .unwrap_or(std::ptr::null())
}
#[no_mangle]
pub unsafe extern "C" fn neptype_result_destroy(raw: *mut c_void) {
    if !raw.is_null() {
        drop(Box::from_raw(raw.cast::<ResultHandle>()));
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_engine_query(request: *const c_char) -> *mut c_char {
    let Some(text) = input(request, 8 * 1024 * 1024) else {
        return std::ptr::null_mut();
    };
    match crate::query(text) {
        Ok(value) => cstring(value).into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}
#[no_mangle]
pub extern "C" fn neptype_composer_create() -> *mut c_void {
    Box::into_raw(Box::new(Handle {
        composer: Mutex::new(Composer::default()),
    }))
    .cast()
}
#[no_mangle]
pub unsafe extern "C" fn neptype_composer_clone(raw: *mut c_void) -> *mut c_void {
    if raw.is_null() {
        return std::ptr::null_mut();
    }
    let Ok(composer) = (&*raw.cast::<Handle>()).composer.lock() else {
        return std::ptr::null_mut();
    };
    Box::into_raw(Box::new(Handle {
        composer: Mutex::new(composer.clone()),
    }))
    .cast()
}
#[no_mangle]
pub unsafe extern "C" fn neptype_composer_query(
    raw: *mut c_void,
    request: *const c_char,
) -> *mut c_char {
    if raw.is_null() {
        return std::ptr::null_mut();
    }
    let Some(text) = input(request, 8 * 1024 * 1024) else {
        return std::ptr::null_mut();
    };
    let Ok(value) = serde_json::from_str(text) else {
        return std::ptr::null_mut();
    };
    let Ok(mut composer) = (&*raw.cast::<Handle>()).composer.lock() else {
        return std::ptr::null_mut();
    };
    match crate::composer_update(&mut composer, &value)
        .and_then(|v| serde_json::to_string(&v).map_err(|e| e.to_string()))
    {
        Ok(value) => cstring(value).into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}
#[no_mangle]
pub unsafe extern "C" fn neptype_string_destroy(raw: *mut c_char) {
    if !raw.is_null() {
        drop(CString::from_raw(raw));
    }
}
#[no_mangle]
pub extern "C" fn neptype_dictionary_id() -> *const c_char {
    static ID: std::sync::OnceLock<CString> = std::sync::OnceLock::new();
    ID.get_or_init(|| cstring(Dictionaries::shared().id()))
        .as_ptr()
}
