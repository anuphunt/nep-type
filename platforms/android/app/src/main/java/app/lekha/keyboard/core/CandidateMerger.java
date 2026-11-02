package app.lekha.keyboard.core;

import java.util.List;

/** Merge sources in caller priority order without moving or duplicating entries. */
public final class CandidateMerger {
    private CandidateMerger() { }
    /** Reject malformed, oversized or control-bearing index data before UI/commit. */
    public static boolean safe(String value) {
        if (value == null || value.isEmpty() || value.length() > 256) return false;
        for (int offset = 0; offset < value.length();) {
            int cp = value.codePointAt(offset);
            int kind = Character.getType(cp);
            if (kind == Character.CONTROL || kind == Character.SURROGATE ||
                kind == Character.LINE_SEPARATOR || kind == Character.PARAGRAPH_SEPARATOR ||
                (kind == Character.FORMAT && cp != 0x200c && cp != 0x200d)) return false;
            offset += Character.charCount(cp);
        }
        return true;
    }
    public static void add(List<String> output, List<String> source, int limit) {
        for (String value : source) {
            if (output.size() >= limit) break;
            if (safe(value) && !output.contains(value)) output.add(value);
        }
    }
}
