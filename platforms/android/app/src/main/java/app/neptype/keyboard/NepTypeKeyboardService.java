package app.neptype.keyboard;

import android.content.Context;
import android.content.ClipData;
import android.content.ClipDescription;
import android.content.ClipboardManager;
import android.content.res.AssetFileDescriptor;
import android.graphics.Color;
import android.inputmethodservice.InputMethodService;
import android.os.Handler;
import android.os.Looper;
import android.os.PersistableBundle;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;
import app.neptype.keyboard.core.Composition;
import app.neptype.keyboard.core.DisplaySettings;
import app.neptype.keyboard.core.CandidatePreview;
import app.neptype.keyboard.core.CandidatePages;
import app.neptype.keyboard.core.InputSafety;
import app.neptype.keyboard.core.FeedbackState;
import app.neptype.keyboard.core.LatestLookupScheduler;
import app.neptype.keyboard.core.EditorSessionGuard;
import app.neptype.keyboard.core.RenderActionGuard;
import app.neptype.keyboard.core.RecoveryBuffer;
import app.neptype.keyboard.core.LanguagePreferences;
import app.neptype.keyboard.core.PersistentLanguagePreferences;
import app.neptype.keyboard.core.SharedEngine;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

/** Experimental offline input method: original Roman text is always the default. */
public final class NepTypeKeyboardService extends InputMethodService {
    private volatile SharedEngine sharedEngine;
    private volatile boolean serviceDestroyed;
    private boolean shifted;
    private boolean symbols;
    private boolean literalOnly = true;
    // Session-only output mode; candidate ranking is owned by the shared engine.
    private boolean allNepaliSuggestions;
    private LinearLayout keyboard;
    private final Composition composition = new Composition();
    private final LanguagePreferences languagePreferences = new LanguagePreferences();
    private final FeedbackState feedback = new FeedbackState();
    private final EditorSessionGuard editGuard = new EditorSessionGuard();
    private final RenderActionGuard actionGuard = new RenderActionGuard();
    private final RecoveryBuffer recovery = new RecoveryBuffer();
    private String activePackage;
    private final CandidatePreview preview = new CandidatePreview();
    private final LatestLookupScheduler lookupScheduler = new LatestLookupScheduler();
    private final Handler main = new Handler(Looper.getMainLooper());
    private List<String> suggestions = Collections.emptyList();
    private long generation;
    private int requestedEditorAction = EditorInfo.IME_ACTION_UNSPECIFIED;
    private int candidateDisplayLimit = DisplaySettings.DEFAULT_LIMIT;
    private int candidatePage;
    private static final int INK = Color.rgb(29, 55, 58);
    private static final int CANVAS = Color.rgb(238, 244, 241);

    @Override public View onCreateInputView() {
        keyboard = new LinearLayout(this);
        keyboard.setOrientation(LinearLayout.VERTICAL);
        keyboard.setPadding(8, 8, 8, 8);
        keyboard.setBackgroundColor(CANVAS);
        render();
        return keyboard;
    }
    @Override public void onStartInput(EditorInfo info, boolean restarting) {
        super.onStartInput(info, restarting);
        allNepaliSuggestions = false;
        // Recovery never crosses an editor/session boundary.
        recovery.clear();
        candidateDisplayLimit = DisplaySettings.candidateLimit(getSharedPreferences(SettingsActivity.PREFS, MODE_PRIVATE)
                .getInt(SettingsActivity.CANDIDATE_LIMIT, DisplaySettings.DEFAULT_LIMIT));
        literalOnly = info == null || InputSafety.literalOnly(info.inputType);
        requestedEditorAction = info == null ? EditorInfo.IME_ACTION_UNSPECIFIED :
                InputSafety.editorAction(info.imeOptions, EditorInfo.IME_FLAG_NO_ENTER_ACTION,
                        EditorInfo.IME_MASK_ACTION, EditorInfo.IME_ACTION_NONE,
                        EditorInfo.IME_ACTION_UNSPECIFIED);
        editGuard.start(restarting, composition.active());
        relinquishOwnership();
        feedback.clear();
        if (!editGuard.mayEdit()) feedback.editUncertain();
        activePackage = info == null ? null : info.packageName;
        // Only an explicit opt-in permits disk storage of package identifiers.
        // Literal-only fields neither read nor write per-app choices.
        if (!literalOnly) {
            Boolean currentRun = languagePreferences.explicitChoice(activePackage);
            Boolean saved = currentRun == null ? PersistentLanguagePreferences.lookup(new AndroidLanguageStore(this), activePackage) : currentRun;
            composition.setNepali(saved == null || saved);
        }
        render();
    }
    @Override public void onFinishInput() {
        // Invalidate queued key taps before releasing the old editor state.
        actionGuard.invalidate();
        recovery.clear();
        // Ownership may already have moved to a different editor. Never make
        // a final edit through a connection whose target is no longer proven.
        if (composition.active()) editGuard.ownershipUncertain();
        relinquishOwnership();
        activePackage = null;
        super.onFinishInput();
    }
    @Override public void onDestroy() {
        actionGuard.invalidate(); recovery.clear(); generation++; lookupScheduler.close();
        final SharedEngine closing;
        synchronized (this) { serviceDestroyed = true; closing = sharedEngine; sharedEngine = null; }
        if (closing != null) new Thread(closing::close, "neptype-engine-close").start();
        super.onDestroy();
    }
    @Override public void onUpdateSelection(int oldStart, int oldEnd, int newStart, int newEnd, int candidatesStart, int candidatesEnd) {
        super.onUpdateSelection(oldStart, oldEnd, newStart, newEnd, candidatesStart, candidatesEnd);
        // A cursor/selection moved inside or outside the marked token invalidates
        // our ownership. Preserve the host's text and drop any stale candidate.
        if (composition.active() && InputSafety.selectionLosesOwnership(oldStart, oldEnd,
                newStart, newEnd, candidatesStart, candidatesEnd, composition.text().length())) {
            // Do not edit a marked span after ownership becomes uncertain.
            blockEdits();
            render();
        }
    }

