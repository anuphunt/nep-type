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
    private static final int MAX_LINE = 16384;

    public SortedCandidateIndex(FileChannel channel, long offset, long length) {
        if (offset < 0 || length < 0) throw new IllegalArgumentException("Invalid segment");
        this.channel = channel; this.offset = offset; this.length = length;
    }
    private int readByte(long position) throws IOException {
        if (position < 0 || position >= length) return -1;
        ByteBuffer b = ByteBuffer.allocate(1);
        int n = channel.read(b, offset + position);
        return n == 1 ? b.get(0) & 255 : -1;
    }
    private long lineStart(long position) throws IOException {
        long p = Math.min(position, length);
        int count = 0;
        while (p > 0 && readByte(p - 1) != '\n') {
            --p;
            if (++count > MAX_LINE) throw new IOException("Index line exceeds limit");
        }
        return p;
    }
    private Line readLine(long start) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        long p = start;
        while (p < length) {
            int ch = readByte(p++);
            if (ch < 0) throw new IOException("Truncated index");
            if (ch == '\n') break;
            if (bytes.size() >= MAX_LINE) throw new IOException("Index line exceeds limit");
            if (ch != '\r') bytes.write(ch);
        }
        return new Line(new String(bytes.toByteArray(), StandardCharsets.UTF_8), p);
    }
    private static final class Line {
        final String text; final long next;
        Line(String text, long next) { this.text = text; this.next = next; }
        String key() { int tab = text.indexOf('\t'); return tab < 0 ? "" : text.substring(0, tab); }
    }
    /** Empty for unrecognized/unsafe input; no automatic conversion or frequency claim. */
    public List<String> lookup(String raw, int limit) throws IOException {
        if (raw == null || limit <= 0 || raw.length() > 128 || !raw.matches("[A-Za-z]+")) return Collections.emptyList();
        String wanted = raw.toLowerCase(Locale.ROOT);
        long lo = 0, hi = length;
        while (lo < hi) {
            long start = lineStart(lo + (hi - lo) / 2);
            Line line = readLine(start);
            if (line.key().compareTo(wanted) < 0) lo = line.next;
            else hi = start;
        }
        List<String> results = new ArrayList<>();
        while (lo < length && results.size() < limit) {
            Line line = readLine(lo);
            if (!wanted.equals(line.key())) break;
            int tab = line.text.indexOf('\t');
            if (tab >= 0) {
                for (String value : line.text.substring(tab + 1).split("\t")) {
                    if (!value.isEmpty() && !results.contains(value)) results.add(value);
                    if (results.size() == limit) break;
                }
            }
            lo = line.next;
        }
        return results;
    }
}
