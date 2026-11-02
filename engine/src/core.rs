use crate::dictionary::Dictionaries;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet},
    sync::OnceLock,
};
use unicode_segmentation::UnicodeSegmentation;

pub fn native(s: &str) -> bool {
    s.chars().any(|c| ('\u{0900}'..='\u{097f}').contains(&c))
}
pub fn unique(values: impl IntoIterator<Item = String>) -> Vec<String> {
    let mut seen = HashSet::new();
    values
        .into_iter()
        .filter(|s| !s.is_empty() && seen.insert(s.clone()))
        .collect()
}
pub fn units(s: &str) -> usize {
    s.encode_utf16().count()
}
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Token {
    pub text: String,
    pub start: usize,
    pub end: usize,
    pub literal: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Choice {
    pub token: Token,
    pub preferred: String,
    pub uncertain: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Word {
    #[serde(flatten)]
    pub token: Token,
    pub value: String,
    #[serde(rename = "outputStart")]
    pub output_start: usize,
    #[serde(rename = "outputEnd")]
    pub output_end: usize,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Rendered {
    pub text: String,
    pub words: Vec<Word>,
}
pub fn tokens(source: &str) -> Vec<Token> {
    static RE: OnceLock<Regex> = OnceLock::new();
    let re=RE.get_or_init(||Regex::new(r#"(?s:```(?:.*?```|.*\z))|(?i:https?://[^\s]+|www\.[^\s]+|[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})|(?m:`[^`\n]*(?:`|$))|(?:[A-Za-z0-9._~\-]+/)+[A-Za-z0-9._~\-]+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+|(?:[A-Za-z_][A-Za-z0-9_]*[0-9_][A-Za-z0-9_]*|[0-9]+[A-Za-z_][A-Za-z0-9_]*)|[a-z]+[A-Z][A-Za-z]*|[A-Za-z]+(?:['’_-][A-Za-z]+)+|[A-Za-z]+"#).unwrap());
    let mut byte = 0;
    let mut offset = 0;
    re.find_iter(source)
        .map(|m| {
            offset += units(&source[byte..m.start()]);
            let start = offset;
            let text = m.as_str();
            offset += units(text);
            byte = m.end();
            let mixed = text.chars().next().is_some_and(|c| c.is_lowercase())
                && text.chars().skip(1).any(|c| c.is_uppercase());
            Token {
                text: text.into(),
                start,
                end: offset,
                literal: mixed
                    || text.contains("://")
                    || text.to_lowercase().starts_with("www.")
                    || text
                        .chars()
                        .any(|c| "@`'’-_./".contains(c) || c.is_numeric()),
            }
        })
        .collect()
}
pub fn phonetic(input: &str) -> String {
    let consonants = [
        ("ksh", "क्ष"),
        ("chh", "छ"),
        ("gy", "ज्ञ"),
        ("jn", "ज्ञ"),
        ("kh", "ख"),
        ("gh", "घ"),
        ("ch", "च"),
        ("jh", "झ"),
        ("th", "थ"),
        ("dh", "ध"),
        ("ph", "फ"),
        ("bh", "भ"),
        ("sh", "श"),
        ("ng", "ङ"),
        ("ny", "ञ"),
        ("k", "क"),
        ("g", "ग"),
        ("c", "च"),
        ("j", "ज"),
        ("t", "त"),
        ("d", "द"),
        ("n", "न"),
        ("p", "प"),
        ("b", "ब"),
        ("m", "म"),
        ("y", "य"),
        ("r", "र"),
        ("l", "ल"),
        ("w", "व"),
        ("v", "व"),
        ("s", "स"),
        ("h", "ह"),
        ("f", "फ"),
        ("q", "क"),
        ("x", "क्स"),
        ("z", "ज"),
    ];
    let vowels = [
        ("aa", "आ", "ा"),
        ("ai", "ऐ", "ै"),
        ("au", "औ", "ौ"),
        ("ee", "ई", "ी"),
        ("ii", "ई", "ी"),
        ("oo", "ऊ", "ू"),
        ("uu", "ऊ", "ू"),
        ("a", "अ", ""),
        ("i", "इ", "ि"),
        ("u", "उ", "ु"),
        ("e", "ए", "े"),
        ("o", "ओ", "ो"),
    ];
    let text = input.to_lowercase();
    let mut s = text.as_str();
    let mut out = String::new();
    let starts = |s: &str, key: &str| {
        s.starts_with(key)
            && (s.len() == key.len() || s.grapheme_indices(true).any(|(i, _)| i == key.len()))
    };
    while !s.is_empty() {
        if let Some((key, value)) = consonants.iter().find(|(key, _)| starts(s, key)) {
            out.push_str(value);
            s = &s[key.len()..];
            if let Some((key, _, value)) = vowels.iter().find(|(key, _, _)| starts(s, key)) {
                out.push_str(value);
                s = &s[key.len()..];
            } else if consonants.iter().any(|(key, _)| starts(s, key)) {
                out.push('्');
            }
        } else if let Some((key, value, _)) = vowels.iter().find(|(key, _, _)| starts(s, key)) {
            out.push_str(value);
            s = &s[key.len()..];
        } else {
            let ch = s.graphemes(true).next().unwrap();
            out.push_str(ch);
            s = &s[ch.len()..];
        }
    }
    out
}
pub fn base(input: &str) -> Vec<String> {
    if input.is_empty() {
        return vec![];
    }
    let d = Dictionaries::shared();
    let key = input.to_lowercase();
    let mut choices = d.lexicon.get(&key).cloned().unwrap_or_default();
    if d.common.contains(&key)
        || (input.graphemes(true).count() > 1 && input == input.to_uppercase())
        || (choices.is_empty() && d.known(&key) && d.aliases(&key).is_empty())
    {
        choices.insert(0, input.into());
    } else if choices.is_empty() {
        let matches = d.aksh(&key);
        if key.graphemes(true).count() >= 3 && matches.len() == 1 {
            choices.push(matches[0].clone());
        }
    }
    choices.push(phonetic(&key));
    choices.push(input.into());
    unique(choices)
}
pub fn experimental(input: &str) -> Vec<String> {
    let b = base(input);
    Dictionaries::shared()
        .aliases(&input.to_lowercase())
        .into_iter()
        .filter(|s| !b.contains(s))
        .collect()
}
pub fn aksharantar(input: &str) -> Vec<String> {
    let b = base(input);
    Dictionaries::shared()
        .aksh(&input.to_lowercase())
        .into_iter()
        .filter(|s| !b.contains(s))
        .collect()
}
pub fn uses_aksh(input: &str) -> bool {
    let key = input.to_lowercase();
    let d = Dictionaries::shared();
    let a = d.aksh(&key);
    key.graphemes(true).count() >= 3
        && !d.lexicon.contains_key(&key)
        && a.len() == 1
        && base(input).first() == a.first()
}
pub fn candidates(input: &str) -> Vec<String> {
    let mut b = base(input);
    if b.is_empty() {
        return b;
    }
    if b.last().is_some_and(|s| s == input) {
        b.pop();
    }
    b.extend(aksharantar(input).into_iter().filter(|s| s != input));
    b.extend(experimental(input).into_iter().filter(|s| s != input));
    b.push(input.into());
    unique(b)
}
pub fn contextual_candidates(choice: &Choice) -> Vec<String> {
    let mut c = candidates(&choice.token.text);
    if c.contains(&choice.preferred) {
        c.retain(|s| s != &choice.preferred);
        c.insert(0, choice.preferred.clone());
    }
    c
}
pub fn context(source: &str, mode: u8) -> Vec<Choice> {
    struct Evidence {
        e: i32,
        n: i32,
        ea: bool,
        na: bool,
        preferred: Option<String>,
    }
    let words = tokens(source);
    let text: Vec<u16> = source.encode_utf16().collect();
    let d = Dictionaries::shared();
    let evidence: Vec<Evidence> = words
        .iter()
        .map(|w| {
            let key = w.text.to_lowercase();
            let curated = d.lexicon.get(&key);
            let common = d.common.contains(&key);
            let known = common || d.known(&key);
            let a = d.aksh(&key);
            if w.literal {
                return Evidence {
                    e: 0,
                    n: 0,
                    ea: false,
                    na: false,
                    preferred: None,
                };
            }
            Evidence {
                e: if common {
                    5
                } else if known {
                    if curated.is_none() {
                        3
                    } else {
                        1
                    }
                } else {
                    0
                },
                n: if curated.is_some() {
                    5
                } else if a.len() == 1 && key.len() >= 3 {
                    4
                } else {
                    0
                },
                ea: common && curated.is_none(),
                na: curated.is_some() && !common,
                preferred: curated.and_then(|v| v.first().cloned()).or_else(|| {
                    if a.len() == 1 && key.len() >= 3 {
                        a.first().cloned()
                    } else {
                        None
                    }
                }),
            }
        })
        .collect();
    let contiguous = |a: usize, b: usize| {
        !words[a].literal
            && !words[b].literal
            && words[b].start > words[a].end
            && text[words[a].end..words[b].start]
                .iter()
                .all(|v| *v == 32 || *v == 9)
    };
    words
        .iter()
        .enumerate()
        .map(|(i, w)| {
            let item = &evidence[i];
            let key = w.text.to_lowercase();
            let mut c = if w.literal
                || (w.text.graphemes(true).count() > 1 && w.text == w.text.to_uppercase())
            {
                Choice {
                    token: w.clone(),
                    preferred: w.text.clone(),
                    uncertain: false,
                }
            } else if d.common.contains(&key) && d.lexicon.contains_key(&key) {
                Choice {
                    token: w.clone(),
                    preferred: w.text.clone(),
                    uncertain: true,
                }
            } else {
                let (mut e, mut n) = (item.e, item.n);
                for j in [
                    i.checked_sub(1),
                    if i + 1 < words.len() {
                        Some(i + 1)
                    } else {
                        None
                    },
                ]
                .into_iter()
                .flatten()
                {
                    if contiguous(i.min(j), i.max(j)) {
                        if evidence[j].ea {
                            e += 3
                        }
                        if evidence[j].na {
                            n += 3
                        }
                    }
                }
                if i > 0
                    && contiguous(i - 1, i)
                    && ["the", "a", "an"].contains(&words[i - 1].text.to_lowercase().as_str())
                    && item.e > 0
                {
                    e += 4;
                }
                if item.e == 0 && item.n == 0 {
                    Choice {
                        token: w.clone(),
                        preferred: phonetic(&w.text),
                        uncertain: true,
                    }
                } else if e >= n + 2 && item.e > 0 {
                    Choice {
                        token: w.clone(),
                        preferred: w.text.clone(),
                        uncertain: false,
                    }
                } else if (n >= e + 2 || (d.lexicon.contains_key(&key) && n > e))
                    && item.preferred.is_some()
                {
                    Choice {
                        token: w.clone(),
                        preferred: item.preferred.clone().unwrap(),
                        uncertain: d
                            .lexicon
                            .get(&key)
                            .is_some_and(|v| v.iter().collect::<HashSet<_>>().len() > 1),
                    }
                } else {
                    Choice {
                        token: w.clone(),
                        preferred: w.text.clone(),
                        uncertain: true,
                    }
                }
            };
            if mode == 2 && !w.literal && !native(&c.preferred) {
                c.preferred = candidates(&w.text)
                    .into_iter()
                    .find(|s| native(s))
                    .unwrap_or_else(|| phonetic(&w.text));
                c.uncertain = true;
            }
            c
        })
        .collect()
}
pub fn active(source: &str, caret: usize) -> Option<Token> {
    tokens(source)
        .into_iter()
        .find(|w| !w.literal && caret >= w.start && caret <= w.end)
}
const ABBREVIATIONS: [&str; 10] = [
    "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc",
];
pub fn render(source: &str, mode: u8, overrides: &HashMap<usize, String>) -> Rendered {
    let choices = context(source, mode);
    let mut text: Vec<u16> = source.encode_utf16().collect();
    let mut stops = HashSet::new();
    if mode != 1 {
        let (mut index, mut choice_index, mut has_nepali) = (0, 0, false);
        let mut previous: Option<&Token> = None;
        while index < text.len() {
            if let Some(c) = choices.get(choice_index).filter(|c| c.token.start == index) {
                if !c.token.literal {
                    has_nepali |= native(overrides.get(&index).unwrap_or(&c.preferred));
                }
                previous = Some(&c.token);
                index = c.token.end;
                choice_index += 1;
                continue;
            }
            let ch = text[index];
            has_nepali |= (0x900..=0x97f).contains(&ch);
            if ch == 46 {
                let left = if index > 0 { text[index - 1] } else { 0 };
                let right = text.get(index + 1).copied().unwrap_or(0);
                if left != 46 && right != 46 {
                    let mut end = index + 1;
                    while end < text.len()
                        && [34, 39, 41, 93, 125, 0x2019, 0x201d].contains(&text[end])
                    {
                        end += 1;
                    }
                    let boundary = end == text.len()
                        || char::from_u32(text[end] as u32)
                            .is_some_and(|c| c.is_whitespace() || c == '\u{200b}');
                    let abbreviation = previous.is_some_and(|w| {
                        w.end == index
                            && (w.literal
                                || ABBREVIATIONS.contains(&w.text.to_lowercase().as_str()))
                    });
                    if boundary && !abbreviation {
                        if has_nepali {
                            stops.insert(index);
                        }
                        has_nepali = false;
                    }
                }
            } else if [33, 63, 10, 0x964].contains(&ch) {
                has_nepali = false;
            }
            index += 1;
        }
    }
    for at in stops {
        text[at] = 0x964;
    }
    let mut out = Vec::new();
    let mut words = Vec::new();
    let mut at = 0;
    for c in choices {
        let w = c.token;
        out.extend_from_slice(&text[at..w.start]);
        let value = if mode == 1 || w.literal {
            w.text.clone()
        } else {
            overrides.get(&w.start).cloned().unwrap_or(c.preferred)
        };
        let start = out.len();
        out.extend(value.encode_utf16());
        if !w.literal && !value.is_empty() {
            words.push(Word {
                token: w.clone(),
                value,
                output_start: start,
                output_end: out.len(),
            });
        }
        at = w.end;
    }
    out.extend_from_slice(&text[at..]);
    Rendered {
        text: String::from_utf16(&out).unwrap(),
        words,
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Snapshot {
    pub source: String,
    pub mode: u8,
    pub overrides: HashMap<usize, String>,
}
#[derive(Clone, Default, Serialize, Deserialize)]
pub struct Composer {
    pub current: Snapshot,
    pub past: Vec<Snapshot>,
    pub future: Vec<Snapshot>,
}
impl Composer {
    fn checkpoint(&mut self) {
        self.past.push(self.current.clone());
        if self.past.len() > 200 {
            self.past.remove(0);
        }
        self.future.clear();
    }
    pub fn set_source(&mut self, value: String) {
        if self.current.source == value {
            return;
        }
        self.checkpoint();
        self.current.overrides =
            retain_choices(&self.current.source, &value, &self.current.overrides);
        self.current.source = value;
    }
    pub fn set_mode(&mut self, mode: u8) {
        if self.current.mode != mode {
            self.checkpoint();
            self.current.mode = mode;
        }
    }
    pub fn choose(&mut self, token: &Token, value: String) {
        if self.current.mode == 1
            || token.literal
            || !tokens(&self.current.source).contains(token)
            || !candidates(&token.text).contains(&value)
            || self.current.overrides.get(&token.start) == Some(&value)
        {
            return;
        }
        self.checkpoint();
        self.current.overrides.insert(token.start, value);
    }
    pub fn undo(&mut self) {
        if let Some(state) = self.past.pop() {
            self.future.push(self.current.clone());
            self.current = state;
        }
    }
    pub fn redo(&mut self) {
        if let Some(state) = self.future.pop() {
            self.past.push(self.current.clone());
            self.current = state;
        }
    }
}
pub fn retain_choices(
    old: &str,
    new: &str,
    choices: &HashMap<usize, String>,
) -> HashMap<usize, String> {
    if choices.is_empty() {
        return HashMap::new();
    }
    let a: Vec<u16> = old.encode_utf16().collect();
    let b: Vec<u16> = new.encode_utf16().collect();
    let prefix = a.iter().zip(&b).take_while(|(a, b)| a == b).count();
    let mut suffix = 0;
    while suffix < a.len() - prefix
        && suffix < b.len() - prefix
        && a[a.len() - 1 - suffix] == b[b.len() - 1 - suffix]
    {
        suffix += 1;
    }
    let aw = tokens(old);
    let bw = tokens(new);
    let counts = |words: &[Token]| {
        let mut c: HashMap<String, usize> = HashMap::new();
        for w in words.iter().filter(|w| !w.literal) {
            *c.entry(w.text.to_lowercase()).or_default() += 1;
        }
        c
    };
    let ac = counts(&aw);
    let bc = counts(&bw);
    let mut kept = HashMap::new();
    for (pos, selected) in choices {
        if let Some(w) = aw.iter().find(|w| w.start == *pos && !w.literal) {
            if ac.get(&w.text.to_lowercase()) != bc.get(&w.text.to_lowercase()) {
                continue;
            }
            let new_pos = if w.end <= prefix {
                Some(*pos)
            } else if w.start >= a.len() - suffix {
                pos.checked_add_signed(b.len() as isize - a.len() as isize)
            } else {
                None
            };
            if let Some(p) = new_pos {
                if bw.iter().any(|v| {
                    v.start == p
                        && !v.literal
                        && v.text == w.text
                        && v.end - v.start == w.end - w.start
                }) {
                    kept.insert(p, selected.clone());
                }
            }
        }
    }
    kept
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct Session {
    pub roman: String,
    pub context: Vec<String>,
    pub selection: usize,
    pub mode: u8,
    #[serde(default)]
    pub code_before_token: bool,
    #[serde(default)]
    pub sentence_has_nepali: bool,
}
impl Session {
    fn parts(&self) -> Option<(String, String, String)> {
        if self.code_before_token || self.roman.contains(':') {
            return None;
        }
        static RE: OnceLock<Regex> = OnceLock::new();
        let re =
            RE.get_or_init(|| Regex::new(r#"^([("'\[]*)([A-Za-z]+)([.,!?;:)'\]]*)$"#).unwrap());
        let c = re.captures(&self.roman)?;
        let word = &c[2];
        if word.chars().next().is_some_and(|c| c.is_lowercase())
            && word.chars().skip(1).any(|c| c.is_uppercase())
        {
            return None;
        }
        Some((c[1].into(), word.into(), c[3].into()))
    }
    fn terminal(suffix: &str, word: &str) -> Option<usize> {
        if ABBREVIATIONS.contains(&word.to_lowercase().as_str()) {
            return None;
        }
        let chars: Vec<(usize, char)> = suffix.char_indices().collect();
        chars
            .iter()
            .enumerate()
            .find(|(i, (_, c))| {
                *c == '.'
                    && (*i == 0 || chars[*i - 1].1 != '.')
                    && chars[*i + 1..].iter().all(|(_, c)| ")]}'\"".contains(*c))
            })
            .map(|(_, v)| v.0)
    }
    pub fn candidates(&self) -> Vec<String> {
        if self.roman.is_empty() {
            return vec![];
        }
        let Some((prefix, word, suffix)) = self.parts() else {
            return vec![self.roman.clone()];
        };
        let mut preceding = if prefix.is_empty() {
            self.context.clone()
        } else {
            vec![]
        };
        preceding.push(word.clone());
        let Some(choice) = context(&preceding.join(" "), self.mode).pop() else {
            return vec![self.roman.clone()];
        };
        let alternatives = contextual_candidates(&choice);
        let mut out = Vec::new();
        for (i, value) in alternatives.iter().enumerate() {
            let mut ending = suffix.clone();
            if !(value == &word && i != 0) && (self.sentence_has_nepali || native(value)) {
                if let Some(at) = Self::terminal(&ending, &word) {
                    ending.replace_range(at..at + 1, "।");
                }
            }
            out.push(prefix.clone() + value + &ending);
        }
        out.push(self.roman.clone());
        unique(out)
    }
    pub fn marked(&self) -> String {
        let options = self.candidates();
        options
            .get(self.selection.min(options.len().saturating_sub(1)))
            .cloned()
            .unwrap_or_default()
    }
    pub fn append(&mut self, text: &str) -> bool {
        if self.mode == 1 || text.is_empty() || !text.chars().all(|c| ('!'..='~').contains(&c)) {
            return false;
        }
        self.roman.push_str(text);
        self.selection = 0;
        true
    }
    pub fn backspace(&mut self) -> bool {
        if self.roman.is_empty() {
            return false;
        }
        let last = self.roman.grapheme_indices(true).next_back().unwrap().0;
        self.roman.truncate(last);
        self.selection = 0;
        true
    }
    pub fn cycle(&mut self, delta: i64) {
        let n = self.candidates().len();
        if n > 0 {
            self.selection =
                (self.selection as i64 + delta.rem_euclid(n as i64)).rem_euclid(n as i64) as usize;
        }
    }
    pub fn select(&mut self, value: &str) -> bool {
        if let Some(i) = self.candidates().iter().position(|s| s == value) {
            self.selection = i;
            true
        } else {
            false
        }
    }
    pub fn reset(&mut self) {
        self.roman.clear();
        self.context.clear();
        self.selection = 0;
        self.code_before_token = false;
        self.sentence_has_nepali = false;
    }
    pub fn commit(&mut self, keep_context: bool, keep_literal_state: bool) -> Option<String> {
        if self.roman.is_empty() {
            return None;
        }
        let result = self.marked();
        let code = self.roman.chars().fold(self.code_before_token, |state, c| {
            if c == '`' {
                !state
            } else {
                state
            }
        });
        if let Some((prefix, word, suffix)) = self.parts().filter(|_| keep_context) {
            if !prefix.is_empty() {
                self.context.clear();
            }
            if suffix.is_empty() {
                self.context.push(word.clone());
                if self.context.len() > 4 {
                    self.context.remove(0);
                }
            } else {
                self.context.clear();
            }
            let terminal = suffix.contains('!')
                || suffix.contains('?')
                || Self::terminal(&suffix, &word).is_some();
            self.sentence_has_nepali = !terminal && (self.sentence_has_nepali || native(&result));
        } else {
            self.context.clear();
            self.sentence_has_nepali = false;
        }
        self.roman.clear();
        self.selection = 0;
        self.code_before_token = keep_literal_state && code;
        Some(result)
    }
    pub fn cancel(&mut self) -> Option<String> {
        if self.roman.is_empty() {
            return None;
        }
        let result = self.roman.clone();
        self.reset();
        Some(result)
    }
}
