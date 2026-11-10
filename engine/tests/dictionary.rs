use neptype_engine::{core, dictionary::Dictionaries};
#[test]
fn one_accepts_common_roman_spellings() {
    for roman in ["eauta", "euta", "yeuta", "yauta"] {
        assert_eq!(core::candidates(roman)[0], "एउटा");
        let mut session = core::Session::default();
        assert!(session.append(roman));
        assert_eq!(session.marked(), "एउटा");
        for mode in [0, 2] {
            let phrase = format!("ma {roman} kitab");
            let rendered = core::render(&phrase, mode, &Default::default());
            assert_eq!(rendered.words[1].value, "एउटा");
        }
    }
}

#[test]
fn every_packed_row_matches_its_source() {
    use sha2::{Digest, Sha256};
    let d = Dictionaries::shared();
    let manifest: serde_json::Value = serde_json::from_str(neptype_engine::dictionary::MANIFEST).unwrap();
    assert_eq!(manifest["schema"], 3);
    assert_eq!(manifest["dictionary"], "roman-nepali-v2-pilot-v1");
    for (file, typos, count_key) in [
        ("roman-nepali-intentional.tsv.gz", false, "intentional_rows"),
        ("roman-nepali-typos.tsv.gz", true, "typo_rows"),
    ] {
        let checks: serde_json::Value = serde_json::from_str(include_str!("../data/decoded-checksums.json")).unwrap();
        let key = if typos { "typos" } else { "intentional" };
        let expected_hash = checks[key].as_str().unwrap();
        let mut hash = Sha256::new();
        let mut count = 0;
        d.visit_rows(typos, |key, values| {
            hash.update(key.as_bytes());
            for value in values { hash.update(b"\t"); hash.update(value.as_bytes()); }
            hash.update(b"\n");
            // Exercise the production binary-search path across the entire index,
            // including block starts/ends and high-collision keys.
            if count % 16384 < 2 || count % 16384 == 63 || values.len() > 64 {
                assert_eq!(if typos { d.typos(key) } else { d.intentional(key) }, values);
            }
            count += 1;
        });
        assert_eq!(format!("{:x}",hash.finalize()),expected_hash,"{file}");
        assert_eq!(count,manifest[count_key].as_u64().unwrap());
    }
}

#[test]
fn intentional_spellings_and_typo_suggestions_stay_separate() {
    let d = Dictionaries::shared();
    assert_eq!(d.intentional("pani")[0], "पनि");
    assert!(d.intentional("pani").contains(&"पानी".to_string()));
    assert!(d.typos("pain").contains(&"पानी".to_string()));
    assert_eq!(core::candidates("namaste")[0], "नमस्ते");
    assert_eq!(d.intentional("NAMASTE"), Vec::<String>::new());
    assert!(d.intentional("").is_empty());
    assert!(d.intentional("not_a_roman_key").is_empty());
}
