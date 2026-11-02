package app.lekha.keyboard.core;

import java.util.LinkedHashMap;
import java.util.Map;

/** In-memory manual choices only. Never stores surrounding text or field content. */
public final class LanguagePreferences {
    private static final int MAX_APPS = 64;
    private final LinkedHashMap<String, Boolean> choices = new LinkedHashMap<String, Boolean>(16, .75f, true) {
        @Override protected boolean removeEldestEntry(Map.Entry<String, Boolean> oldest) { return size() > MAX_APPS; }
    };
    private static boolean valid(String app) { return app != null && !app.isEmpty() && app.length() <= 255; }
    public Boolean explicitChoice(String app) { return valid(app) ? choices.get(app) : null; }
    public boolean languageFor(String app) { Boolean value = explicitChoice(app); return value == null || value; }
    public void remember(String app, boolean nepali, boolean literalOnly) {
        if (!literalOnly && valid(app)) choices.put(app, nepali);
    }
    public int size() { return choices.size(); }
}