    private void render() {
        // Every button captures this render's generation. A queued tap from a
        // prior composition or editor must never act on the current one.
        actionGuard.invalidate();
        if (keyboard == null) return;
        keyboard.removeAllViews();
        LinearLayout candidates = new LinearLayout(this);
        String pending = preview.current(generation, composition.text(), composition.active(), suggestions);
        if (composition.active()) {
            final long shownGeneration = generation;
            final String shownToken = composition.text();
            Button original = add(candidates, shownToken, "Keep original " + shownToken,
                    () -> keepOriginal(shownGeneration, shownToken), 1f);
            original.setLayoutParams(new LinearLayout.LayoutParams(dp(112), dp(48)));
            final int shownPage = candidatePage;
            int start = CandidatePages.offset(suggestions.size(), candidateDisplayLimit, shownPage);
            if (start >= 0) {
                for (int i = start; i < Math.min(start + candidateDisplayLimit, suggestions.size()); i++) {
                    String candidate = suggestions.get(i);
                    boolean selected = candidate.equals(pending);
                    Button choice = add(candidates, candidate,
                            (selected ? "Selected preview " : "Preview ") + candidate
                                    + ", suggestion " + (i + 1) + " of " + suggestions.size(),
                            () -> previewCandidate(candidate, shownGeneration, shownToken, shownPage), 1f);
                    choice.setLayoutParams(new LinearLayout.LayoutParams(dp(112), dp(48)));
                    choice.setSelected(selected);
                }
            }
        } else {
            TextView title = new TextView(this);
            title.setText(!editGuard.mayEdit() ? "Typing paused · refocus field" : (literalOnly ? "Literal typing in this field" : (composition.isNepali() ? (allNepaliSuggestions ? "All Nepali suggestions" : "Nepali · tap a suggestion to convert") : "English · literal typing")));
            title.setTextColor(INK); title.setGravity(Gravity.CENTER); title.setTextSize(14);
            candidates.addView(title, new LinearLayout.LayoutParams(0, dp(40), 1f));
            if (!literalOnly && composition.isNepali()) {
                Button all = add(candidates, allNepaliSuggestions ? "All ✓" : "All",
                        "All Nepali suggestions " + (allNepaliSuggestions ? "on" : "off")
                                + "; tap to change suggestion mode", () -> {
                            if (!editGuard.mayEdit() || literalOnly || composition.active() || !composition.isNepali()) return;
                            allNepaliSuggestions = !allNepaliSuggestions; generation++; render();
                        }, 1f);
                all.setEnabled(editGuard.mayEdit());
            }
        }
        if (composition.active()) {
            // Keep touch targets usable on narrow screens instead of squeezing
            // the original and up to four suggestions into the screen width.
            HorizontalScrollView candidateScroll = new HorizontalScrollView(this);
            candidateScroll.setFillViewport(false);
            candidateScroll.setHorizontalScrollBarEnabled(true);
            candidateScroll.setContentDescription("Suggestions; scroll horizontally for more choices");
            candidateScroll.addView(candidates);
            keyboard.addView(candidateScroll, new LinearLayout.LayoutParams(-1, dp(48)));
        } else {
            keyboard.addView(candidates);
        }
        int pages = CandidatePages.pageCount(suggestions.size(), candidateDisplayLimit);
        if (composition.active() && pages > 1) {
            final long shownGeneration = generation;
            final String shownToken = composition.text();
            final int shownPage = candidatePage;
            LinearLayout navigation = new LinearLayout(this);
            Button previous = add(navigation, "Previous", "Previous candidate page", () ->
                    changeCandidatePage(shownGeneration, shownToken, shownPage, shownPage - 1), 1f);
            previous.setEnabled(shownPage > 0);
            TextView pageLabel = new TextView(this);
            pageLabel.setText("Candidates " + (shownPage + 1) + " of " + pages);
            pageLabel.setTextColor(INK); pageLabel.setGravity(Gravity.CENTER);
            pageLabel.setContentDescription("Candidate page " + (shownPage + 1) + " of " + pages);
            navigation.addView(pageLabel, new LinearLayout.LayoutParams(0, dp(48), 2f));
            Button next = add(navigation, "Next", "Next candidate page", () ->
                    changeCandidatePage(shownGeneration, shownToken, shownPage, shownPage + 1), 1f);
            next.setEnabled(shownPage + 1 < pages);
            keyboard.addView(navigation);
        }
        if (feedback.notice() != FeedbackState.Notice.NONE) {
            LinearLayout noticeRow = new LinearLayout(this);
            TextView notice = new TextView(this);
            notice.setText(feedback.message());
            notice.setTextColor(INK);
            notice.setGravity(Gravity.CENTER);
            notice.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
            noticeRow.addView(notice, new LinearLayout.LayoutParams(0, -2, 4f));
            add(noticeRow, "Dismiss", "Dismiss typing notice", () -> { feedback.clear(); render(); }, 1f);
            keyboard.addView(noticeRow);
        }
        if (!literalOnly && !editGuard.mayEdit() && recovery.available()) {
            LinearLayout recoveryRow = new LinearLayout(this);
            add(recoveryRow, "Copy retained Roman text", "Copy the retained Roman token to the clipboard; this does not edit the current field", this::copyRecovery, 1f);
            keyboard.addView(recoveryRow);
        }
        if (pending != null) {
            final long shownGeneration = generation;
            final String shownToken = composition.text();
            LinearLayout actions = new LinearLayout(this);
            add(actions, "Use " + pending,
                    "Use " + pending + "; replace the current Roman word",
                    () -> commitPreview(shownGeneration, shownToken, pending), 1f);
            add(actions, "Cancel choice", "Cancel preview and keep the Roman word",
                    () -> cancelPreview(shownGeneration, shownToken, pending), 1f);
            keyboard.addView(actions);
        }
        String[] rows = symbols ? new String[]{"1234567890", "@#$%&*+-/", "()[]_:=?!"} : new String[]{"qwertyuiop", "asdfghjkl", "zxcvbnm"};
        for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
            String keys = rows[rowIndex];
            LinearLayout row = new LinearLayout(this);
            if (!symbols && rowIndex == 2) add(row, shifted ? "⇧ On" : "⇧", shifted ? "Shift on; tap to turn off" : "Shift off; tap to turn on", () -> { shifted = !shifted; render(); }, 1.3f);
            for (char key : keys.toCharArray()) {
                String letter = String.valueOf(key);
                String displayed = shifted && !symbols ? letter.toUpperCase(Locale.ROOT) : letter;
                if (symbols) add(row, displayed, displayed, () -> insert(displayed), 1f);
                else add(row, displayed, displayed, () -> type(displayed), 1f);
            }
            if (rowIndex == 2) add(row, "⌫", "Delete", this::delete, 1.3f);
            keyboard.addView(row);
        }
        LinearLayout bottom = new LinearLayout(this);
        add(bottom, "🌐", "Switch keyboard", () -> { if (editGuard.mayEdit() && !finishOriginal()) return; if (android.os.Build.VERSION.SDK_INT >= 28) switchToNextInputMethod(false); else ((InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE)).showInputMethodPicker(); }, 1.2f);
        Button language = add(bottom, composition.isNepali() ? "ने / EN" : "EN / ने", literalOnly ? "Language switching unavailable in this literal-only field" : (composition.isNepali() ? "Nepali mode; switch to English" : "English mode; switch to Nepali"), this::toggleLanguage, 1.6f);
        language.setEnabled(!literalOnly && editGuard.mayEdit());
        add(bottom, symbols ? "ABC" : "?123", symbols ? "Show letters" : "Show numbers and symbols", () -> { symbols = !symbols; render(); }, 1.3f);
        add(bottom, ",", "Comma", () -> insert(","), 1f);
        add(bottom, "space", "Space", () -> insert(" "), 4f);
        add(bottom, ".", "Period", () -> insert("."), 1f);
        add(bottom, "↵", "Return", this::returnKey, 1.3f);
        keyboard.addView(bottom);
    }
    private void type(String value) {
        if (!readyToEdit()) return;
        InputConnection c = getCurrentInputConnection();
        if (c == null) { blockEdits(); render(); return; }
        if (!literalOnly && composition.accepts(value)) {
            String proposed = composition.text() + value;
            if (c.setComposingText(proposed, 1)) {
                feedback.confirmedEdit();
                composition.append(value);
                requestCandidates();
            } else {
                // The host rejected the edit (or its outcome is uncertain).
                // Do not retry and risk duplicate text; relinquish ownership.
                blockEdits();
            }
        } else if (finishOriginal()) confirmEdit(c.commitText(value, 1));
        if (shifted) shifted = false;
        render();
    }
    private void requestCandidates() {
        final String source = composition.text();
        final boolean useAllNepali = allNepaliSuggestions;
        final long request = ++generation;
        preview.clear();
        candidatePage = 0;
        suggestions = Collections.emptyList();
        boolean accepted = lookupScheduler.submit(() -> {
            List<String> values;
            boolean failed = false;
            try { values = obtainSharedEngine().candidates(source, useAllNepali ? SharedEngine.ALL_NEPALI : SharedEngine.NEPALI); }
            catch (Exception | LinkageError error) { values = Collections.emptyList(); failed = true; }
            final List<String> found = new ArrayList<>(values);
            found.remove(source); // The native UI offers the original separately.
            final boolean allUnavailable = failed;
            main.post(() -> {
                if (!InputSafety.acceptsLookup(request, generation, source, composition.text(), composition.active())) return;
                if (allUnavailable) feedback.dictionariesUnavailable();
                suggestions = found; candidatePage = 0; render();
            });
        });
        if (!accepted) feedback.dictionariesUnavailable();
    }
    private SharedEngine obtainSharedEngine() throws IOException {
        if (serviceDestroyed) throw new IOException("Keyboard session closed");
        SharedEngine current = sharedEngine;
        if (current != null) return current;
        SharedEngine created = new SharedEngine("");
        synchronized (this) {
            if (serviceDestroyed) { created.close(); throw new IOException("Keyboard session closed"); }
            sharedEngine = created;
        }
        return created;
    }
    private void changeCandidatePage(long shownGeneration, String shownToken, int shownPage, int requestedPage) {
        if (!CandidatePages.acceptsChange(shownGeneration, generation, shownToken, composition.text(),
                composition.active(), shownPage, candidatePage, requestedPage, suggestions.size(), candidateDisplayLimit)) return;
        // Never allow a previously selected, now-hidden candidate to be used.
        preview.clear();
        candidatePage = requestedPage;
        render();
    }
    private void keepOriginal(long shownGeneration, String shownToken) {
        if (!InputSafety.acceptsCandidate(shownGeneration, generation, shownToken, composition.text(),
                composition.active(), true)) return;
        finishOriginal(); render();
    }
    private void previewCandidate(String candidate, long shownGeneration, String shownToken, int shownPage) {
        if (literalOnly || !CandidatePages.displayed(suggestions, candidateDisplayLimit, shownPage, candidatePage, candidate)) return;
        if (preview.select(candidate, shownGeneration, generation, shownToken, composition.text(),
                composition.active(), suggestions)) render();
    }
    private boolean previewStillShown(long shownGeneration, String shownToken, String shownValue) {
        return preview.matchesDisplay(shownGeneration, shownToken, shownValue,
                generation, composition.text(), composition.active(), suggestions);
    }
    private void cancelPreview(long shownGeneration, String shownToken, String shownValue) {
        if (!previewStillShown(shownGeneration, shownToken, shownValue)) return;
        preview.clear(); render();
    }
    private void commitPreview(long shownGeneration, String shownToken, String shownValue) {
        if (!readyToEdit()) return;
        if (!previewStillShown(shownGeneration, shownToken, shownValue)) return;
        InputConnection c = getCurrentInputConnection();
        String candidate = preview.current(generation, composition.text(), composition.active(), suggestions);
        if (literalOnly || candidate == null) return;
        if (c == null) { blockEdits(); render(); return; }
        // Success or failure both invalidate this token. A false result has an
        // uncertain host outcome, so never retry the same replacement.
        boolean applied = c.commitText(candidate, 1);
        relinquishOwnership(); confirmEdit(applied); render();
    }
    private void relinquishOwnership() {
        composition.takeOriginal(); preview.clear(); suggestions = Collections.emptyList(); candidatePage = 0; generation++;
        lookupScheduler.clearPending();
    }
    private boolean finishOriginal() {
        if (!readyToEdit()) return false;
        if (composition.active()) {
            InputConnection c = getCurrentInputConnection();
            if (c == null || !c.finishComposingText()) {
                // Avoid replay after an uncertain host response.
                blockEdits(); render(); return false;
            }
        }
        relinquishOwnership();
        return true;
    }
    private void toggleLanguage() {
        if (literalOnly || !finishOriginal()) return;
        allNepaliSuggestions = false;
        composition.setNepali(!composition.isNepali());
        languagePreferences.remember(activePackage, composition.isNepali(), false);
        if (!PersistentLanguagePreferences.remember(new AndroidLanguageStore(this), activePackage, composition.isNepali(), false)) {
            android.widget.Toast.makeText(this, "Could not save language choice; it remains in memory for this run.", android.widget.Toast.LENGTH_LONG).show();
        }
        render();
    }
    private void insert(String value) {
        if (!readyToEdit() || !finishOriginal()) return;
        InputConnection c = getCurrentInputConnection();
        confirmEdit(c != null && c.commitText(value, 1));
        render();
    }
    private void returnKey() {
        if (!readyToEdit() || !finishOriginal()) return;
        InputConnection c = getCurrentInputConnection();
        if (c == null) { blockEdits(); render(); return; }
        if (requestedEditorAction == EditorInfo.IME_ACTION_UNSPECIFIED) confirmEdit(c.commitText("\n", 1));
        else confirmEdit(c.performEditorAction(requestedEditorAction));
        render();
    }
    private void delete() {
        if (!readyToEdit()) return;
        InputConnection c = getCurrentInputConnection();
        if (c == null) { blockEdits(); render(); return; }
        if (composition.active()) {
            String current = composition.text();
            String shorter = current.substring(0, current.length() - 1); // composing input is ASCII only
            if (!c.setComposingText(shorter, 1)) { blockEdits(); render(); return; }
            feedback.confirmedEdit();
            composition.backspace();
            if (composition.active()) requestCandidates(); else { confirmEdit(c.finishComposingText()); suggestions = Collections.emptyList(); generation++; }
        } else {
            CharSequence selected = c.getSelectedText(0);
            if (selected != null && selected.length() > 0) confirmEdit(c.commitText("", 1));
            else confirmEdit(c.deleteSurroundingTextInCodePoints(1, 0));
        }
        render();
    }
    private Button add(LinearLayout row, String label, String description, Runnable action, float weight) {
        Button button = new Button(this); button.setText(label); button.setTextColor(INK); button.setAllCaps(false);
        button.setSingleLine(true); button.setEllipsize(TextUtils.TruncateAt.END);
        final long capturedRender = actionGuard.current();
        button.setContentDescription(description); button.setOnClickListener(view -> {
            if (actionGuard.accepts(capturedRender)) action.run();
        });
        row.addView(button, new LinearLayout.LayoutParams(0, dp(48), weight));
        return button;
    }
    private boolean readyToEdit() {
        if (editGuard.mayEdit()) return true;
        feedback.editUncertain(); render(); return false;
    }
    private void blockEdits() {
        // Capture before clearing local ownership; never write to an uncertain host.
        recovery.remember(composition.text(), literalOnly);
        relinquishOwnership();
        editGuard.ownershipUncertain();
        feedback.editUncertain();
    }

    private void copyRecovery() {
        if (literalOnly || editGuard.mayEdit()) return;
        String retained = recovery.valueForExplicitCopy();
        if (retained == null) return;
        try {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard == null) return;
            ClipData clip = ClipData.newPlainText("NepType retained Roman text", retained);
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                PersistableBundle extras = new PersistableBundle();
                extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true);
                clip.getDescription().setExtras(extras);
            }
            clipboard.setPrimaryClip(clip);
            recovery.clear();
            android.widget.Toast.makeText(this, "Retained Roman text copied; check the destination before pasting.", android.widget.Toast.LENGTH_LONG).show();
        } catch (RuntimeException failure) {
            // Keep the token available if the platform could not confirm a copy.
            android.widget.Toast.makeText(this, "Could not copy retained text.", android.widget.Toast.LENGTH_LONG).show();
        }
        render();
    }
    private void confirmEdit(boolean confirmed) {
        if (confirmed) feedback.confirmedEdit(); else blockEdits();
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
