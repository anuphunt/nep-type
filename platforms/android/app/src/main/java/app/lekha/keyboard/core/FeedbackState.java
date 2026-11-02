package app.lekha.keyboard.core;

/** Small, non-sensitive status model. It never records input or app identity. */
public final class FeedbackState {
    public enum Notice { NONE, EDIT_UNCERTAIN, DICTIONARIES_UNAVAILABLE }
    private Notice notice = Notice.NONE;

    public Notice notice() { return notice; }
    public void clear() { notice = Notice.NONE; }
    /** Keep a host-edit warning visible until explicitly dismissed or focus changes. */
    public void confirmedEdit() {
        if (notice != Notice.EDIT_UNCERTAIN) notice = Notice.NONE;
    }
    public void editUncertain() { notice = Notice.EDIT_UNCERTAIN; }
    public void dictionariesUnavailable() {
        // A data warning must never hide a more serious uncertain host edit.
        if (notice != Notice.EDIT_UNCERTAIN) notice = Notice.DICTIONARIES_UNAVAILABLE;
    }
    public String message() {
        switch (notice) {
            case EDIT_UNCERTAIN: return "Typing paused: check your text and refocus the field.";
            case DICTIONARIES_UNAVAILABLE: return "Suggestions are unavailable. Original remains selected.";
            default: return "";
        }
    }
}
