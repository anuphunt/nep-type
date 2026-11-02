use neptype_engine::dictionary::Dictionaries;
use std::{
    fs::File,
    io::{BufRead, BufReader},
    path::Path,
};
#[test]
fn every_packed_row_matches_its_source() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let d = Dictionaries::shared();
    let mut count = 0;
    for (file, aksh) in [
        ("google-ne-aliases.tsv", false),
        ("aksharantar-indiccorp-v1.tsv", true),
    ] {
        for row in
            BufReader::new(File::open(root.join("data/compiled").join(file)).unwrap()).lines()
        {
            let row = row.unwrap();
            let mut parts = row.split('\t');
            let key = parts.next().unwrap();
            let expected: Vec<String> = parts.map(String::from).collect();
            assert_eq!(
                if aksh { d.aksh(key) } else { d.aliases(key) },
                expected,
                "{file}: {key}"
            );
            count += 1;
        }
    }
    assert_eq!(count, 2_449_776);
}
