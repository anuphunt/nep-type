package app.neptype.keyboard.core;

/** A single, short, in-memory Roman token; never captures protected fields. */
public final class RecoveryBuffer {
    private String token;

    /** Preserve the first uncertain token, never replace it with a later event. */
    public void remember(String value, boolean literalOnly) {
        if (token != null || literalOnly || value == null || value.length() == 0 || value.length() > 128) return;
        for (int i = 0; i < value.length(); i++) {
            char ch = value.charAt(i);
            if (ch < 33 || ch > 126) return;
        }
        token = value;
    }

    public boolean available() { return token != null; }
    /** Call only in direct response to an explicit user recovery action. */
    public String valueForExplicitCopy() { return token; }
    public void clear() { token = null; }
}
