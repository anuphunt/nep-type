package app.lekha.keyboard.core;

/** Fail closed after the host's marked-text ownership becomes uncertain. */
public final class EditorSessionGuard {
    private boolean blocked;
    public boolean mayEdit() { return !blocked; }
    public void ownershipUncertain() { blocked = true; }
    /** A restart can retain host composition; only a new input session resets. */
    public void start(boolean restarting, boolean hadActiveComposition) {
        if (!restarting) blocked = false;
        else if (hadActiveComposition) blocked = true;
    }
}
