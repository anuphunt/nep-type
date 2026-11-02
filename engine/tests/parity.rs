use serde_json::Value;
#[test]
fn frozen_swift_behavior() {
    let corpus = include_str!("../../shared/fixtures/swift-baseline.jsonl");
    let mut count = 0;
    for line in corpus.lines() {
        let case: Value = serde_json::from_str(line).unwrap();
        let mut actual = neptype_engine::dispatch(&case["request"]).unwrap();
        if case["request"]["op"] == "session" {
            actual = serde_json::json!({"trace":actual["trace"]});
        }
        assert_eq!(
            actual, case["expected"],
            "Case {}: {}",
            count, case["request"]
        );
        count += 1;
    }
    assert!(count > 2000);
    eprintln!("Verified {count} frozen Swift behavior cases");
}
#[test]
fn dictionary_integrity() {
    use sha2::{Digest, Sha256};
    let data = neptype_engine::dictionary::PACK;
    assert_eq!(&Sha256::digest(&data[40..])[..], &data[8..40]);
}
