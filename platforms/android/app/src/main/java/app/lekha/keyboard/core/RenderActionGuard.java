package app.lekha.keyboard.core;

/** Reject callbacks queued by an obsolete keyboard rendering or editor session.
 * Calls are confined to the Android input service's main thread. This is not
 * proof of editor identity or a replacement for InputConnection ownership.
 */
public final class RenderActionGuard {
    private long generation;
    public long current() { return generation; }
    public void invalidate() { generation++; }
    public boolean accepts(long captured) { return captured == generation; }
}
