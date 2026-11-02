package app.neptype.keyboard.core;

import java.util.Collections;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.List;

/** Suggestion-only port of the Swift phonetic fallback for lowercase ASCII words.
 * This is a deterministic transliteration rule, not evidence of language or correctness.
 */
public final class PhoneticCandidates {
    private PhoneticCandidates() { }
    private static final Map<String, String> CONSONANTS;
    private static final Map<String, String[]> VOWELS;
    static {
        Map<String, String> c = new HashMap<>();
        String[][] consonants = {
            {"ksh","क्ष"},{"chh","छ"},{"gy","ज्ञ"},{"jn","ज्ञ"},{"kh","ख"},{"gh","घ"},
            {"ch","च"},{"jh","झ"},{"th","थ"},{"dh","ध"},{"ph","फ"},{"bh","भ"},
            {"sh","श"},{"ng","ङ"},{"ny","ञ"},{"k","क"},{"g","ग"},{"c","च"},
            {"j","ज"},{"t","त"},{"d","द"},{"n","न"},{"p","प"},{"b","ब"},
            {"m","म"},{"y","य"},{"r","र"},{"l","ल"},{"w","व"},{"v","व"},
            {"s","स"},{"h","ह"},{"f","फ"},{"q","क"},{"x","क्स"},{"z","ज"}
        };
        for (String[] row : consonants) c.put(row[0], row[1]);
        CONSONANTS = Collections.unmodifiableMap(c);
        Map<String, String[]> v = new HashMap<>();
        String[][] vowels = {
            {"aa","आ","ा"},{"ai","ऐ","ै"},{"au","औ","ौ"},
            {"ee","ई","ी"},{"ii","ई","ी"},{"oo","ऊ","ू"},{"uu","ऊ","ू"},
            {"a","अ",""},{"i","इ","ि"},{"u","उ","ु"},{"e","ए","े"},{"o","ओ","ो"}
        };
        for (String[] row : vowels) v.put(row[0], new String[]{row[1], row[2]});
        VOWELS = Collections.unmodifiableMap(v);
    }
    private static <T> String match(Map<String, T> table, String input, int start) {
        for (int length = Math.min(3, input.length() - start); length >= 1; --length) {
            String key = input.substring(start, start + length);
            if (table.containsKey(key)) return key;
        }
        return null;
    }
    /** Empty means no fallback; caller must keep the original and require explicit selection. */
    public static String suggest(String input) {
        if (input == null || input.isEmpty() || input.length() > 128 || !input.matches("[a-z]+")) return "";
        String source = input.toLowerCase(Locale.ROOT);
        StringBuilder output = new StringBuilder();
        for (int i = 0; i < source.length();) {
            String consonant = match(CONSONANTS, source, i);
            if (consonant != null) {
                output.append(CONSONANTS.get(consonant)); i += consonant.length();
                String vowel = match(VOWELS, source, i);
                if (vowel != null) { output.append(VOWELS.get(vowel)[1]); i += vowel.length(); }
                else if (i < source.length() && match(CONSONANTS, source, i) != null) output.append("्");
            } else {
                String vowel = match(VOWELS, source, i);
                if (vowel != null) { output.append(VOWELS.get(vowel)[0]); i += vowel.length(); }
                else output.append(source.charAt(i++));
            }
        }
        return output.toString();
    }
    /** Only fill an empty index result; the host must still require explicit choice. */
    public static String lastResort(String input, List<String> indexed) {
        if (input == null || input.length() < 3 || indexed == null || !indexed.isEmpty()) return "";
        String value = suggest(input);
        return CandidateMerger.safe(value) ? value : "";
    }
}
