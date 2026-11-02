package app.neptype.keyboard.core;

import java.util.LinkedHashMap;
import java.util.Map;

/** Local opt-in app modes only. Does not handle typed text, URLs or field contents. */
public final class PersistentLanguagePreferences {
    public interface Store {
        boolean enabled();
        String snapshot();
        /** Set enabled and optionally replace or remove the whole snapshot atomically. */
        boolean commit(boolean enabled, String snapshot);
    }
    private static final Object LOCK = new Object();
    private static final int LIMIT = 64, MAX_SIZE = 17000;
    private PersistentLanguagePreferences() { }
    private static boolean validApp(String app) {
        return app != null && app.length() <= 255 && app.matches("[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+");
    }
    /** Reject the complete snapshot on any error; never partly apply corrupt data. */
    private static LinkedHashMap<String, Boolean> decode(String snapshot) {
        LinkedHashMap<String, Boolean> out = new LinkedHashMap<>();
        if (snapshot == null || snapshot.isEmpty()) return out;
        if (snapshot.length() > MAX_SIZE || !snapshot.startsWith("v1\n") || !snapshot.endsWith("\n")) return null;
        String[] lines = snapshot.split("\n", -1);
        for (int i = 1; i < lines.length - 1; i++) {
            String[] fields = lines[i].split("\t", -1);
            if (fields.length != 2 || !validApp(fields[0]) || !(fields[1].equals("N") || fields[1].equals("E")) || out.containsKey(fields[0]) || out.size() == LIMIT) return null;
            out.put(fields[0], fields[1].equals("N"));
        }
        return out;
    }
    private static String encode(LinkedHashMap<String, Boolean> entries) {
        StringBuilder out = new StringBuilder("v1\n");
        for (Map.Entry<String, Boolean> e : entries.entrySet()) out.append(e.getKey()).append('\t').append(e.getValue() ? 'N' : 'E').append('\n');
        return out.toString();
    }
    public static boolean isEnabled(Store store) {
        synchronized (LOCK) {
            try { return store.enabled(); } catch (RuntimeException ex) { return false; }
        }
    }
    /** Explicit setting: disabling also removes stored app identifiers. */
    public static boolean setEnabled(Store store, boolean enabled) {
        synchronized (LOCK) {
            try { return store.commit(enabled, null); }
            catch (RuntimeException ex) { return false; }
        }
    }
    /** Returns null on no choice, corrupt data, disabled storage or invalid app. */
    public static Boolean lookup(Store store, String app) {
        synchronized (LOCK) {
            try {
                if (!validApp(app) || !store.enabled()) return null;
                LinkedHashMap<String, Boolean> entries = decode(store.snapshot());
                return entries == null ? null : entries.get(app);
            } catch (RuntimeException ex) { return null; }
        }
    }
    /** Called only for explicit non-sensitive mode switches. Writes one atomic snapshot. */
    public static boolean remember(Store store, String app, boolean nepali, boolean literalOnly) {
        synchronized (LOCK) {
            try {
                if (literalOnly || !validApp(app) || !store.enabled()) return true;
                LinkedHashMap<String, Boolean> entries = decode(store.snapshot());
                if (entries == null) entries = new LinkedHashMap<>();
                entries.remove(app); entries.put(app, nepali);
                if (entries.size() > LIMIT) entries.remove(entries.keySet().iterator().next());
                return store.commit(true, encode(entries));
            } catch (RuntimeException ex) { return false; }
        }
    }
}
