package app.lekha.keyboard.core;

/** Platform-independent, lossless Roman composition; candidate replacement is explicit. */
public final class Composition {
    private final StringBuilder text = new StringBuilder();
    private boolean nepali = true;
    public String text() { return text.toString(); }
    public boolean isNepali() { return nepali; }
    public boolean active() { return text.length() > 0; }
    public boolean accepts(String value) {
        return nepali && text.length() < 128 && value != null && value.length() == 1 && value.matches("[A-Za-z]");
    }
    public boolean append(String value) {
        if (!accepts(value)) return false;
        text.append(value); return true;
    }
    public boolean backspace() {
        if (!active()) return false;
        text.deleteCharAt(text.length() - 1); return true;
    }
    public String takeOriginal() { String s = text(); text.setLength(0); return s; }
    public void setNepali(boolean value) {
        if (active()) throw new IllegalStateException("Commit or cancel composition first");
        nepali = value;
    }
}
