use serde::Deserialize;
use std::{
    collections::{HashMap, HashSet},
    sync::OnceLock,
};

pub static PACK: &[u8] = include_bytes!("../data/neptype.pack");
pub const MANIFEST: &str = include_str!("../data/manifest.json");
#[derive(Deserialize)]
struct Meta {
    lexicon: HashMap<String, Vec<String>>,
    common: HashSet<String>,
}
pub struct Dictionaries {
    pub lexicon: HashMap<String, Vec<String>>,
    pub common: HashSet<String>,
    english: &'static [u8],
    pool: &'static [u8],
    aliases: &'static [u8],
    aksh: &'static [u8],
}
fn u32at(data: &[u8], at: usize) -> usize {
    u32::from_le_bytes(data[at..at + 4].try_into().unwrap()) as usize
}
fn varint(data: &[u8], at: &mut usize) -> usize {
    let (mut value, mut shift) = (0, 0);
    loop {
        let b = data[*at];
        *at += 1;
        value |= ((b & 127) as usize) << shift;
        if b < 128 { return value; }
        shift += 7;
        assert!(shift < usize::BITS as usize, "Oversized dictionary integer");
    }
}
impl Dictionaries {
    pub fn shared() -> &'static Self {
        static DATA: OnceLock<Dictionaries> = OnceLock::new();
        DATA.get_or_init(|| {
            assert_eq!(&PACK[..8], b"NEPTYPE3");
            let mut at = 40;
            let mut part = || {
                let len = u32at(PACK, at);
                at += 4;
                let bytes = &PACK[at..at + len];
                at += len;
                bytes
            };
            let meta: Meta = serde_json::from_slice(part()).expect("Canonical dictionary metadata");
            Self {
                lexicon: meta.lexicon,
                common: meta.common,
                english: part(),
                pool: part(),
                aliases: part(),
                aksh: part(),
            }
        })
    }
    pub fn id(&self) -> String {
        PACK[8..40].iter().map(|b| format!("{b:02x}")).collect()
    }
    pub fn known(&self, key: &str) -> bool {
        let mut low = 0;
        let mut high = self.english.len();
        let data = self.english;
        while low < high {
            let mid = (low + high) / 2;
            let mut start = mid;
            while start > low && data[start - 1] != b'\n' {
                start -= 1;
            }
            let mut end = start;
            while end < data.len() && data[end] != b'\n' {
                end += 1;
            }
            match data[start..end].cmp(key.as_bytes()) {
                std::cmp::Ordering::Equal => return true,
                std::cmp::Ordering::Less => low = end + 1,
                _ => high = start,
            }
        }
        false
    }
    fn spelling(&self, id: usize) -> String {
        let count = u32at(self.pool, 0);
        assert!(id < count);
        let blocks = u32at(self.pool, 4);
        let base = 8 + blocks * 4;
        let mut at = base + u32at(self.pool, 8 + (id / 32) * 4);
        let mut value = Vec::new();
        for _ in 0..=id % 32 {
            let prefix = varint(self.pool, &mut at);
            let len = varint(self.pool, &mut at);
            value.truncate(prefix);
            value.extend_from_slice(&self.pool[at..at + len]);
            at += len;
        }
        String::from_utf8(value).expect("UTF-8 dictionary spelling")
    }
    fn lookup(&self, key: &str, data: &[u8]) -> Vec<String> {
        if key.is_empty() || !key.bytes().all(|b| b.is_ascii_lowercase()) {
            return vec![];
        }
        let count = u32at(data, 0);
        let base = 4 + count * 4;
        let block_key = |i: usize| {
            let mut p = base + u32at(data, 4 + i * 4);
            assert_eq!(varint(data, &mut p), 0);
            let len = varint(data, &mut p);
            &data[p..p + len]
        };
        let mut low = 0;
        let mut high = count;
        while low < high {
            let mid = (low + high) / 2;
            if block_key(mid) <= key.as_bytes() {
                low = mid + 1
            } else {
                high = mid
            }
        }
        if low == 0 {
            return vec![];
        }
        let block = low - 1;
        let mut at = base + u32at(data, 4 + block * 4);
        let end = if block + 1 < count {
            base + u32at(data, 8 + block * 4)
        } else {
            data.len()
        };
        let mut word = Vec::new();
        while at < end {
            let prefix = varint(data, &mut at);
            let len = varint(data, &mut at);
            word.truncate(prefix);
            word.extend_from_slice(&data[at..at + len]);
            at += len;
            let n = varint(data, &mut at);
            let mut ids = Vec::with_capacity(n);
            for _ in 0..n {
                ids.push(varint(data, &mut at));
            }
            match word.as_slice().cmp(key.as_bytes()) {
                std::cmp::Ordering::Equal => {
                    return ids.into_iter().map(|id| self.spelling(id)).collect()
                }
                std::cmp::Ordering::Greater => return vec![],
                _ => {}
            }
        }
        vec![]
    }
    pub fn aliases(&self, key: &str) -> Vec<String> {
        // Compatibility method for the former external-alias API.
        self.typos(key)
    }
    pub fn typos(&self, key: &str) -> Vec<String> {
        self.lookup(key, self.aliases)
    }
    pub fn aksh(&self, key: &str) -> Vec<String> {
        // Compatibility method; no Aksharantar dictionary remains in the pack.
        self.intentional(key)
    }
    pub fn intentional(&self, key: &str) -> Vec<String> {
        self.lookup(key, self.aksh)
    }
    /// Stream the embedded rows for exhaustive source verification without
    /// materializing the 29 million Roman keys in memory.
    pub fn visit_rows(&self, typos: bool, mut visit: impl FnMut(&str, &[String])) {
        let data = if typos { self.aliases } else { self.aksh };
        let blocks = u32at(data, 0);
        let mut at = 4 + blocks * 4;
        let mut key = Vec::new();
        while at < data.len() {
            let prefix = varint(data, &mut at);
            let len = varint(data, &mut at);
            key.truncate(prefix);
            key.extend_from_slice(&data[at..at + len]);
            at += len;
            let count = varint(data, &mut at);
            let values: Vec<String> = (0..count)
                .map(|_| self.spelling(varint(data, &mut at)))
                .collect();
            visit(std::str::from_utf8(&key).unwrap(), &values);
        }
    }
}
