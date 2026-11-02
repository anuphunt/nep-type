package app.neptype.keyboard.core;

import java.util.List;

/** Reversible choice while the host still owns the original marked token. */
public final class CandidatePreview {
    private String selected;
    private String source;
    private long generation;

    public void clear() { selected = null; source = null; }

    public boolean select(String value, long shownGeneration, long currentGeneration,
                          String shownToken, String currentToken, boolean active,
                          List<String> suggestions) {
        if (value == null || suggestions == null || !InputSafety.acceptsCandidate(
                shownGeneration, currentGeneration, shownToken, currentToken,
                active, suggestions.contains(value))) return false;
        selected = value;
        source = shownToken;
        generation = shownGeneration;
        return true;
    }

    /** Null if text, focus, generation or the offered list has since changed. */
    public String current(long currentGeneration, String currentToken, boolean active,
                          List<String> suggestions) {
        if (selected == null || suggestions == null || !InputSafety.acceptsCandidate(
                generation, currentGeneration, source, currentToken, active,
                suggestions.contains(selected))) return null;
        return selected;
    }

    /** A queued button event must still refer to the exact preview it displayed. */
    public boolean matchesDisplay(long shownGeneration, String shownToken, String shownValue,
                                  long currentGeneration, String currentToken, boolean active,
                                  List<String> suggestions) {
        if (shownValue == null || !InputSafety.acceptsCandidate(shownGeneration, currentGeneration,
                shownToken, currentToken, active, true)) return false;
        return shownValue.equals(current(currentGeneration, currentToken, active, suggestions));
    }
}
