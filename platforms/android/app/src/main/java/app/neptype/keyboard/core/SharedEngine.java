package app.neptype.keyboard.core;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
/** JNI transport only; the shared Rust engine owns all language logic. */
public final class SharedEngine implements AutoCloseable {
    public static final int NEPALI = 0, ENGLISH = 1, ALL_NEPALI = 2;
    static { System.loadLibrary("neptype_jni"); }
    public static native String dictionaryId();
    private long handle;
    public SharedEngine(String directory) {
        if (directory.indexOf('\0') >= 0) throw new IllegalArgumentException("Invalid directory");
        handle = create(directory.getBytes(StandardCharsets.UTF_8));
        if (handle == 0) throw new IllegalStateException("Shared engine or dictionaries unavailable");
    }
    public synchronized List<String> candidates(String roman, int mode) {
        if (handle == 0) throw new IllegalStateException("Engine is closed");
        if (roman.indexOf('\0') >= 0) throw new IllegalArgumentException("Embedded NUL");
        byte[][] values = candidates(handle, roman.getBytes(StandardCharsets.UTF_8), mode);
        if (values == null) throw new IllegalStateException("Shared engine rejected lookup");
        List<String> result = new ArrayList<>();
        for (byte[] value : values) result.add(new String(value, StandardCharsets.UTF_8));
        return result;
    }
    @Override public synchronized void close() { if (handle != 0) { destroy(handle); handle = 0; } }
    private static native long create(byte[] directory);
    private static native byte[][] candidates(long engine, byte[] roman, int mode);
    private static native void destroy(long engine);
}
