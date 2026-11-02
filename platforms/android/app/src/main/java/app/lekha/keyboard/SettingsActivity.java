package app.lekha.keyboard;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Build;
import android.provider.Settings;
import android.view.Gravity;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.Switch;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import app.lekha.keyboard.core.DisplaySettings;
import app.lekha.keyboard.core.PersistentLanguagePreferences;

/** Explicit, user-driven setup. Does not enable or select an input method itself. */
public final class SettingsActivity extends Activity {
    static final String PREFS = "lekha_display";
    static final String CANDIDATE_LIMIT = "candidate_limit";
    private static final int INK = Color.rgb(29, 55, 58);
    private static final int CANVAS = Color.rgb(238, 244, 241);
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(24), dp(32), dp(24), dp(32));
        page.setBackgroundColor(CANVAS);
        scroll.addView(page);
        setContentView(scroll);

        TextView brand = text("लेख  Lekha", 30);
        heading(brand);
        page.addView(brand);
        page.addView(text("Nepali typing, at your pace", 18));
        page.addView(text("EXPERIMENTAL KEYBOARD", 12));
        page.addView(text("Lekha suggests Nepali spellings from local indexes. Roman text stays in place until you choose a suggestion. Review your text before using it.", 16));
        TextView gettingStarted = text("Get started", 21);
        heading(gettingStarted);
        page.addView(gettingStarted);
        page.addView(text("1. Open keyboard settings and enable Lekha yourself.\n\n2. Choose Lekha from the keyboard picker.\n\n3. Type Roman Nepali, preview a suggestion, then tap Use or Keep original.", 16));
        Button systemSettings = new Button(this);
        systemSettings.setText("Open keyboard settings");
        systemSettings.setAllCaps(false);
        systemSettings.setOnClickListener(v -> {
            try { startActivity(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)); }
            catch (ActivityNotFoundException | SecurityException ex) {
                Toast.makeText(this, "Open your device's keyboard settings to enable Lekha.", Toast.LENGTH_LONG).show();
            }
        });
        page.addView(systemSettings);
        Button chooseKeyboard = new Button(this);
        chooseKeyboard.setText("Choose a keyboard");
        chooseKeyboard.setAllCaps(false);
        chooseKeyboard.setOnClickListener(v -> {
            InputMethodManager manager = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
            if (manager != null) manager.showInputMethodPicker();
            else Toast.makeText(this, "Keyboard picker is unavailable on this device.", Toast.LENGTH_LONG).show();
        });
        page.addView(chooseKeyboard);

        TextView preferences = text("Suggestions", 21);
        heading(preferences);
        page.addView(preferences);
        page.addView(text("How many Nepali choices to show alongside your original word. Changes apply when you next open a text field.", 15));
        SharedPreferences settings = getSharedPreferences(PREFS, MODE_PRIVATE);
        int current = DisplaySettings.candidateLimit(settings.getInt(CANDIDATE_LIMIT, DisplaySettings.DEFAULT_LIMIT));
        RadioGroup choices = new RadioGroup(this);
        choices.setOrientation(RadioGroup.HORIZONTAL);
        choices.setContentDescription("Maximum number of Nepali suggestions");
        for (int number = 2; number <= 4; number++) {
            RadioButton option = new RadioButton(this);
            option.setId(number);
            option.setText(String.valueOf(number));
            option.setContentDescription(number + " Nepali suggestions");
            choices.addView(option);
            option.setChecked(number == current);
        }
        choices.setOnCheckedChangeListener((group, id) -> {
            if (id >= 2 && id <= 4) settings.edit().putInt(CANDIDATE_LIMIT, id).apply();
        });
        page.addView(choices);

        TextView appModes = text("Language by app", 21);
        heading(appModes);
        page.addView(appModes);
        page.addView(text("Optionally remember your manual language choice per app between launches. This stores app identifiers and language choices locally, never typed text. Turning it off deletes the saved choices. Protected and literal-only fields do not save a choice.", 15));
        AndroidLanguageStore languageStore = new AndroidLanguageStore(this);
        Switch rememberModes = new Switch(this);
        rememberModes.setText("Remember manual language per app");
        rememberModes.setContentDescription("Remember manual language per app between launches");
        rememberModes.setChecked(PersistentLanguagePreferences.isEnabled(languageStore));
        rememberModes.setOnCheckedChangeListener((button, enabled) -> {
            if (!PersistentLanguagePreferences.setEnabled(languageStore, enabled)) {
                button.setOnCheckedChangeListener(null);
                button.setChecked(PersistentLanguagePreferences.isEnabled(languageStore));
                Toast.makeText(this, "Could not change saved language settings.", Toast.LENGTH_LONG).show();
                // Recreate the settings screen so the listener is restored safely.
                recreate();
            }
        });
        page.addView(rememberModes);

        TextView privacy = text("Offline prototype", 21);
        heading(privacy);
        page.addView(privacy);
        page.addView(text("Suggestions use files on this device. This prototype requests no internet permission. Field and text safety still need testing on Android; use it only for evaluation.", 15));
        page.addView(text("By default, language choices are kept in memory for the current run. Android settings and keyboard names can vary by device.", 15));
    }
    private TextView text(String value, int size) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(INK);
        view.setGravity(Gravity.START);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.bottomMargin = dp(16);
        view.setLayoutParams(params);
        return view;
    }
    private void heading(TextView view) {
        if (Build.VERSION.SDK_INT >= 28) view.setAccessibilityHeading(true);
    }
}
