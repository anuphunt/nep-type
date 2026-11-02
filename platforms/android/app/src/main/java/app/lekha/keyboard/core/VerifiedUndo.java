package app.lekha.keyboard.core;

/**
 * Dormant contract for a host that can compare-and-replace atomically. Android
 * InputConnection does not expose this guarantee, so no service calls it.
 */
public final class VerifiedUndo {
    public enum Result { APPLIED, STALE, UNKNOWN, UNAVAILABLE }
    public interface AtomicEditor {
        /** Check the exact text and caret and replace in one indivisible host operation. */
        Result compareAndReplace(String expected, String original, int expectedCaret, long session);
    }
    private String original, committed;
    private int expectedCaret;
    private long session;
    public void clear() { original = null; committed = null; }
    public boolean arm(String source, String replacement, int caret, long currentSession, boolean confirmed) {
        clear();
        if (!confirmed || source == null || replacement == null || source.isEmpty() || replacement.isEmpty()
                || source.equals(replacement) || caret < replacement.length()) return false;
        original = source; committed = replacement; expectedCaret = caret; session = currentSession;
        return true;
    }
    /** An attempt is one-shot, including unavailable or ambiguous results. */
    public Result undo(AtomicEditor editor, long currentSession) {
        if (original == null || session != currentSession) { clear(); return Result.STALE; }
        String source = original, expected = committed;
        int caret = expectedCaret; long token = session;
        clear();
        if (editor == null) return Result.UNAVAILABLE;
        Result result = editor.compareAndReplace(expected, source, caret, token);
        return result == null ? Result.UNKNOWN : result;
    }
}
