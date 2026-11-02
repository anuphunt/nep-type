package app.neptype.keyboard.core;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/** Bounded lookup in an uncompressed, byte-sorted UTF-8 roman<TAB>candidate TSV segment. */
public final class SortedCandidateIndex {
    private final FileChannel channel;
    private final long offset, length;
    private static final int MAX_LINE = 4096;
    private static final int MAX_CANDIDATES = 64;
    private static final int MAX_SCALARS = 60;

    public SortedCandidateIndex(FileChannel channel, long offset, long length) {
        if (offset < 0 || length < 0 || offset > Long.MAX_VALUE - length) throw new IllegalArgumentException("Invalid segment");
        this.channel = channel; this.offset = offset; this.length = length;
    }
    // Cache belongs to one lookup, so concurrent lookups never share mutable
    // buffer state. Read only within the APK asset segment; positional reads
    // must not disturb a shared channel's position.
    private final class Reader {
        private final ByteBuffer buffer = ByteBuffer.allocate(4096);
        private long base = -1;
        private int available;
        int readByte(long position) throws IOException {
            if (position < 0 || position >= length) return -1;
            if (base < 0 || position < base || position >= base + available) {
                base = (position / buffer.capacity()) * buffer.capacity();
                buffer.clear();
                buffer.limit((int)Math.min(buffer.capacity(), length - base));
                available = 0;
                while (buffer.hasRemaining()) {
                    int count = channel.read(buffer, offset + base + available);
                    if (count <= 0) break;
                    available += count;
                }
                if (available == 0 || position >= base + available) throw new IOException("Truncated index");
            }
            return buffer.get((int)(position - base)) & 255;
        }
    }
    private long lineStart(Reader reader, long position) throws IOException {
        long p = Math.min(position, length);
        int count = 0;
        while (p > 0 && reader.readByte(p - 1) != '\n') {
            --p;
            if (++count > MAX_LINE) throw new IOException("Index line exceeds limit");
        }
        return p;
    }
    private Line readLine(Reader reader, long start) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        long p = start;
        while (p < length) {
            int ch = reader.readByte(p++);
            if (ch < 0) throw new IOException("Truncated index");
            if (ch == '\n') break;
            if (p - start > MAX_LINE) throw new IOException("Index line exceeds limit");
            if (ch != '\r') bytes.write(ch);
        }
        return new Line(new String(bytes.toByteArray(), StandardCharsets.UTF_8), p);
    }
    private static final class Line {
        final String text; final long next;
        Line(String text, long next) { this.text = text; this.next = next; }
        String key() { int tab = text.indexOf('\t'); return tab < 0 ? "" : text.substring(0, tab); }
    }
    // Match the shared Swift index contract. Reject the entire matching row
    // rather than showing a seemingly safe prefix of a corrupt row.
    private static boolean validCandidate(String value) {
        if (value.isEmpty() || value.codePointCount(0, value.length()) > MAX_SCALARS) return false;
        for (int i = 0; i < value.length();) {
            int scalar = value.codePointAt(i);
            if (!((scalar >= 0x0900 && scalar <= 0x097f) || scalar == 0x200c || scalar == 0x200d)) return false;
            i += Character.charCount(scalar);
        }
        return true;
    }
    /** Empty for unrecognized/unsafe input; no automatic conversion or frequency claim. */
    public List<String> lookup(String raw, int limit) throws IOException {
        if (raw == null || limit <= 0 || raw.length() > 128 || !raw.matches("[A-Za-z]+")) return Collections.emptyList();
        String wanted = raw.toLowerCase(Locale.ROOT);
        Reader reader = new Reader();
        long lo = 0, hi = length;
        while (lo < hi) {
            long start = lineStart(reader, lo + (hi - lo) / 2);
            Line line = readLine(reader, start);
            if (line.key().compareTo(wanted) < 0) lo = line.next;
            else hi = start;
        }
        List<String> results = new ArrayList<>();
        while (lo < length) {
            Line line = readLine(reader, lo);
            if (!wanted.equals(line.key())) break;
            int tab = line.text.indexOf('\t');
            if (tab < 0) return Collections.emptyList();
            String[] values = line.text.substring(tab + 1).split("\t", -1);
            if (values.length > MAX_CANDIDATES) return Collections.emptyList();
            for (String value : values) if (!validCandidate(value)) return Collections.emptyList();
            for (String value : values) if (results.size() < limit && !results.contains(value)) results.add(value);
            lo = line.next;
        }
        return results;
    }
}
