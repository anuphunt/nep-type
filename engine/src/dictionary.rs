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
impl Dictionaries {
    pub fn shared() -> &'static Self {
        static DATA: OnceLock<Dictionaries> = OnceLock::new();
        DATA.get_or_init(|| {
            assert_eq!(&PACK[..8], b"NEPTYPE2");
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
            let prefix = self.pool[at] as usize;
            let len = self.pool[at + 1] as usize;
            at += 2;
            value.truncate(prefix);
            value.extend_from_slice(&self.pool[at..at + len]);
            at += len;
        }
        value
            .into_iter()
            .map(|b| {
                char::from_u32(if b < 128 {
                    0x900 + b as u32
                } else {
                    0x200c + (b - 128) as u32
                })
                .unwrap()
            })
            .collect()
    }
    fn lookup(&self, key: &str, data: &[u8]) -> Vec<String> {
        if key.is_empty() || !key.bytes().all(|b| b.is_ascii_lowercase()) {
            return vec![];
        }
        let count = u32at(data, 0);
        let base = 4 + count * 4;
        let block_key = |i: usize| {
            let p = base + u32at(data, 4 + i * 4);
            &data[p + 2..p + 2 + data[p + 1] as usize]
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
            let prefix = data[at] as usize;
            let len = data[at + 1] as usize;
            at += 2;
            word.truncate(prefix);
            word.extend_from_slice(&data[at..at + len]);
            at += len;
            let n = data[at] as usize;
            at += 1;
            let mut ids = Vec::with_capacity(n);
            for _ in 0..n {
                let mut id = 0;
                let mut shift = 0;
                loop {
                    let b = data[at];
                    at += 1;
                    id |= ((b & 127) as usize) << shift;
                    if b < 128 {
                        break;
                    }
                    shift += 7;
                }
                ids.push(id);
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
        self.lookup(key, self.aliases)
    }
    pub fn aksh(&self, key: &str) -> Vec<String> {
        self.lookup(key, self.aksh)
    }
}
