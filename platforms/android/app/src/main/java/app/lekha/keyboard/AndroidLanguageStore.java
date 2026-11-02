package app.lekha.keyboard;

import android.content.Context;
import android.content.SharedPreferences;
import app.lekha.keyboard.core.PersistentLanguagePreferences;

/** Private app preferences; Android backup is disabled in the manifest. */
final class AndroidLanguageStore implements PersistentLanguagePreferences.Store {
    private static final String FILE = "lekha_language_private", ENABLED = "remember_apps", SNAPSHOT = "manual_modes_v1";
    private final SharedPreferences prefs;
    AndroidLanguageStore(Context context) { prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE); }
    @Override public boolean enabled() { return prefs.getBoolean(ENABLED, false); }
    @Override public String snapshot() { return prefs.getString(SNAPSHOT, null); }
    @Override public boolean commit(boolean enabled, String snapshot) {
        SharedPreferences.Editor edit = prefs.edit().putBoolean(ENABLED, enabled);
        if (snapshot == null) edit.remove(SNAPSHOT); else edit.putString(SNAPSHOT, snapshot);
        return edit.commit();
    }
}
