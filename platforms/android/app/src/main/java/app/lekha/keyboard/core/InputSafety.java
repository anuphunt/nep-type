package app.lekha.keyboard.core;

/** Pure decisions for asynchronous lookup and host composition ownership.
 * These guards cannot prove that an Android editor applies an edit correctly. */
public final class InputSafety {
    private InputSafety() { }
    /** Android InputType bit values. Unknown types conservatively pass through.
     * See https://developer.android.com/reference/android/text/InputType */
    public static boolean literalOnly(int type) {
        final int kind = type & 0x0f, variation = type & 0x0ff0;
        if (kind != 1) return true; // TYPE_CLASS_TEXT only
        if ((type & 0x80000) != 0) return true; // TYPE_TEXT_FLAG_NO_SUGGESTIONS
        switch (variation) {
            case 0x00: // normal
            case 0x30: // email subject (not an address)
            case 0x40: // short message
            case 0x50: // long message
            case 0x60: // person name
            case 0x70: // postal address
            case 0xa0: // web edit text
            case 0xb0: // filter
            case 0xc0: // phonetic
                return false;
            default: // passwords, URIs, email addresses and unknown types
                return true;
        }
    }
    public static boolean acceptsLookup(long requestGeneration, long currentGeneration,
                                        String requestText, String currentText,
                                        boolean active) {
        return active && requestGeneration == currentGeneration && requestText != null
                && requestText.equals(currentText);
    }
    /** A candidate button belongs to the exact token and generation it displayed. */
    public static boolean acceptsCandidate(long displayedGeneration, long currentGeneration,
                                           String displayedToken, String currentToken,
                                           boolean active, boolean listed) {
        return listed && acceptsLookup(displayedGeneration, currentGeneration,
                                       displayedToken, currentToken, active);
    }
    /** Return an editor action if explicitly provided and not disabled by host. */
    public static int editorAction(int options, int noEnterFlag, int actionMask,
                                   int actionNone, int actionUnspecified) {
        if ((options & noEnterFlag) != 0) return actionUnspecified;
        int action = options & actionMask;
        return action == actionNone ? actionUnspecified : action;
    }
    public static boolean selectionLosesOwnership(int oldStart, int oldEnd,
                                                   int newStart, int newEnd,
                                                   int composingStart, int composingEnd,
                                                   int expectedLength) {
        boolean valid = composingStart >= 0 && composingEnd >= composingStart;
        // An unknown, malformed, or differently sized marked range is not
        // enough evidence that a future replacement still belongs to us.
        if (!valid || expectedLength <= 0 || composingEnd - composingStart != expectedLength) return true;
        return newStart != composingEnd || newEnd != composingEnd;
    }
}
