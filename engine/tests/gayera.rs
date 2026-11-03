use neptype_engine::{core, dispatch};
use serde_json::json;

#[test]
fn gayera_converts_even_beside_english_words() {
    for mode in [0, 2] {
        assert_eq!(dispatch(&json!({"op":"render","source":"gayera","mode":mode})).unwrap()["text"], "गएर");
    }
    for (source, expected) in [("office gayera", "office गएर"), ("ma office gayera", "म office गएर"), ("Gayera", "गएर")] {
        assert_eq!(dispatch(&json!({"op":"render","source":source})).unwrap()["text"], expected);
    }
    assert_eq!(core::candidates("gayera")[0], "गएर");
    assert!(core::candidates("gayera").contains(&"gayera".to_string()));
    for source in ["https://gayera.com", "gayera@example.com", "`gayera`"] {
        assert_eq!(dispatch(&json!({"op":"render","source":source})).unwrap()["text"], source);
    }
    assert_eq!(dispatch(&json!({"op":"render","source":"gayera","mode":1})).unwrap()["text"], "gayera");
}
