package app.lekha.keyboard.core;

/** Platform-independent validation for candidate display preferences. */
public final class DisplaySettings {
    public static final int DEFAULT_LIMIT = 4;
    private DisplaySettings() { }
    public static int candidateLimit(int requested) {
        return requested >= 2 && requested <= 4 ? requested : DEFAULT_LIMIT;
    }
}
