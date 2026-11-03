use neptype_engine::{core::*, dictionary::Dictionaries, dispatch};
use serde_json::json;
use std::collections::HashMap;

#[test]
fn vehicle_spelling_is_first_for_lower_and_title_case() {
    for source in ["gaadi", "Gaadi", "gadi", "Gadi"] {
        for mode in [0, 2] {
            let pad =
                dispatch(&json!({"op":"pad", "source":source, "mode":mode, "caret":source.len()}))
                    .unwrap();
            assert_eq!(pad["rendered"]["text"], "गाडी", "{source}, mode {mode}");
            assert_eq!(pad["candidates"][0], "गाडी", "{source}, mode {mode}");
        }
    }
}

#[test]
fn vehicle_candidates_retain_existing_spellings_and_original_input() {
    let d = Dictionaries::shared();
    for source in ["gaadi", "Gaadi", "gadi", "Gadi"] {
        let values = candidates(source);
        assert_eq!(values.first().unwrap(), "गाडी");
        // Keep the phonetic result, external alternatives, and case-exact Roman input.
        assert_eq!(
            &values[1..],
            &[
                phonetic(source),
                "अगाडि".into(),
                "अगाडी".into(),
                source.into()
            ]
        );
        assert_eq!(d.aliases(&source.to_lowercase()), ["अगाडि", "अगाडी"]);
        assert!(d.aksh(&source.to_lowercase()).is_empty());
    }
    // An authored word must not alter the generic d/i character rules.
    assert_eq!(phonetic("gaadi"), "गादि");
    assert_eq!(phonetic("gadi"), "गदि");
}

#[test]
fn vehicle_lookup_keeps_english_acronyms_and_protected_text() {
    for source in ["gaadi", "Gaadi", "gadi", "Gadi"] {
        assert_eq!(render(source, 1, &HashMap::new()).text, source);
    }
    for source in [
        "GAADI",
        "GADI",
        "gAaDi",
        "gAdI",
        "`gaadi`",
        "https://example.com/gaadi",
        "gaadi@example.com",
        "गाडी",
    ] {
        assert_eq!(render(source, 0, &HashMap::new()).text, source);
    }
    assert_eq!(render("GAADI", 2, &HashMap::new()).text, "गाडी");
    assert_eq!(
        render("mero Gaadi office", 0, &HashMap::new()).text,
        "मेरो गाडी office"
    );
}

#[test]
fn vehicle_session_and_explicit_alternatives_remain_usable() {
    for source in ["gaadi", "Gaadi", "gadi"] {
        let mut session = Session::default();
        for ch in source.chars() {
            assert!(session.append(&ch.to_string()));
        }
        assert_eq!(session.marked(), "गाडी");
        assert_eq!(session.commit(false, false).as_deref(), Some("गाडी"));

        let mut composer = Composer::default();
        composer.set_source(source.into());
        let token = tokens(source).remove(0);
        composer.choose(&token, "अगाडि".into());
        assert_eq!(render(source, 0, &composer.current.overrides).text, "अगाडि");
        composer.undo();
        assert_eq!(render(source, 0, &composer.current.overrides).text, "गाडी");
        composer.redo();
        assert_eq!(render(source, 0, &composer.current.overrides).text, "अगाडि");
        composer.choose(&token, source.into());
        assert_eq!(render(source, 0, &composer.current.overrides).text, source);
    }
}
